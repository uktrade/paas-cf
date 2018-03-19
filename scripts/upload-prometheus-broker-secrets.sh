#!/bin/sh

set -eu

export PASSWORD_STORE_DIR=${PROMETHEUS_BROKER_PASSWORD_STORE_DIR}

PROMETHEUS_BROKER_AWS_ACCESS_KEY_ID=$(pass "prometheus-broker/aws-access-key")
PROMETHEUS_BROKER_AWS_SECRET_KEY_ID=$(pass "prometheus-broker/aws-secret-key")
PROMETHEUS_BROKER_UAA_PASSWORD=$(pass "prometheus-broker/uaa-password")
PROMETHEUS_BROKER_UAA_USERNAME=$(pass "prometheus-broker/uaa-username")

SECRETS=$(mktemp secrets.yml.XXXXXX)
trap 'rm  "${SECRETS}"' EXIT

cat > "${SECRETS}" << EOF
---
prometheus_broker_aws_access_key_id: ${PROMETHEUS_BROKER_AWS_ACCESS_KEY_ID}
prometheus_broker_aws_secret_key_id: ${PROMETHEUS_BROKER_AWS_SECRET_KEY_ID}
prometheus_broker_uaa_password: ${PROMETHEUS_BROKER_UAA_PASSWORD}
prometheus_broker_uaa_username: ${PROMETHEUS_BROKER_UAA_USERNAME}
EOF

aws s3 cp "${SECRETS}" "s3://gds-paas-${DEPLOY_ENV}-state/prometheus-broker-secrets.yml"
