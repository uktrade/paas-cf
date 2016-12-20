#!/usr/bin/env python
import argparse
import boto3
import netaddr

class ElasticacheBrokerTest(object):
    def __init__(self, vpc_id, instance_id, org_id=None, space_id=None):
        self.instance_id = instance_id
        self.org_id = org_id
        self.space_id = space_id

    def provision(self):
        elasticache = boto3.client('elasticache')
        vpc = boto3.resource('ec2').Vpc(self.vpc_id)

        subnets = self.create_subnets(vpc, select_subnets())

        subnet_group = self.create_subnet_group(elasticache, subnets)
        self.create_elasticache(elasticache, subnet_group, cache_node_type(self.plan_id),, engine_version())

    def deprovision(self):
        print self

    def select_subnets(self):
        supernet = netaddr.IPNetwork('10.0.64.0/18')
        all_subnets = list(supernet.subnet(28))
        # TODO
        # used_subnets = [] # derive from aws
        # return (all_subnets - used_subnets).take(2)
        azs = ['eu-west-1a', 'eu-west-1b']
        return zip(all_subnets[:2], azs)

    def create_subnets(self, vpc, subnets_and_azs):
        return map(lambda (subnet, az):
                vpc.create_subnet(
                    DryRun=False,
                    CidrBlock=subnet,
                    AvailabilityZone=az
                ).subnet_id,
            subnets_and_azs
        )

    def create_subnet_group(self, elasticache, subnets):
        return elasticache.create_cache_subnet_group(
            CacheSubnetGroupName='cache-subnet-group-%s' % self.instance_id,
            CacheSubnetGroupDescription='Cache subnet group for %s' % self.instance_id,
            SubnetIds=subnets
        )['CacheSubnetGroup']['CacheSubnetGroupName']

    def create_elasticache(self, elasticache, subnet_group, cache_node_type, engine_version):
        return elasticache.create_cache_cluster(
            CacheClusterId='cache-cluster-%s' % self.instance_id,
            #ReplicationGroupId='string',
            NumCacheNodes=1,
            CacheNodeType=cache_node_type,
            Engine='redis',
            EngineVersion=engine_version,
            # CacheParameterGroupName='string',
            CacheSubnetGroupName=subnet_group,
            SecurityGroupIds=[
                'string',
            ],
            Tags=[
                {
                    'Key': 'string',
                    'Value': 'string'
                },
            ],
            SnapshotArns=[
                'string',
            ],
            SnapshotName='string',
            PreferredMaintenanceWindow='string',
            Port=123,
            NotificationTopicArn='string',
            AutoMinorVersionUpgrade=True|False,
            SnapshotRetentionLimit=123,
            SnapshotWindow='string',
            AuthToken='string'
        )


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument('--provision', help='Create a new elasticache', action='store_true')
    action_group.add_argument('--deprovision', help='Delete an existing elasticache', action='store_true')

    parser.add_argument('--vpc-id', help='Id for existing VPC', required=True)
    parser.add_argument('--instance-id', help='Id for new elasticache instance', required=True)
    parser.add_argument('--org-id', help='Org for new elasticache instance', required=True)
    parser.add_argument('--space-id', help='Space for new elasticache instance', required=True)

    args = parser.parse_args()

    ec = ElasticacheBrokerTest(args.vpc_id, args.instance_id, args.org_id, args.space_id)
    if args.provision:
        ec.provision()
    else:
        ec.deprovision()

