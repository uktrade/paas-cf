#!/bin/bash

set -euo pipefail

WORKING_DIR="$(mktemp -dt generate-cf-certs.XXXXXX)"
trap 'rm -rf "${WORKING_DIR}"' EXIT

echo "Working directory is ${WORKING_DIR}"

cd ${WORKING_DIR}

mkdir certs

aws s3 cp s3://gds-paas-${FROM}-state/cf-secrets.yml cf-secrets-${FROM}.yml
aws s3 cp s3://gds-paas-${TO}-state/cf-secrets.yml cf-secrets-${TO}.yml

grep -v "uaa_clients" cf-secrets-${TO}.yml > cf-secrets-${TO}-updated.yml
grep "uaa_clients" cf-secrets-${FROM}.yml >> cf-secrets-${TO}-updated.yml

aws s3 cp cf-secrets-${TO}-updated.yml s3://gds-paas-${TO}-state/cf-secrets.yml

aws s3 cp s3://gds-paas-${FROM}-state/bosh-CA.tar.gz .
aws s3 cp s3://gds-paas-${TO}-state/cf-certs.tar.gz .

tar xzf bosh-CA.tar.gz
tar xzf cf-certs.tar.gz -C certs

rm cf-certs.tar.gz

mv bosh-CA.crt certs/uaa-CA.crt
echo "" > certs/uaa-CA.key

tar czf cf-certs.tar.gz -C certs .

aws s3 cp cf-certs.tar.gz s3://gds-paas-${TO}-state/cf-certs.tar.gz
