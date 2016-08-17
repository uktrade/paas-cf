#!/bin/bash

set -eux

SCRIPT_NAME="$0"
export AWS_DEFAULT_REGION=eu-west-1

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)

abort() {
  echo "$@" 1>&2
  exit 1
}

usage() {
  cat <<EOF

This script will restore a RDS backup using AWS restore point in time, or recover from a snapshot.

In order for this script to work you must:
 * Have cf-cli on your PATH.
 * Have aws-cli on your PATH.
 * Have jq (https://stedolan.github.io/jq/) on your PATH.
 * Login into cf as a OrgManager or Admin user.
 * Target the organisation where the services reside and must be restored.
 * Export the AWS credentials for the AWS account that hosts the RDS instances

Usage:

$SCRIPT_NAME point-in-time <from-service-instance> <to-service-instance> <time-stamp>

Restores an existing DB service to a point in time, creating a new service instance for the restored DB.
The original service instance is unchanged.

 * from-service-instance: CF service instance to restore from.
 * to-service-instance: Name of the new service instance created.
 * time-stamp: time to restore from, in iso-8601 UTC format: "2016-08-09T09:07:16Z"

$SCRIPT_NAME snapshot <aws-snapshot-name> <to-service-instance> <plan>

Restores a final snapshot of a DB service, creating a new service instance for the restored DB.
The original service instance is assumed to already have been deleted.

 * aws-snapshot-name: AWS snapshot to restore from.
 * to-service-instance: Name of the new service created.
 * plan: plan to use from the marketplace of postgres.

In both usage cases, the script will:
 1. Create a service instance using cf-cli.
 2. Throw away the RDS instance created by cf-cli, but keep the reference in CF.
 3. Restore the backup to a new RDS instance.
 4. Rename the restored instance to the name created in 1, and deleted in 2.

Limitations:

 After the script finishes, there will be an RDS instance with the restored db, and a CF service instance pointing at it.
 Because of the way we have to delete and rename the RDS instances without notificying CF in order to perform the restore,
 CF will have the wrong state for the new service instance - it will appear that the create failed.
 In fact, after the script finishes the new service instance should be fine - we have tested we can bind it to an app and hit the /db endpoint.

 We don't currently supply the correct master password seed to the script (see TODO below).
 Thus, we cannot bind to the new service instance until we have manually set the correct password.
 A quickish way to workaround this is to restart an rds-broker, as it resets passwords for instances it cannot log in to on startup.

EOF
  abort
}

extract_existing_instance_info() {
  local instance_name="$1"
  instance_info_json=/tmp/instance_info.$$.json
  trap 'rm -f "${instance_info_json}"' EXIT INT TERM

  echo "Extracting RDS settings of temporary RDS instance ${instance_name}..."
  aws rds describe-db-instances \
    --region "${AWS_DEFAULT_REGION}" \
    --db-instance-identifier "${instance_name}" > "${instance_info_json}"
  DESIRED_DB_INSTANCE_CLASS="$(jq -r '.DBInstances[0].DBInstanceClass' < ${instance_info_json})"
  DESIRED_DB_SUBNET_GROUP_NAME="$(jq -r '.DBInstances[0].DBSubnetGroup.DBSubnetGroupName' < ${instance_info_json})"
  DESIRED_ENGINE="$(jq -r '.DBInstances[0].Engine' < ${instance_info_json})"
  DESIRED_OPTION_GROUP_NAME="$(jq -r '.DBInstances[0].OptionGroupMemberships[0].OptionGroupName' < ${instance_info_json})"
  DESIRED_STORAGE_TYPE="$(jq -r '.DBInstances[0].StorageType' < ${instance_info_json})"
  DESIRED_DB_PARAMETER_GROUP_NAME="$(jq -r '.DBInstances[0].DBParameterGroups[0].DBParameterGroupName' < ${instance_info_json})"
  DESIRED_VPC_SECURITY_GROUP_IDS="$(jq -r '.DBInstances[0].VpcSecurityGroups | map(.VpcSecurityGroupId)' < ${instance_info_json} | xargs)"
  DESIRED_BACKUP_RETENTION_PERIOD="$(jq -r '.DBInstances[0].BackupRetentionPeriod' < ${instance_info_json})"

  DESIRED_TAGS=$(
    aws rds list-tags-for-resource \
      --region "${AWS_DEFAULT_REGION}" \
      --resource-name "arn:aws:rds:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:db:${instance_name}" \
      --query TagList
  )

  rm -f "${instance_info_json}"

  # Print the settings
  ( set -o posix ; set ) | grep DESIRED | sed 's/^/    /'
}

create_new_cf_instance() {
  # Will create a CF instance, and the RDS one will be being deleted in background

  echo "Creating new instance $TO_INSTANCE_NAME in Cloudfoundry..."
  if cf service "${TO_INSTANCE_NAME}" > /dev/null; then
    abort "ERROR: Service ${TO_INSTANCE_NAME} already exists, aborting..."
  fi
  cf create-service "${SERVICE_TYPE}" "${SERVICE_PLAN}" "${TO_INSTANCE_NAME}"

  if ! TO_INSTANCE_GUID=$(cf service "${TO_INSTANCE_NAME}" --guid); then
    abort "Unable to get new service instance GUID: ${TO_INSTANCE_GUID}"
  fi

  TO_RDS_INSTANCE_NAME="rdsbroker-${TO_INSTANCE_GUID}"

  # Extract the attributes (Security groups, DB parameters, etc.) from the recently created DB.
  # This way we don't need to parse the settings from YAMLs
  extract_existing_instance_info "${TO_RDS_INSTANCE_NAME}"

  echo "Deleting temporary AWS RDS instance that has been just created: ${TO_RDS_INSTANCE_NAME}..."
  aws rds delete-db-instance \
    --region "${AWS_DEFAULT_REGION}" \
    --db-instance-identifier "${TO_RDS_INSTANCE_NAME}" \
    --skip-final-snapshot > /dev/null
}

trigger_restore_instance() {
  # Will trigger a backup in background
  case "$RESTORE_TYPE" in
    point-in-time)
      echo "Restoring RDS instance ${FROM_RDS_INSTANCE_NAME} into ${TO_RDS_INSTANCE_NAME}-restore from point in time ${RESTORE_DATE}"
      aws rds restore-db-instance-to-point-in-time \
        --region "${AWS_DEFAULT_REGION}" \
        --source-db-instance-identifier "${FROM_RDS_INSTANCE_NAME}" \
        --target-db-instance-identifier "${TO_RDS_INSTANCE_NAME}-restore" \
        --restore-time "${RESTORE_DATE}" \
        --db-instance-class "${DESIRED_DB_INSTANCE_CLASS}" \
        --db-subnet-group-name "${DESIRED_DB_SUBNET_GROUP_NAME}" \
        --copy-tags-to-snapshot \
        --engine "${DESIRED_ENGINE}" \
        --option-group-name "${DESIRED_OPTION_GROUP_NAME}" \
        --storage-type "${DESIRED_STORAGE_TYPE}" > /dev/null
    ;;
    snapshot)
      echo "Restoring snapshot ${FROM_RDS_SNAPSHOT_NAME} into ${TO_RDS_INSTANCE_NAME}-restore"
      aws rds restore-db-instance-from-db-snapshot \
        --db-snapshot-identifier "${FROM_RDS_SNAPSHOT_NAME}" \
        --db-instance-identifier "${TO_RDS_INSTANCE_NAME}-restore" \
        --db-instance-class "${DESIRED_DB_INSTANCE_CLASS}" \
        --db-subnet-group-name "${DESIRED_DB_SUBNET_GROUP_NAME}" \
        --copy-tags-to-snapshot \
        --engine "${DESIRED_ENGINE}" \
        --option-group-name "${DESIRED_OPTION_GROUP_NAME}" \
        --storage-type "${DESIRED_STORAGE_TYPE}" > /dev/null
    ;;
    *)
      abort "not implemented"
    ;;
  esac
}

modify_new_instance() {
  # We must reset the master password
  TO_MASTER_PASSWORD=$(
    echo -n "${RDS_BROKER_MASTER_PASSWORD_SEED}${TO_INSTANCE_GUID}" | \
      openssl dgst -md5 -binary | \
      openssl enc -base64 | \
      tr '+/' '-_'
    )

  echo "Applying tags to ${TO_RDS_INSTANCE_NAME}-restore to match desired ones"
  aws rds add-tags-to-resource \
    --region "${AWS_DEFAULT_REGION}" \
    --resource-name "arn:aws:rds:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:db:${TO_RDS_INSTANCE_NAME}-restore" \
    --tags "${DESIRED_TAGS}"

  echo "Modifying AWS settings of ${TO_RDS_INSTANCE_NAME}-restore to match desired ones"
  aws rds modify-db-instance \
    --region "${AWS_DEFAULT_REGION}" \
    --db-instance-identifier "${TO_RDS_INSTANCE_NAME}-restore" \
    --new-db-instance-identifier  "${TO_RDS_INSTANCE_NAME}" \
    --db-parameter-group-name "${DESIRED_DB_PARAMETER_GROUP_NAME}" \
    --vpc-security-group-ids "${DESIRED_VPC_SECURITY_GROUP_IDS}" \
    --backup-retention-period "${DESIRED_BACKUP_RETENTION_PERIOD}" \
    --master-user-password "${TO_MASTER_PASSWORD}" \
    --apply-immediately
}

get_instance_status() {
  aws rds describe-db-instances \
    --region "${AWS_DEFAULT_REGION}" \
    --db-instance-identifier "$1" \
    --query 'DBInstances[0].DBInstanceStatus'
}

wait_for_rds_instance_available() {
  echo -n "Waiting for RDS instance $1 to be available..."
  while true; do
    if output=$(get_instance_status "$1" 2>&1); then
      if echo "$output" | grep -q available; then
        break
      else
        echo -n .;
        sleep 5
      fi
    else
      echo
      abort "Error: $output"
    fi
  done
  echo
}

wait_for_rds_instance_deleted() {
  echo -n "Waiting for RDS instance $1 to be deleted..."
  while true; do
    if ! output=$(get_instance_status "$1" 2>&1); then
      if echo "$output" | grep -q DBInstanceNotFound; then
        break
      else
        echo
        abort "Error: $output"
      fi
    fi
    echo -n .
    sleep 5
  done
  echo
}

set_point_in_time_vars() {
  if [ $# -lt 3 ]; then
    usage
  fi

  # TODO
  RDS_BROKER_MASTER_PASSWORD_SEED="mysecret"

  FROM_INSTANCE_GUID=""
  SERVICE_PLAN=""

  FROM_INSTANCE_NAME="$1"
  TO_INSTANCE_NAME="$2"
  # Value must be a time in Universal Coordinated Time (UTC) format
  RESTORE_DATE="$3"

  if ! INSTANCE_INFO="$(cf service "${FROM_INSTANCE_NAME}")"; then
    abort "Unable to get original service instance ${FROM_INSTANCE_NAME} info: ${INSTANCE_INFO}"
  fi
  if ! FROM_INSTANCE_GUID="$(cf service "${FROM_INSTANCE_NAME}" --guid)"; then
    abort "Unable to get original service instance GUID: ${FROM_INSTANCE_GUID}"
  fi
  SERVICE_TYPE="$(echo "${INSTANCE_INFO}" | sed -n 's/^Service: //p')"
  SERVICE_PLAN="$(echo "${INSTANCE_INFO}" | sed -n 's/^Plan: //p')"
  FROM_RDS_INSTANCE_NAME="rdsbroker-${FROM_INSTANCE_GUID}"
}

set_snapshot_vars() {
  if [ $# -lt 3 ]; then
    usage
  fi

  FROM_RDS_SNAPSHOT_NAME="$1"
  TO_INSTANCE_NAME="$2"
  SERVICE_PLAN="$3"
  SERVICE_TYPE="postgres"
}

if [ $# -lt 1 ]; then
  usage
fi
RESTORE_TYPE=${1:-}
shift

case "$RESTORE_TYPE" in
  point-in-time)
    set_point_in_time_vars "$@"
  ;;
  snapshot)
    set_snapshot_vars "$@"
  ;;
  *)
    usage
  ;;
esac

create_new_cf_instance
trigger_restore_instance

wait_for_rds_instance_available "${TO_RDS_INSTANCE_NAME}-restore"
wait_for_rds_instance_deleted "${TO_RDS_INSTANCE_NAME}"

modify_new_instance

echo "Done :)"
