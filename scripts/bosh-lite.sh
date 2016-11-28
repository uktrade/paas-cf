#!/bin/bash

set -eu
set -o pipefail

SCRIPT_NAME="$0"
PROJECT_DIR="$(cd "$(dirname "${SCRIPT_NAME}")/.."; pwd)"
PROJECT_DIR_PARENT="$(cd "${PROJECT_DIR}/.."; pwd)"

# Set to false to disable autohalt
BOSH_LITE_AUTO_HALT=${BOSH_LITE_AUTO_HALT:-true}

# Defaults
DEFAULT_BOSH_LITE_INSTANCE_TYPE=m3.xlarge
DEFAULT_BOSH_LITE_CODEBASE_PATH="${PROJECT_DIR_PARENT}/bosh-lite"
DEFAULT_BOSH_LITE_REGION="eu-west-1"
DEFAULT_BOSH_LITE_VPC_TAG_NAME_SUFFIX="bosh-lite-vpc"
DEFAULT_BOSH_LITE_SUBNET_TAG_NAME_SUFFIX="bosh-lite-subnet-0"
DEFAULT_BOSH_LITE_SECURITY_GROUP_TAG_NAME_SUFFIX="bosh-lite-office-access"

DEFAULT_BOSH_LITE_ALLOWED_CIDRS="80.194.77.90/32 80.194.77.100/32 85.133.67.244/32"
DEFAULT_BOSH_LITE_ALLOWED_PORTS="22 25555"

usage() {
  cat <<EOF
Start a bosh-lite instance in AWS.

Usage:
  $SCRIPT_NAME <start|stop|destroy|info|ssh>

Actions:

  start         Start bosh-lite
  stop          Halt bosh-lite
  destroy       Destroy bosh-lite
  info          Print bosh-lite info
  ssh           SSH or execute commands on the bosh-lite instance

Requirements:
 * Exported \$DEPLOY_ENV variable
 * Exported AWS credentials as \$AWS_ACCESS_KEY_ID and \$AWS_SECRET_ACCESS_KEY
 * aws_cli installed
 * vagrant and vagrant-aws plugin

Variables to override:

  BOSH_LITE_INSTANCE_TYPE:
    VM size for this VM. More info: https://aws.amazon.com/ec2/instance-types/
    Default: ${DEFAULT_BOSH_LITE_INSTANCE_TYPE}

  BOSH_LITE_CODEBASE_PATH:
    Where bosh-lite code is cloned
    Default: ${DEFAULT_BOSH_LITE_CODEBASE_PATH}

  BOSH_LITE_SUBNET_TAG_NAME:
    VPC tag 'Name' to deploy to. Will be created if missing.
    Default: \${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_VPC_TAG_NAME_SUFFIX}

  BOSH_LITE_SUBNET_TAG_NAME:
    Subnet tag 'Name' to deploy to. Will be created if missing.
    Default: \${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_SUBNET_TAG_NAME_SUFFIX}

  BOSH_LITE_SECURITY_GROUP_TAG_NAME:
    Security Group tag 'Name' to use for bosh-lite. Will be created if missing.
    Default: \${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_SECURITY_GROUP_TAG_NAME_SUFFIX}

  BOSH_LITE_ALLOWED_CIDRS:
    CIDRs to allow when creating the security group
    Note: Won't be updated if the SG already exists.
    Default: ${DEFAULT_BOSH_LITE_ALLOWED_CIDRS}

  BOSH_LITE_ALLOWED_PORTS:
    Ports in bosh-lite to allow when creating the security group
    Note: Won't be updated if the SG already exists.
    Default: ${DEFAULT_BOSH_LITE_ALLOWED_PORTS}

  BOSH_LITE_REGION:
    Bosh lite region to deploy
    Defaul: ${DEFAULT_BOSH_LITE_REGION}

EOF

  exit 0
}

check_bosh_lite_codebase() {
  if [ ! -f "${BOSH_LITE_CODEBASE_PATH}/Vagrantfile" ]; then
    cat <<EOF
Path ${BOSH_LITE_CODEBASE_PATH} does not seem to contain the bosh-lite code base"

You can clone it by running:

  git clone https://github.com/cloudfoundry/bosh-lite.git "${BOSH_LITE_CODEBASE_PATH}"

or export \$BOSH_LITE_CODEBASE_PATH to a path containing the bosh-lite code.

EOF
    exit 1
  fi
}

check_vagrant() {
  if ! ( which vagrant > /dev/null && vagrant plugin list | grep -q vagrant-aws); then
    cat <<EOF
You must have vagrant installed in your system with the vagrant-aws plugin.

1. Check https://www.vagrantup.com/docs/installation/ to install vagrant
2. run 'vagrant plugin install vagrant-aws' to install the vagrant-aws plugin
EOF
    exit 1
  fi
}

get_vagrant_box() {
  if ! vagrant box list | grep -qe 'cloudfoundry/bosh-lite .*aws'; then
    vagrant box add cloudfoundry/bosh-lite --provider aws
  fi
}

init_environment() {
  if [ -z "${DEPLOY_ENV:-}" ]; then
    echo "Error: You must set \$DEPLOY_ENV"
    exit 1
  fi

  export BOSH_LITE_NAME="${DEPLOY_ENV}-bosh-lite"
  export BOSH_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
  export BOSH_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

  export BOSH_LITE_CODEBASE_PATH="${BOSH_LITE_CODEBASE_PATH:-$DEFAULT_BOSH_LITE_CODEBASE_PATH}"

  export BOSH_LITE_INSTANCE_TYPE="${BOSH_LITE_INSTANCE_TYPE:-${DEFAULT_BOSH_LITE_INSTANCE_TYPE}}"
  export BOSH_LITE_CODEBASE_PATH="${BOSH_LITE_CODEBASE_PATH:-${DEFAULT_BOSH_LITE_CODEBASE_PATH}}"
  export BOSH_LITE_REGION="${BOSH_LITE_REGION:-${DEFAULT_BOSH_LITE_REGION}}"

  export BOSH_LITE_VPC_TAG_NAME="${BOSH_LITE_VPC_TAG_NAME:-${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_VPC_TAG_NAME_SUFFIX}}"
  export BOSH_LITE_SUBNET_TAG_NAME="${BOSH_LITE_SUBNET_TAG_NAME:-${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_SUBNET_TAG_NAME_SUFFIX}}"
  export BOSH_LITE_SECURITY_GROUP_TAG_NAME="${BOSH_LITE_SECURITY_GROUP_TAG_NAME:-${DEPLOY_ENV}-${DEFAULT_BOSH_LITE_SECURITY_GROUP_TAG_NAME_SUFFIX}}"

  export BOSH_LITE_ALLOWED_CIDRS="${BOSH_LITE_ALLOWED_CIDRS:-${DEFAULT_BOSH_LITE_ALLOWED_CIDRS}}"
  export BOSH_LITE_ALLOWED_PORTS="${BOSH_LITE_ALLOWED_PORTS:-${DEFAULT_BOSH_LITE_ALLOWED_PORTS}}"
}

get_aws_key_pair_finger_print() {
  aws ec2 describe-key-pairs \
    --region "${BOSH_LITE_REGION}" \
    --filters "Name=key-name,Values=${BOSH_LITE_KEYPAIR}" \
    --query "KeyPairs[0].KeyFingerprint" \
    --output text
}

init_ssh_key_vars() {
  export BOSH_LITE_KEYPAIR="${DEPLOY_ENV}_bosh_lite_ssh_key_pair"

  # Get SSH key pair from the state
  SSH_DIR="${BOSH_LITE_CODEBASE_PATH}/.vagrant/.ssh"
  mkdir -p "${SSH_DIR}"
  export BOSH_LITE_PRIVATE_KEY="${SSH_DIR}/id_rsa"
  if [ ! -f "${BOSH_LITE_PRIVATE_KEY}" ]; then
    echo "SSH key is missing, regenerating..."
    ssh-keygen -f "${BOSH_LITE_PRIVATE_KEY}" -P ""
    chmod 600 "${BOSH_LITE_PRIVATE_KEY}"
  fi

  local aws_key_finger_print
  aws_key_finger_print=$(get_aws_key_pair_finger_print)
  local local_key_finger_print
  local_key_finger_print=$(if [ -f "${BOSH_LITE_PRIVATE_KEY}.fingerprint" ]; then cat "${BOSH_LITE_PRIVATE_KEY}.fingerprint"; fi)

  if [ "${aws_key_finger_print}" != "${local_key_finger_print}" ]; then
    echo "Updating AWS Key ${BOSH_LITE_KEYPAIR}"
    if [ "${aws_key_finger_print}" != "None" ]; then
      aws ec2 delete-key-pair \
        --region "${BOSH_LITE_REGION}" \
        --key-name "${BOSH_LITE_KEYPAIR}" > /dev/null || true
    fi
    aws ec2 import-key-pair \
      --region "${BOSH_LITE_REGION}" \
      --key-name "${BOSH_LITE_KEYPAIR}" \
      --public-key-material "$(cat "${BOSH_LITE_PRIVATE_KEY}.pub")" > /dev/null
    get_aws_key_pair_finger_print > "${BOSH_LITE_PRIVATE_KEY}.fingerprint"
  fi
}

delete_ssh_key_pair() {
  aws ec2 delete-key-pair \
    --region "${BOSH_LITE_REGION}" \
    --key-name "${BOSH_LITE_KEYPAIR}" > /dev/null || true
}

build_aws_cli_tag_filter() {
  local pair
  local filter
  filter=""
  for pair in "$@"; do
    filter="${filter:+${filter},}Name=tag:${pair%:*},Values=${pair#*:}"
  done
  echo "${filter}"
}

find_vpc_by_tags() {
  local tag_filter
  tag_filter="$(build_aws_cli_tag_filter "$@")"
  aws ec2 describe-vpcs \
    --region "${BOSH_LITE_REGION}" \
    --filters "${tag_filter}" \
    --query 'Vpcs[0].VpcId' \
    --output text
}

find_route_table_by_tags() {
  local tag_filter
  tag_filter="$(build_aws_cli_tag_filter "$@")"
  aws ec2 describe-route-tables \
    --region "${BOSH_LITE_REGION}" \
    --filters "${tag_filter}" \
    --query 'RouteTables[0]RouteTableId' \
    --output text
}

find_subnet_by_tags() {
  local tag_filter
  tag_filter="$(build_aws_cli_tag_filter "$@")"
  aws ec2 describe-subnets \
    --region "${BOSH_LITE_REGION}" \
    --filters "${tag_filter}" \
    --query 'Subnets[0].SubnetId' \
    --output text
}

find_security_group_by_tags() {
  local tag_filter
  tag_filter="$(build_aws_cli_tag_filter "$@")"
  aws ec2 describe-security-groups \
    --region "${BOSH_LITE_REGION}" \
    --filters "${tag_filter}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text
}

create_dedicated_subnet_and_security_group() {
  local vpcid
  local subnetid
  local sgid

  vpcid=$(find_vpc_by_tags "Name:${BOSH_LITE_VPC_TAG_NAME}")
  if [ "$vpcid" == "None" ]; then
    echo "Creating missing VPC with Name:${BOSH_LITE_VPC_TAG_NAME}"
    vpcid="$(
      aws ec2 create-vpc \
        --region "${BOSH_LITE_REGION}" \
        --cidr-block 10.244.0.32/28 \
        --query Vpc.VpcId \
        --output text
    )"
    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${vpcid}" \
      --tags "Key=Name,Value=${BOSH_LITE_VPC_TAG_NAME}"
    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${vpcid}" \
      --tags "Key=Created-by,Value=bosh-lite.sh"

  fi
  echo "Using VPC ${vpcid} with Name:${BOSH_LITE_VPC_TAG_NAME}"

  # TODO: Create the routing table :(

  subnetid=$(find_subnet_by_tags "Name:${BOSH_LITE_SUBNET_TAG_NAME}")
  if [ "$subnetid" == "None" ]; then
    echo "Creating missing Subnet with Name:${BOSH_LITE_SUBNET_TAG_NAME}"
    subnetid="$(
      aws ec2 create-subnet \
        --region "${BOSH_LITE_REGION}" \
        --cidr-block 10.244.0.32/28 \
        --vpc-id "${vpcid}" \
        --cidr-block "10.244.0.32/28" \
        --query Subnet.SubnetId \
        --output text
    )"

    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${subnetid}" \
      --tags "Key=Name,Value=${BOSH_LITE_SUBNET_TAG_NAME}"
    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${subnetid}" \
      --tags "Key=Created-by,Value=bosh-lite.sh"

    aws ec2 modify-subnet-attribute \
      --region "${BOSH_LITE_REGION}" \
      --subnet-id "${subnetid}" \
      --map-public-ip-on-launch
  fi
  echo "Using Subnet ${subnetid} with Name:${BOSH_LITE_SUBNET_TAG_NAME}"

  sgid="$(find_security_group_by_tags "Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}")"
  if [ "$sgid" == "None" ]; then
    echo "Creating missing Security Group with Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}"
    sgid="$(
      aws ec2 create-security-group \
        --region "${BOSH_LITE_REGION}" \
        --group-name "${BOSH_LITE_SECURITY_GROUP_TAG_NAME}" \
        --description "${DEPLOY_ENV} bosh-lite: Allow access from Office and management IPs" \
        --vpc-id "${vpcid}" \
        --query GroupId \
        --output text
    )"
    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${sgid}" \
      --tags "Key=Name,Value="${BOSH_LITE_SECURITY_GROUP_TAG_NAME}""
    aws ec2 create-tags \
      --region "${BOSH_LITE_REGION}" \
      --resources "${sgid}" \
      --tags "Key=Created-by,Value=bosh-lite.sh"

    local cidr
    local port
    for cidr in ${BOSH_LITE_ALLOWED_CIDRS}; do
      for port in ${BOSH_LITE_ALLOWED_PORTS}; do
        aws ec2 authorize-security-group-ingress \
          --region "${BOSH_LITE_REGION}" \
          --group-id "${sgid}" \
          --protocol "tcp" \
          --port "${port}" \
          --cidr "${cidr}"
      done
    done
  fi
  echo "Using Security Group ${sgid} with Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}"
}

delete_dedicated_subnet_and_security_group() {
  sgid="$(find_security_group_by_tags "Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}" "Created-by:bosh-lite.sh")"
  if [ "$sgid" != "None" ]; then
    echo "Deleting Security Group with Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}"
    aws ec2 delete-security-group \
      --region "${BOSH_LITE_REGION}" \
      --group-id "${sgid}"
  fi

  subnetid=$(find_subnet_by_tags "Name:${BOSH_LITE_SUBNET_TAG_NAME}" "Created-by:bosh-lite.sh")
  if [ "$subnetid" != "None" ]; then
    echo "Deleting Subnet with Name:${BOSH_LITE_SUBNET_TAG_NAME}"
    aws ec2 delete-subnet \
      --region "${BOSH_LITE_REGION}" \
      --subnet-id "${subnetid}"
  fi

  vpcid=$(find_vpc_by_tags "Name:${BOSH_LITE_VPC_TAG_NAME}" "Created-by:bosh-lite.sh")
  if [ "$vpcid" != "None" ]; then
    echo "Deleting VPC with Name:${BOSH_LITE_VPC_TAG_NAME}"
    aws ec2 delete-vpc \
      --region "${BOSH_LITE_REGION}" \
      --vpc-id "${vpcid}"
  fi
}



init_subnet_and_security_group_vars() {
  # Query the subnet tagged as Name=bosh-lite-subnet-0
  BOSH_LITE_SUBNET_ID="$(find_subnet_by_tags "Name:${BOSH_LITE_SUBNET_TAG_NAME}")"
  export BOSH_LITE_SUBNET_ID
  if ! aws ec2 describe-subnets --region "${BOSH_LITE_REGION}" --subnet-ids "${BOSH_LITE_SUBNET_ID}" > /dev/null; then
    echo
    echo "ERROR: Cannot find valid subnet with Tag '${BOSH_LITE_SUBNET_TAG_NAME}'. Did you create it first?"
    exit 1
  fi

  # Query the security group tagged as Name=bosh-lite-office-access
  BOSH_LITE_SECURITY_GROUP="$(find_security_group_by_tags "Name:${BOSH_LITE_SECURITY_GROUP_TAG_NAME}")"
  export BOSH_LITE_SECURITY_GROUP
  if ! aws ec2 describe-security-groups --region "${BOSH_LITE_REGION}" --group-ids "${BOSH_LITE_SECURITY_GROUP}" > /dev/null; then
    echo
    echo "ERROR: Cannot find valid security group with Tag '${BOSH_LITE_SECURITY_GROUP_TAG_NAME}'. Did you create it first?"
    exit 1
  fi
}

run_vagrant() {
  (
    cd "${BOSH_LITE_CODEBASE_PATH}"
    vagrant "$@"
  )
}

configure_auto_halt() {
  if [ "${BOSH_LITE_AUTO_HALT}" == "true" ]; then
    # m h dom mon dow user  command
    echo "0 19 * * * root /sbin/halt -p" | run_vagrant ssh -- sudo tee /etc/cron.d/auto_halt > /dev/null
    run_vagrant ssh -- sudo /etc/init.d/cron restart > /dev/null
  else
    rm -f /etc/cron.d/auto_halt
  fi
}

get_vagrant_state() {
  aws ec2 describe-instances \
    --region "${BOSH_LITE_REGION}" \
    --filter "Name=tag:Name,Values=${BOSH_LITE_NAME}" \
    --query 'Reservations[*].Instances[*].State.Name' \
    --output text | grep -v terminated
}

get_vagrant_public_ip() {
  aws ec2 describe-instances \
    --region "${BOSH_LITE_REGION}" \
    --filter "Name=tag:Name,Values=${BOSH_LITE_NAME}" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text
}

get_vagrant_private_ip() {
  aws ec2 describe-instances \
    --region "${BOSH_LITE_REGION}" \
    --filter "Name=tag:Name,Values=${BOSH_LITE_NAME}" \
    --query 'Reservations[*].Instances[*].PrivateIpAddress' \
    --output text
}

get_admin_password() {
  run_vagrant ssh -- sudo /etc/init.d/cron restart > /dev/null
}

update_and_get_admin_password() {
  echo "Updating and getting admin password..."
  cat <<EOF | run_vagrant ssh -- tee update_director_password.rb > /dev/null
#!/bin/env ruby

require 'yaml'

config = YAML.load_file('/var/vcap/jobs/director/config/director.yml.erb')
if config["user_management"]["local"]["users"] == []
  puts "Generating new password and restaring bosh..."
  new_password = (1..12).map{|i| ('a'..'z').to_a[rand(26)]}.join
  config["user_management"]["local"]["users"] =  [{"name" => "admin", "password" => new_password}]
  File.open('/var/vcap/jobs/director/config/director.yml.erb', 'w') { |file| file.write(YAML.dump(config)) }
  system("/var/vcap/bosh/bin/monit restart director")
  sleep 20
else
  puts "Admin password already changed, not updated."
end

puts "\nBosh-lite admin password is: #{config["user_management"]["local"]["users"][0]["password"]}\n\n"
EOF

  run_vagrant ssh -- sudo ruby ./update_director_password.rb
}

print_info() {
  BOSH_LITE_PUBLIC_IP=$(get_vagrant_public_ip)
  BOSH_LITE_PRIVATE_IP=$(get_vagrant_private_ip)
  echo "Bosh-Lite state: $(get_vagrant_state)"
  if [ -z "${BOSH_LITE_PUBLIC_IP}" ] && [ -z "${BOSH_LITE_PRIVATE_IP}" ]; then
    echo "Cannot find the public or private IP for a bosh-lite VM with name '${BOSH_LITE_NAME}' in region ${BOSH_LITE_REGION}. Is it running?"
    return
  fi
  cat <<EOF
Bosh-Lite public IP: ${BOSH_LITE_PUBLIC_IP:-n/a}
Bosh-Lite private IP: ${BOSH_LITE_PRIVATE_IP}

Add it as a target by running:

  bosh target ${BOSH_LITE_PUBLIC_IP}

  or

  bosh target ${BOSH_LITE_PRIVATE_IP}

SSH to it running:

  DEPLOY_ENV=${DEPLOY_ENV} $SCRIPT_NAME ssh

or

  DEPLOY_ENV=${DEPLOY_ENV} $SCRIPT_NAME ssh <commands>

EOF

  if [ "${BOSH_LITE_AUTO_HALT}" == "true" ]; then
    echo "Note: This VM will be automatically stopped in the evenings"
  else
    echo "Note: This VM will NOT be automatically stopped in the evenings"
  fi
}

ACTION=${1:-}

case "${ACTION}" in
  info|start|stop|destroy|ssh|t|d)
  ;;
  *)
    usage
  ;;
esac

case "${ACTION}" in
  t)
    init_environment
    create_dedicated_subnet_and_security_group
  ;;
  d)
    init_environment
    delete_dedicated_subnet_and_security_group
  ;;
  info)
    init_environment
    check_bosh_lite_codebase
    check_vagrant
    init_ssh_key_vars
    print_info
    if [ "$(get_vagrant_state)" == "running" ]; then
      update_and_get_admin_password
    fi
  ;;
  start)
    init_environment
    check_bosh_lite_codebase
    check_vagrant
    init_ssh_key_vars
    init_subnet_and_security_group_vars

    get_vagrant_box

    run_vagrant up --provider=aws
    echo "Bosh lite instance provisioned."

    update_and_get_admin_password
    print_info
  ;;
  stop)
    init_environment
    check_bosh_lite_codebase
    check_vagrant
    init_ssh_key_vars
    echo "Halting Bosh lite VM"
    run_vagrant ssh -- sudo halt
    sleep 10
    echo "Bosh lite VM state: $(get_vagrant_state)"
  ;;
  destroy)
    init_environment
    check_bosh_lite_codebase
    check_vagrant
    init_ssh_key_vars
    run_vagrant destroy
    delete_ssh_key_pair
  ;;
  ssh)
    init_environment
    check_bosh_lite_codebase
    check_vagrant
    init_ssh_key_vars
    shift
    run_vagrant ssh ${1:+--} "$@"
  ;;
esac




