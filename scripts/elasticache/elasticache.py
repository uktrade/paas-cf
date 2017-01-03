#!/usr/bin/env python
import argparse
import boto3
import netaddr
import subprocess
import tempfile
import json
import os

DEPLOY_ENV = os.environ.get('DEPLOY_ENV')

# The ARN of the elasticache cluster is needed to add a tag to the cluster (after creation)
# In a real broker implementation the fields 'aws', region, and account number would have to be fetched from the manifest
# Note: there is value in parameterising the partition field: https://github.com/alphagov/paas-rds-broker/pull/23
ELASTICACHE_ARN_PREFIX='arn:aws:elasticache:eu-west-1:{}:cluster:'.format(os.environ.get('AWS_DEV_ACCOUNT'))
APP_GUID='appGuidProvidedByCloudController'
BINDING_ID='someValueProvidedByCloudController'

class ElasticacheBrokerTest(object):
    def __init__(self, vpc_id, instance_id, service_id, plan_id, security_group_id, org_id=None, org_name=None, space_id=None, space_name=None):
        self.vpc_id = vpc_id
        self.instance_id = instance_id
        self.service_id = service_id
        self.plan_id = plan_id
        self.org_id = org_id
        self.org_name = org_name
        self.space_id = space_id
        self.space_name = space_name
        self.security_group_id = security_group_id
        self.port = 6379

    def provision(self):
        elasticache = boto3.client('elasticache')
        vpc = boto3.resource('ec2').Vpc(self.vpc_id)

        existing_subnets = vpc.subnets.all()
        subnets = self.create_subnets(vpc, self.select_subnets(existing_subnets))

        subnet_ids = map(lambda subnet: subnet.subnet_id, subnets)
        self.create_tags(vpc, subnet_ids)
        subnet_group = self.create_subnet_group(elasticache, subnet_ids)
        self.create_elasticache(elasticache, subnet_group, self.cache_node_type(), self.engine_version())

        subnet_cidrs = map(lambda subnet: subnet.cidr_block, subnets)
        asg_name = self.create_application_security_group(subnet_group, subnet_cidrs)
        self.bind_application_security_group(asg_name)

    def deprovision(self):
        print self

    def bind(self):
        arn = self.buildARN()
        elasticache = boto3.client('elasticache')
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
        j = {'credentials': self.get_cluster_url(self.buildCacheClusterId())}
        print json.dumps(j)

    def unbind(self):
        arn = self.buildARN()
        elasticache = boto3.client('elasticache')
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
        supernet = netaddr.IPNetwork('10.0.64.0/18')
        allowed_subnet_set = netaddr.IPSet(list(supernet.subnet(28)))
        existing_subnet_set = netaddr.IPSet(map(lambda subnet: subnet.cidr_block, existing_subnets))
        available_subnet_set = allowed_subnet_set - existing_subnet_set
        available_subnets = []
        for cidr in available_subnet_set.iter_cidrs():
            available_subnets.extend(cidr.subnet(28))
        azs = ['eu-west-1a', 'eu-west-1b']
        return zip(available_subnets[:2], azs)

    def create_subnets(self, vpc, subnets_and_azs):
        print "Creating subnets..."
        print subnets_and_azs
        return map(lambda (subnet, az): create_subnet(vpc, subnet, az), subnets_and_azs)


    def create_subnet_group(self, elasticache, subnet_ids):
        return elasticache.create_cache_subnet_group(
            CacheSubnetGroupName='cache-subnet-group-%s' % self.instance_id,
            CacheSubnetGroupDescription='Cache subnet group for %s' % self.instance_id,
            SubnetIds=subnet_ids
        )['CacheSubnetGroup']['CacheSubnetGroupName']

    def create_elasticache(self, elasticache, subnet_group, cache_node_type, engine_version):
        # http://boto3.readthedocs.io/en/latest/reference/services/elasticache.html#ElastiCache.Client.create_cache_cluster
        return elasticache.create_cache_cluster(
            #Note: has a 20 character limit
            CacheClusterId=self.buildCacheClusterId(),
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
            Tags=self.build_tags(),
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

    def cache_node_type(self):
        #TODO: get the node type from the plan
        return 'cache.t2.micro'

    def engine_version(self):
        #TODO: get the engine version from the plan
        # http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/SelectEngine.RedisVersions.html
        return '3.2.4'

    def create_application_security_group(self, subnet_group, subnet_cidrs):
        asg_name = 'elasticache-{}-{}'.format(self.space_id, subnet_group)
        asg_rules = map(lambda subnet_cidr:
            {'protocol': 'tcp', 'destination': subnet_cidr, 'ports': '{}'.format(self.port)},
            subnet_cidrs)
        with tempfile.NamedTemporaryFile() as temp_file:
            json.dump(asg_rules, temp_file)
            temp_file.flush()
            subprocess.check_call(['cf', 'create-security-group', asg_name, temp_file.name])
        return asg_name

    def bind_application_security_group(self, asg_name):
        subprocess.check_call(['cf', 'bind-security-group', asg_name, self.org_name, self.space_name])

    def build_tags(self):
        return [
            {
                'Key': 'Name',
                'Value': 'elasticache-{}'.format(self.instance_id)
            },
            {
                'Key': 'Owner',
                'Value': 'Cloud Foundry'
            },
            {
                'Key': 'Plan ID',
                'Value': self.plan_id
            },
            {
                'Key': 'Service ID',
                'Value': self.service_id
            },
            {
                'Key': 'Space ID',
                'Value': self.space_id
            },
            {
                'Key': 'Broker Name',
                'Value': 'Redis-broker'
            },
            {
                'Key': 'Organization ID',
                'Value': self.org_id
            },
            {
                'Key': 'Instance ID',
                'Value': self.instance_id
            },
        ]

    def create_tags(self, vpc, subnet_ids):
        vpc.create_tags(
            DryRun=False,
            Resources=subnet_ids,
            Tags=self.build_tags()
        )

    def buildCacheClusterId(self):
        return 'ccid-%s' % self.instance_id

    def buildARN(self):
        return '{}{}'.format(ELASTICACHE_ARN_PREFIX, self.buildCacheClusterId())

    def buildBindingTagKey(self):
        return 'binding-id-{}'.format(BINDING_ID)

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
    action_group.add_argument('--provision', help='Create a new elasticache', action='store_true')
    action_group.add_argument('--deprovision', help='Delete an existing elasticache', action='store_true')
    action_group.add_argument('--bind', help='Bind an app to an existing elasticache', action='store_true')
    action_group.add_argument('--unbind', help='Unbind an app from an existing elasticache', action='store_true')

    parser.add_argument('--vpc-id', help='Id for existing VPC', required=True)
    parser.add_argument('--instance-id', help='Id for new elasticache instance', required=True)
    parser.add_argument('--service-id', help='Service ID for new elasticache instance', required=True)
    parser.add_argument('--plan-id', help='Plan ID for new elasticache instance', required=True)
    parser.add_argument('--org-id', help='Org for new elasticache instance', required=True)
    # A broker implementation would probably derive the org name from the org ID, but for simplicity and proof of concept
    # we will just pass it into this script
    parser.add_argument('--org-name', help='Org for new elasticache instance', required=True)
    parser.add_argument('--space-id', help='Space for new elasticache instance', required=True)
    # A broker implementation would probably derive the space name from the space ID, but for simplicity and proof of concept
    # we will just pass it into this script
    parser.add_argument('--space-name', help='Space for new elasticache instance', required=True)
    parser.add_argument('--security-group-id', help='Security group for new elasticache instance', required=True)

    args = parser.parse_args()

    ec = ElasticacheBrokerTest(args.vpc_id, args.instance_id, args.service_id, args.plan_id, args.security_group_id, args.org_id, args.org_name, args.space_id, args.space_name)
    if args.provision:
        ec.provision()
    elif args.deprovision:
        ec.deprovision()
    elif args.bind:
        ec.bind()
    else:
        ec.unbind()
