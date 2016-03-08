#!/bin/bash
set -euo pipefail

CONCOURSE_URL=$1
FLY_CMD=fly-"${DEPLOY_ENV}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

$("${SCRIPT_DIR}"/../../vagrant/environment.sh ${DEPLOY_ENV})

if [ ! -x "$FLY_CMD" ]; then
  FLY_CMD_URL="$CONCOURSE_URL/api/v1/cli?arch=amd64&platform=$(uname | tr '[:upper:]' '[:lower:]')"
  echo "Downloading fly command..." 1>&2
  curl "$FLY_CMD_URL" -o "$FLY_CMD" -u ${CONCOURSE_ATC_USER}:${CONCOURSE_ATC_PASSWORD} --silent
  chmod +x "$FLY_CMD"
fi

cat <<EOF
export FLY_CMD=${FLY_CMD}
EOF

$FLY_CMD login -t "${FLY_TARGET}" --concourse-url "${CONCOURSE_URL}"
