#!/usr/bin/env python
import argparse
import boto3

BOLD = '\033[1m'
ENDC = '\033[0m'

class WafIpsetUpdater(object):
    def __init__(self, ipset_id, cidrs):
        self.ipset_id = ipset_id
        self.cidrs = set(cidrs)

    def update(self):
        waf = boto3.client('waf')

        existing_cidrs = self.existing_cidrs(waf)

        cidrs_to_remove = existing_cidrs - self.cidrs
        cidrs_to_add = self.cidrs - existing_cidrs

        self.update_ipset(waf, cidrs_to_add, cidrs_to_remove)

    def existing_cidrs(self, waf):
        ipset = waf.get_ip_set(
            IPSetId=self.ipset_id
        )
        return set(map(lambda descriptor: descriptor['Value'], ipset['IPSet']['IPSetDescriptors']))

    def get_change_token(self, waf):
        return waf.get_change_token()['ChangeToken']

    def update_ipset(self, waf, cidrs_to_add, cidrs_to_remove):
        insert_updates = map(lambda cidr: {'Action': 'INSERT', 'IPSetDescriptor': { 'Type': 'IPV4', 'Value': cidr }}, cidrs_to_add)
        delete_updates = map(lambda cidr: {'Action': 'DELETE', 'IPSetDescriptor': { 'Type': 'IPV4', 'Value': cidr }}, cidrs_to_remove)
        change_token = self.get_change_token(waf)
        waf.update_ip_set(
            IPSetId=self.ipset_id,
            ChangeToken=change_token,
            Updates=insert_updates + delete_updates
        )

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ipset-id', help='IPSet to update', required=True)
    parser.add_argument('--cidrs', help='CIDRs to include in the set', nargs='*', metavar='CIDR', default=[])

    args = parser.parse_args()

    ipset = WafIpsetUpdater(args.ipset_id, args.cidrs)
    ipset.update()
