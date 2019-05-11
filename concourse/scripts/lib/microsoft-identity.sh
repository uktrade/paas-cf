#!/bin/sh
set -e
set -u

get_microsoft_identity_secrets() {
  # shellcheck disable=SC2154
  secrets_uri="s3://${state_bucket}/microsoft-identity-secrets.yml"
  export microsoft_identity_tenantid
  export microsoft_identity_oauth_client_id
  export microsoft_identity_oauth_client_secret
  secrets_size=$(aws s3 ls "${secrets_uri}" | awk '{print $3}')
  if [ "${secrets_size}" != 0 ] && [ -n "${secrets_size}" ]  ; then
    secrets_file=$(mktemp -t microsoft-identity-secrets.XXXXXX)

    aws s3 cp "${secrets_uri}" "${secrets_file}"
    microsoft_identity_tenantid=$("${SCRIPT_DIR}"/val_from_yaml.rb secrets.microsoft_identity_tenantid "${secrets_file}")
    microsoft_identity_oauth_client_id=$("${SCRIPT_DIR}"/val_from_yaml.rb secrets.microsoft_identity_oauth_client_id "${secrets_file}")
    microsoft_identity_oauth_client_secret=$("${SCRIPT_DIR}"/val_from_yaml.rb secrets.microsoft_identity_oauth_client_secret "${secrets_file}")

    rm -f "${secrets_file}"
  fi
}
