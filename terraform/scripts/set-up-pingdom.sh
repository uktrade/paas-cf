#!/bin/bash

set -eu
TERRAFORM_ACTION=${1}
TF_VERSION=0.11.14
PLUGIN_VERSION=0.2.3
BINARY=terraform-provider-pingdom-tf-${TF_VERSION}-$(uname -s)-$(uname -m)
STATEFILE=pingdom-${AWS_ACCOUNT}.tfstate

# Get Pingdom credentials
export PASSWORD_STORE_DIR=~/.paas-pass
PINGDOM_USER=$(pass pingdom.com/username)
PINGDOM_PASSWORD=$(pass pingdom.com/password)
PINGDOM_API_KEY=$(pass pingdom.com/app-key/govuk-paas-terraform)
PINGDOM_ACCOUNT_EMAIL=$(pass pingdom.com/account_email)

# Install Terraform plugin to temporary directory
PAAS_CF_DIR=$(pwd)
WORKING_DIR=$(mktemp -d terraform-pingdom.XXXXXX)
trap 'rm -r "${PAAS_CF_DIR}/${WORKING_DIR}"' EXIT

if [ ! -d bin/ ]; then
  mkdir bin/
fi

#wget can only check timestamp on a file in work dir
cd bin/
wget -N "https://github.com/alphagov/paas-terraform-provider-pingdom/releases/download/${PLUGIN_VERSION}/${BINARY}"
cp ./"${BINARY}" "${PAAS_CF_DIR}"/"${WORKING_DIR}"/terraform-provider-pingdom
chmod +x "${PAAS_CF_DIR}"/"${WORKING_DIR}"/terraform-provider-pingdom

# Work in tmp dir to ensure there's no local state before we kick off terraform, it prioritises it
cd "${PAAS_CF_DIR}"/"${WORKING_DIR}"

# Initialise Terraform with remote state.
terraform init \
  -backend=true \
  -backend-config="bucket=gds-paas-${DEPLOY_ENV}-state" \
  -backend-config="key=${STATEFILE}" \
  -backend-config="region=${AWS_DEFAULT_REGION}" \
  "${PAAS_CF_DIR}"/terraform/pingdom

# Run Terraform Pingdom Provider
terraform "${TERRAFORM_ACTION}" \
	-var-file="${PAAS_CF_DIR}/terraform/${AWS_ACCOUNT}.tfvars" \
	-var "env=${DEPLOY_ENV}" \
	-var "pingdom_user=${PINGDOM_USER}" \
	-var "pingdom_password=${PINGDOM_PASSWORD}" \
	-var "pingdom_api_key=${PINGDOM_API_KEY}" \
	-var "pingdom_account_email=${PINGDOM_ACCOUNT_EMAIL}" \
	-var "apps_dns_zone_name=${APPS_DNS_ZONE_NAME}" \
	-var "system_dns_zone_name=${SYSTEM_DNS_ZONE_NAME}" \
  "${PAAS_CF_DIR}"/terraform/pingdom
