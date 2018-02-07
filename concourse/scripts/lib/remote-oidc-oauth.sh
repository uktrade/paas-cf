#!/bin/sh
set -e
set -u

get_remote_oidc_oauth_secrets() {
  # shellcheck disable=SC2154
  secrets_uri="s3://${state_bucket}/remote-oidc-secrets.yml"
  export remote_oidc_client_id
  export remote_oidc_client_secret
  secrets_size=$(aws s3 ls "${secrets_uri}" | awk '{print $3}')
  if [ "${secrets_size}" != 0 ] && [ -n "${secrets_size}" ]  ; then
    secrets_file=$(mktemp -t remote-oidc-secrets.XXXXXX)

    aws s3 cp "${secrets_uri}" "${secrets_file}"
    remote_oidc_client_id=$("${SCRIPT_DIR}"/val_from_yaml.rb secrets.remote_oidc_client_id "${secrets_file}")
    remote_oidc_client_secret=$("${SCRIPT_DIR}"/val_from_yaml.rb secrets.remote_oidc_client_secret "${secrets_file}")

    rm -f "${secrets_file}"
  fi
}
