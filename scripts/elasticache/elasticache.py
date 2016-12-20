#!/usr/bin/env python
import argparse
import boto3

SUBNET_RANGE='10.0.64.0/18' # todo figure out how to split this up

class ElasticacheBrokerTest(object):
    def __init__(self, instance_id, org_id=None, space_id=None):
        self.instance_id = instance_id
        self.org_id = org_id
        self.space_id = space_id

    def provision(self):
        client = boto3.client('elasticache')
        subnets = create_subnets()

        response = client.create_cache_subnet_group(
            CacheSubnetGroupName='cache-subnet-group-%s' % self.instance_id,
            CacheSubnetGroupDescription='Cache subnet group for %s' % self.instance_id,
            SubnetIds=subnets
        )


    def deprovision(self):
        print self

    def create_subnets(self):
        return []

if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument('--provision', help='Create a new elasticache', action='store_true')
    action_group.add_argument('--deprovision', help='Delete an existing elasticache', action='store_true')

    parser.add_argument('--instance-id', help='Id for new elasticache instance', required=True)
    parser.add_argument('--org-id', help='Org for new elasticache instance', required=True)
    parser.add_argument('--space-id', help='Space for new elasticache instance', required=True)

    args = parser.parse_args()

    ec = ElasticacheBrokerTest(args.instance_id, args.org_id, args.space_id)
    if args.provision:
        ec.provision()
    else:
        ec.deprovision()

