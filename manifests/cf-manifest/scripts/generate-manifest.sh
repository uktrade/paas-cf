#!/bin/bash

set -eu -o pipefail

PAAS_CF_DIR=${PAAS_CF_DIR:-paas-cf}
CF_DEPLOYMENT_DIR=${PAAS_CF_DIR}/manifests/cf-deployment
WORKDIR=${WORKDIR:-.}

datadog_opsfile=${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/noop.yml
if [ "${ENABLE_DATADOG}" = "true" ] ; then
  datadog_opsfile="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/090-datadog-nozzle.yml"
fi

oauth_opsfile=${PAAS_CF_DIR}/manifests/cf-manifest//manifest/operations/noop.yml
if [ "${DISABLE_USER_CREATION}" = "false" ] ; then
   oauth_opsfile="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/100-oauth.yml"
fi

ops500s=""
for i in ${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/5*.yml; do
  ops500s="$ops500s -o $i"
done

ops600s=""
for i in ${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/6*.yml; do
  ops600s="$ops600s -o $i"
done

# shellcheck disable=SC2086
bosh interpolate \
  --var-file ipsec_ca.private_key="${WORKDIR}/ipsec-CA/ipsec-CA.key" \
  --var-file ipsec_ca.certificate="${WORKDIR}/ipsec-CA/ipsec-CA.crt" \
  --vars-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/data/000-aws-rds-combined-ca-bundle-pem.yml" \
  --vars-file="${WORKDIR}/terraform-outputs/vpc.yml" \
  --vars-file="${WORKDIR}/terraform-outputs/bosh.yml" \
  --vars-file="${WORKDIR}/terraform-outputs/concourse.yml" \
  --vars-file="${WORKDIR}/terraform-outputs/cf.yml" \
  --vars-file="${WORKDIR}/cf-secrets/cf-secrets.yml" \
  --vars-file="${PAAS_CF_DIR}/manifests/variables.yml" \
  --vars-file="${PAAS_CF_DIR}/manifests/cf-manifest/static-ips-and-ports.yml" \
  --vars-file="${CF_ENV_SPECIFIC_MANIFEST}" \
  --vars-file="${WORKDIR}/environment-variables/environment-variables.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/rename-network.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/aws.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/use-s3-blobstore.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/use-external-dbs.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/stop-skipping-tls-validation.yml" \
  --ops-file="${CF_DEPLOYMENT_DIR}/operations/enable-uniq-consul-node-name.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/030-legacy-stemcells.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/040-graphite.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/050-rds-broker.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/060-cdn-broker.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/070-elasticache-broker.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/080-logsearch.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/200-paas-admin-uaa-client.yml" \
  ${ops500s} \
  ${ops600s} \
  --ops-file="${WORKDIR}/grafana-dashboards-opsfile/grafana-dashboards-opsfile.yml" \
  --ops-file="${WORKDIR}/vpc-peering-opsfile/vpc-peers.yml" \
  --ops-file="${datadog_opsfile}" \
  --ops-file="${oauth_opsfile}" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/900-cert-rotation.yml" \
  --ops-file="${PAAS_CF_DIR}/manifests/cf-manifest/manifest/operations/999-prune.yml" \
  "$@" \
  "${CF_DEPLOYMENT_DIR}/cf-deployment.yml"
