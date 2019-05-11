#!/bin/sh

set -eu

export PASSWORD_STORE_DIR=${OAUTH_PASSWORD_STORE_DIR}

MICROSOFT_IDENTITY_TENANTID=$(pass "microsoft/identity/${MAKEFILE_ENV_TARGET}/tenantid")
MICROSOFT_IDENTITY_OAUTH_CLIENT_ID=$(pass "microsoft/identity/${MAKEFILE_ENV_TARGET}/oauth/client_id")
MICROSOFT_IDENTITY_OAUTH_CLIENT_SECRET=$(pass "microsoft/identity/${MAKEFILE_ENV_TARGET}/oauth/client_secret")

SECRETS=$(mktemp secrets.yml.XXXXXX)
trap 'rm  "${SECRETS}"' EXIT

cat > "${SECRETS}" << EOF
---
secrets:
  microsoft_identity_tenantid: ${MICROSOFT_IDENTITY_TENANTID}
  microsoft_identity_oauth_client_id: ${MICROSOFT_IDENTITY_OAUTH_CLIENT_ID}
  microsoft_identity_oauth_client_secret: ${MICROSOFT_IDENTITY_OAUTH_CLIENT_SECRET}
EOF

aws s3 cp "${SECRETS}" "s3://gds-paas-${DEPLOY_ENV}-state/microsoft-identity-secrets.yml"
