#!/bin/bash

set -eu

cf_deployment_manifest() {
  (
  CF_DEPLOYMENT=$(cd "$(dirname "$0")/manifests/cf-deployment" && pwd)
  cd "${CF_DEPLOYMENT}"

  ops500s=""
  for i in ../cf-manifest/manifest/operations/5*.yml; do
    ops500s="$ops500s -o $i"
  done

  ops600s=""
  for i in ../cf-manifest/manifest/operations/6*.yml; do
    ops600s="$ops600s -o $i"
  done

  bosh interpolate \
    -o operations/rename-network.yml -v network_name=cf \
    -o operations/aws.yml \
    -o operations/use-s3-blobstore.yml \
    -o operations/use-external-dbs.yml \
    -v external_database_type=postgres -v external_database_port=5432 -v external_cc_database_name=api \
    -o operations/override-app-domains.yml -v app_domains='((terraform_outputs_cf_apps_domain))' \
    -o operations/rename-deployment.yml -v deployment_name='((environment))' \
    -o operations/stop-skipping-tls-validation.yml \
    -o operations/enable-uniq-consul-node-name.yml \
    ${ops500s} \
    ${ops600s} \
    cf-deployment.yml
  )
}

orig_paas_cf_manifest() {
  cat manifests/cf-manifest/manifest/000-base-cf-deployment.yml
}

spruce diff <(cf_deployment_manifest) <(orig_paas_cf_manifest) | \
  gsed  '/^ *\$/{s/^ *\$//;s/\[\(.[^]]*\)\]/\/name=\1/g;s/\./\//g}'
