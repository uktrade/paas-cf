#!/usr/bin/env python
import argparse
import boto3

BOLD = '\033[1m'
ENDC = '\033[0m'

class NetworkAclUpdater(object):
    def __init__(self, network_acl_id, whitelist, blacklist):
        self.network_acl_id = network_acl_id
        self.whitelist = whitelist
        self.blacklist = blacklist

    def update(self):
        ec2 = boto3.resource('ec2')
        acl = ec2.NetworkAcl(self.network_acl_id)

        rules_to_remove = self.rules_to_remove(acl)
        rules_to_add = self.rules_to_add(acl)
        self.add_rules(acl, rules_to_add)
        self.remove_rules(acl, rules_to_remove)

    def ingress_rules(self, acl):
        return [e for e in acl.entries if e['RuleNumber'] < 32767 and not e['Egress']]

    def unavailable_rule_numbers(self, acl):
        return set(map(lambda e: e['RuleNumber'], acl.entries))

    def rules_to_remove(self, acl):
        return [e for e in self.ingress_rules(acl)
                if (e['RuleAction'] == 'allow' and e['CidrBlock'] not in self.whitelist)
                or (e['RuleAction'] == 'deny' and e['CidrBlock'] not in self.blacklist)]

    def rules_to_add(self, acl):
        unavailable_rule_numbers = self.unavailable_rule_numbers(acl)
        ingress_rules = self.ingress_rules(acl)
        existing_whitelist_cidrs = map(lambda e: e['CidrBlock'], [e for e in ingress_rules if e['RuleAction'] == 'allow'])
        existing_blacklist_cidrs = map(lambda e: e['CidrBlock'], [e for e in ingress_rules if e['RuleAction'] == 'deny'])
        whitelist_to_add = [cidr for cidr in self.whitelist if cidr not in existing_whitelist_cidrs]
        blacklist_to_add = [cidr for cidr in self.blacklist if cidr not in existing_blacklist_cidrs]

        return self.build_whitelist_rules(whitelist_to_add, unavailable_rule_numbers) +\
               self.build_blacklist_rules(blacklist_to_add, unavailable_rule_numbers)

    def build_whitelist_rules(self, cidrs, unavailable_rule_numbers):
        return self.build_rules(cidrs, unavailable_rule_numbers, 100, 'allow')

    def build_blacklist_rules(self, cidrs, unavailable_rule_numbers):
        return self.build_rules(cidrs, unavailable_rule_numbers, 500, 'deny')

    def build_rules(self, cidrs, unavailable_rule_numbers, starting_rule_number, rule_action):
        next_candidate_rule_number = starting_rule_number
        rules = []

        def find_rule_number(candidate_rule_number):
            while candidate_rule_number in unavailable_rule_numbers:
                candidate_rule_number += 1
            return candidate_rule_number, candidate_rule_number + 1

        for cidr_block in cidrs:
            rule_number, next_candidate_rule_number = find_rule_number(next_candidate_rule_number)
            rules.append(self.build_rule(cidr_block, rule_number, rule_action))

        return rules

    def build_rule(self, cidr_block, rule_number, rule_action):
        return {
            'RuleNumber': rule_number,
            'CidrBlock': cidr_block,
            'RuleAction': rule_action,
        }

    def add_rules(self, acl, rules):
        for rule in rules:
            acl.create_entry(
                DryRun=False,
                RuleNumber=rule['RuleNumber'],
                Protocol='-1',
                RuleAction=rule['RuleAction'],
                Egress=False,
                CidrBlock=rule['CidrBlock'],
            )

    def remove_rules(self, acl, rules):
        for rule in rules:
            acl.delete_entry(
                DryRun=False,
                RuleNumber=rule['RuleNumber'],
                Egress=False,
            )

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--acl-id', help='Network ACL to update', required=True)
    parser.add_argument('--whitelist', help='CIDRs to whitelist', nargs='*', metavar='CIDR', default=[])
    parser.add_argument('--blacklist', help='CIDRs to blacklist', nargs='*', metavar='CIDR', default=[])
    args = parser.parse_args()

    acls = NetworkAclUpdater(args.acl_id, args.whitelist, args.blacklist)
    acls.update()
