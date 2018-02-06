#!/bin/bash

set -euo pipefail

aws s3 cp s3://gds-paas-${FROM}-state/cf-secrets.yml cf-secrets-${FROM}.yml
aws s3 cp s3://gds-paas-${TO}-state/cf-secrets.yml cf-secrets-${TO}.yml

grep -v "uaa_clients" cf-secrets-${TO}.yml > cf-secrets-${TO}-updated.yml
grep "uaa_clients" cf-secrets-${FROM}.yml >> cf-secrets-${TO}-updated.yml

aws s3 cp cf-secrets-${TO}-updated.yml s3://gds-paas-${TO}-state/cf-secrets.yml

rm cf-secrets-*
