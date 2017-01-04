#!/usr/bin/env python
import argparse
import boto3
import netaddr
import subprocess
import tempfile
import json
import os
import pprint
from botocore.exceptions import ClientError
import time

DEPLOY_ENV = os.environ.get('DEPLOY_ENV')

# The ARN of the elasticache cluster is needed to add a tag to the cluster (after creation)
# In a real broker implementation the fields 'aws', region, and account number would have to be fetched from the manifest
# Note: there is value in parameterising the partition field: https://github.com/alphagov/paas-rds-broker/pull/23
ELASTICACHE_ARN_PREFIX='arn:aws:elasticache:eu-west-1:{}:cluster:'.format(os.environ.get('AWS_DEV_ACCOUNT'))
APP_GUID='appGuidProvidedByCloudController'
BINDING_ID='someValueProvidedByCloudController'

class ElasticacheBrokerTest(object):
    def __init__(self, vpc_id, service_id, security_group_id):
        self.vpc_id = vpc_id
        self.service_id = service_id
        self.security_group_id = security_group_id
        self.port = 6379
        self.subnet_range = '10.0.64.0/18'

    def provision(self, instance_id, space_name, space_id, org_id, plan_id):
        elasticache = boto3.client('elasticache')
        vpc = boto3.resource('ec2').Vpc(self.vpc_id)

        existing_subnets = vpc.subnets.all()
        subnets = self.create_subnets(vpc, self.select_subnets(existing_subnets))

        subnet_ids = map(lambda subnet: subnet.subnet_id, subnets)
        self.create_tags(vpc, subnet_ids, instance_id, space_name, org_id, plan_id)
        subnet_group = self.create_subnet_group(elasticache, subnet_ids, instance_id)
        self.create_elasticache(elasticache, subnet_group, self.cache_node_type(), self.engine_version(), instance_id, space_name, org_id, plan_id)

        subnet_cidrs = map(lambda subnet: subnet.cidr_block, subnets)
        security_group_id = self.create_application_security_group(subnet_group, subnet_cidrs, instance_id)
        self.bind_application_security_group(security_group_id, space_id)

    def deprovision(self, instance_id):
        elasticache = boto3.client('elasticache')
        self.delete_application_security_group(instance_id)

        cluster_id = self.buildCacheClusterId(instance_id)
        if self.cache_cluster_still_exists(elasticache, cluster_id):
            print "Deleting cluster: %s" % instance_id
            response = self.delete_elasticache(elasticache, instance_id)

        while self.cache_cluster_still_exists(elasticache, cluster_id):
            print 'Waiting for deletion of cache cluster %s...' % cluster_id
            time.sleep(15)

        subnet_group = self.build_subnet_group_name(instance_id)
        if self.subnet_group_still_exists(elasticache, subnet_group):
            print "Deleting subnet group: %s" % subnet_group
            self.delete_subnet_group(elasticache, subnet_group)

        while self.subnet_group_still_exists(elasticache, subnet_group):
            print 'Waiting for deletion of subnet group %s...' % subnet_group
            time.sleep(15)

        for subnet in self.get_subnets(instance_id):
            print "Deleting subnet: %s" % subnet.id
            subnet.delete()

    def get_subnets(self, instance_id):
        vpc = boto3.resource('ec2').Vpc(self.vpc_id)
        subnets = vpc.subnets.filter(
            Filters = [{'Name': 'tag:Instance ID', 'Values': [instance_id]}]
        )
        return list(subnets)

    def cache_cluster_still_exists(self, elasticache, cluster_id):
        try:
            response = elasticache.describe_cache_clusters(CacheClusterId=cluster_id)
        except ClientError as e:
            if e.response['Error']['Code'] == 'CacheClusterNotFound':
                return False
            else:
                raise e
        return True

    def subnet_group_still_exists(self, elasticache, cache_subnet_group_name):
        try:
            response = elasticache.describe_cache_subnet_groups(CacheSubnetGroupName=cache_subnet_group_name)
        except ClientError as e:
            if e.response['Error']['Code'] == 'CacheSubnetGroupNotFoundFault':
                return False
            else:
                raise e
        return True


    def bind(self, instance_id):
        arn = self.buildARN(instance_id)
        elasticache = boto3.client('elasticache')
        print "Adding tag: %s" % self.buildBindingTagKey()
        print "To resource: %s" % arn
        elasticache.add_tags_to_resource(
            ResourceName=arn,
            Tags=[
                {
                    'Key': self.buildBindingTagKey(),
                    'Value': 'app-guid-{}'.format(APP_GUID)
                },
            ]
        )
        print 'Redis cluster endpoint: '
        j = {'credentials': self.get_cluster_url(self.buildCacheClusterId(instance_id))}
        print json.dumps(j)

    def unbind(self, instance_id):
        arn = self.buildARN(instance_id)
        elasticache = boto3.client('elasticache')
        print "Removing tag: %s" % self.buildBindingTagKey()
        print "From resource: %s" % arn
        elasticache.remove_tags_from_resource(
            ResourceName=arn,
            TagKeys=[self.buildBindingTagKey()]
        )

    def get_cluster_url(self, cache_cluster_id):
        elasticache = boto3.client('elasticache')
        response = elasticache.describe_cache_clusters(CacheClusterId=cache_cluster_id, ShowCacheNodeInfo=True)
        address = response['CacheClusters'][0]['CacheNodes'][0]['Endpoint']['Address']
        port = response['CacheClusters'][0]['CacheNodes'][0]['Endpoint']['Port']
        return '{}:{}'.format(address, port)

    def select_subnets(self, existing_subnets):
        print "Selecting subnets in range %s" % self.subnet_range
        supernet = netaddr.IPNetwork(self.subnet_range)
        allowed_subnet_set = netaddr.IPSet(list(supernet.subnet(28)))
        existing_subnet_set = netaddr.IPSet(map(lambda subnet: subnet.cidr_block, existing_subnets))
        available_subnet_set = allowed_subnet_set - existing_subnet_set
        available_subnets = []
        for cidr in available_subnet_set.iter_cidrs():
            available_subnets.extend(cidr.subnet(28))
        azs = ['eu-west-1a', 'eu-west-1b']
        return zip(available_subnets[:2], azs)

    def create_subnets(self, vpc, subnets_and_azs):
        print "Creating subnets: %s" % subnets_and_azs
        return map(lambda (subnet, az): create_subnet(vpc, subnet, az), subnets_and_azs)


    def create_subnet_group(self, elasticache, subnet_ids, instance_id):
        subnet_group_name = self.build_subnet_group_name(instance_id)
        print "Creating subnet group: %s" % subnet_group_name
        return elasticache.create_cache_subnet_group(
            CacheSubnetGroupName=subnet_group_name,
            CacheSubnetGroupDescription='Cache subnet group for %s' % instance_id,
            SubnetIds=subnet_ids
        )['CacheSubnetGroup']['CacheSubnetGroupName']

    def delete_subnet_group(self, elasticache, subnet_group):
        elasticache.delete_cache_subnet_group( CacheSubnetGroupName=subnet_group)

    def create_elasticache(self, elasticache, subnet_group, cache_node_type, engine_version, instance_id, space_name, org_id, plan_id):
        cluster_id = self.buildCacheClusterId(instance_id)
        print "Creating elasticache cluster: %s" % cluster_id
        # http://boto3.readthedocs.io/en/latest/reference/services/elasticache.html#ElastiCache.Client.create_cache_cluster
        return elasticache.create_cache_cluster(
            #Note: has a 20 character limit
            CacheClusterId=cluster_id,
            #ReplicationGroupId='string',
            NumCacheNodes=1,
            CacheNodeType=cache_node_type,
            Engine='redis',
            EngineVersion=engine_version,
            # CacheParameterGroupName='string',
            CacheSubnetGroupName=subnet_group,
            #NOTE: the broker would get security group from manifest
            SecurityGroupIds=[
                self.security_group_id,
            ],
            Tags=self.build_tags(instance_id, space_name, org_id, plan_id),
            #SnapshotArns=[],
            #SnapshotName='string',
            PreferredMaintenanceWindow='Thu:03:00-Thu:04:00',
            Port=self.port,
            #NotificationTopicArn='string',
            AutoMinorVersionUpgrade=False,
            #SnapshotRetentionLimit=7,
            #SnapshotWindow='01:00-02:00',
            # For guidance on AuthToken see:
            # http://boto3.readthedocs.io/en/latest/reference/services/elasticache.html#ElastiCache.Client.create_cache_cluster
            #AuthToken=''
        )

    def delete_elasticache(self, elasticache, instance_id):
        response = elasticache.delete_cache_cluster(
            CacheClusterId=self.buildCacheClusterId(instance_id),
            #FinalSnapshotIdentifier=self.buildCacheClusterId()
        )
        print 'Deleting cache cluster:'
        return response

    def cache_node_type(self):
        #TODO: get the node type from the plan
        return 'cache.t2.micro'

    def engine_version(self):
        #TODO: get the engine version from the plan
        # http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/SelectEngine.RedisVersions.html
        return '3.2.4'

    def create_application_security_group(self, subnet_group, subnet_cidrs, instance_id):
        asg_name = self.buildApplicationSecurityGroupName(instance_id)
        asg_rules = map(lambda subnet_cidr:
            {'protocol': 'tcp', 'destination': subnet_cidr, 'ports': '{}'.format(self.port)},
            subnet_cidrs)
        body = json.dumps({
            "name": asg_name,
            "rules": asg_rules
        })
        print "Creating security group: %s" % asg_name
        response_string = subprocess.check_output(['cf', 'curl', '-X', 'POST', '/v2/security_groups', '-d', body])
        response = json.loads(response_string)
        security_group_id = response['metadata']['guid']
        return security_group_id

    def delete_application_security_group(self, instance_id):
        asg_name = self.buildApplicationSecurityGroupName(instance_id)
        subprocess.check_call(['cf', 'delete-security-group', asg_name, '-f'])

    def bind_application_security_group(self, guid, space_id):
        print "Binding security group {} to space {}".format(guid, space_id)
        subprocess.check_call(['cf', 'curl', '-X', 'PUT', '/v2/security_groups/{}/spaces/{}'.format(guid, space_id)])

    def build_tags(self, instance_id, space_name, org_id, plan_id):
        return [
            {
                'Key': 'Name',
                'Value': 'elasticache-{}'.format(instance_id)
            },
            {
                'Key': 'Owner',
                'Value': 'Cloud Foundry'
            },
            {
                'Key': 'Plan ID',
                'Value': plan_id
            },
            {
                'Key': 'Service ID',
                'Value': self.service_id
            },
            {
                'Key': 'Space ID',
                'Value': space_name
            },
            {
                'Key': 'Broker Name',
                'Value': 'Redis-broker'
            },
            {
                'Key': 'Organization ID',
                'Value': org_id
            },
            {
                'Key': 'Instance ID',
                'Value': instance_id
            },
        ]

    def create_tags(self, vpc, subnet_ids, instance_id, space_name, org_id, plan_id):
        print "Creating tags: %s" % self.build_tags(instance_id, space_name, org_id, plan_id)
        vpc.create_tags(
            DryRun=False,
            Resources=subnet_ids,
            Tags=self.build_tags(instance_id, space_name, org_id, plan_id)
        )

    def buildCacheClusterId(self, instance_id):
        return 'ccid-%s' % instance_id

    def buildARN(self, instance_id):
        return '{}{}'.format(ELASTICACHE_ARN_PREFIX, self.buildCacheClusterId(instance_id))

    def buildBindingTagKey(self):
        return 'binding-id-{}'.format(BINDING_ID)

    def buildApplicationSecurityGroupName(self, instance_id):
        return 'elasticache-{}'.format(instance_id)

    def build_subnet_group_name(self, instance_id):
        return 'cache-subnet-group-%s' % instance_id

def get_space_id(space_name):
    response_string = subprocess.check_output(['cf', 'curl', '/v2/spaces'])
    response = json.loads(response_string)
    resources = response['resources']
    space = filter(lambda space: space['entity']['name'] == space_name, resources)[0]
    return space['metadata']['guid']

def create_subnet(vpc, subnet, az):
    print "Calling vpc.create_subnet..."
    print '%s' % subnet
    return vpc.create_subnet(
        DryRun=False,
        CidrBlock='%s' % subnet,
        AvailabilityZone=az
    )



if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    action_group = parser.add_mutually_exclusive_group(required=True)

    # Actions
    action_group.add_argument('--provision', help='Create a new elasticache', action='store_true')
    action_group.add_argument('--deprovision', help='Delete an existing elasticache', action='store_true')
    action_group.add_argument('--bind', help='Bind an app to an existing elasticache', action='store_true')
    action_group.add_argument('--unbind', help='Unbind an app from an existing elasticache', action='store_true')

    # Broker constants
    parser.add_argument('--vpc-id', help='Id for existing VPC', required=True)
    parser.add_argument('--service-id', help='Service ID for new elasticache instance', required=True)
    parser.add_argument('--security-group-id', help='Security group for new elasticache instance', required=True)

    # Parameters sent by the cloud controller
    parser.add_argument('--instance-id', help='Id for new elasticache instance', required=True)
    parser.add_argument('--plan-id', help='Plan ID for new elasticache instance', required=True)
    parser.add_argument('--space-name', help='Space for new elasticache instance', required=True)
    # A broker implementation would receive the space id from the cloud controller, but for simplicity and proof of concept
    # we just pass name and the script retrieves the id

    args = parser.parse_args()

    space_id = get_space_id(args.space_name)

    ec = ElasticacheBrokerTest(args.vpc_id, args.service_id, args.security_group_id)
    if args.provision:
        ec.provision(args.instance_id, args.space_name, space_id, args.org_id, args.plan_id)
    elif args.deprovision:
        ec.deprovision(args.instance_id)
    elif args.bind:
        ec.bind(args.instance_id)
    else:
        ec.unbind(args.instance_id)
