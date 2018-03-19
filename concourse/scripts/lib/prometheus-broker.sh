#!/bin/sh
set -e
set -u

get_prometheus_broker_secrets() {
  # shellcheck disable=SC2154
  export secrets_uri="s3://${state_bucket}/prometheus-broker-secrets.yml"
  export prometheus_broker_aws_access_key_id
  export prometheus_broker_aws_secret_key_id
  export prometheus_broker_uaa_password
  export prometheus_broker_uaa_username
  if aws s3 ls "${secrets_uri}" > /dev/null ; then
    secrets_file=$(mktemp -t compose-secrets.XXXXXX)

    aws s3 cp "${secrets_uri}" "${secrets_file}"
    prometheus_broker_aws_access_key_id=$("${SCRIPT_DIR}"/val_from_yaml.rb prometheus_broker_aws_access_key_id "${secrets_file}")
    prometheus_broker_aws_secret_key_id=$("${SCRIPT_DIR}"/val_from_yaml.rb prometheus_broker_aws_secret_key_id "${secrets_file}")
    prometheus_broker_uaa_password=$("${SCRIPT_DIR}"/val_from_yaml.rb prometheus_broker_uaa_password "${secrets_file}")
    prometheus_broker_uaa_username=$("${SCRIPT_DIR}"/val_from_yaml.rb prometheus_broker_uaa_username "${secrets_file}")

    rm -f "${secrets_file}"
  fi
}
