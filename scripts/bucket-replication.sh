#!/bin/bash

if [ -z "${DEPLOY_ENV:-}" ]; then
  echo "You must set \$DEPLOY_ENV." >&2
  exit 1
fi

echo
echo "Making buckets"

RAND=$(date +%s)
BUCKET_A="${DEPLOY_ENV}-bucket-${RAND}"
BUCKET_B="${DEPLOY_ENV}-bucket-${RAND}-b"

aws s3 mb "s3://${BUCKET_A}"
aws s3 mb "s3://${BUCKET_B}" --region us-east-1

echo
echo "Enabling bucket versioning"
aws s3api put-bucket-versioning --bucket "${BUCKET_A}" --versioning-configuration Status=Enabled
aws s3api put-bucket-versioning --bucket "${BUCKET_B}" --versioning-configuration Status=Enabled

echo
echo "Setting up IAM role"
ROLE_NAME="s3-replication-role"
cat <<EOF > /tmp/trust-policy.json
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Principal":{
            "Service":"s3.amazonaws.com"
         },
         "Action":"sts:AssumeRole"
      }
   ]
}
EOF
aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document "$(cat /tmp/trust-policy.json)" > /tmp/create-role-output.json
ROLE_ARN=$(jq -r '.Role.Arn' < /tmp/create-role-output.json)

echo
echo "Creating access policy"

cat <<EOF > /tmp/access-policy.json
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetReplicationConfiguration",
            "s3:ListBucket"
         ],
         "Resource":[
            "arn:aws:s3:::${BUCKET_A}"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl"
         ],
         "Resource":[
            "arn:aws:s3:::${BUCKET_A}/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:ReplicateObject",
            "s3:ReplicateDelete"
         ],
         "Resource":"arn:aws:s3:::${BUCKET_B}/*"
      }
   ]
}
EOF
aws iam create-policy --policy-name replicate-s3-bucket --policy-document "$(cat /tmp/access-policy.json)" > /tmp/policy-output.json
POLICY_ARN=$(jq -r '.Policy.Arn' < /tmp/policy-output.json)
echo "Policy created: ${POLICY_ARN}"

echo
echo "Attaching role policy"
aws iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}"

echo
echo "Creating replication policy"
cat <<EOF > /tmp/replication-policy.json
{
  "Role": "${ROLE_ARN}",
  "Rules": [
    {
      "Prefix": "",
      "Status": "Enabled",
      "Destination": {
        "Bucket": "arn:aws:s3:::${BUCKET_B}",
        "StorageClass": "STANDARD"
      }
    }
  ]
}
EOF
echo
echo "Configuring bucket replication"
aws s3api put-bucket-replication --bucket "${BUCKET_A}" --replication-configuration "$(cat /tmp/replication-policy.json)" > /tmp/put-bucket-replication-output.json

list_bucket_contents() {
  echo BUCKET_A
  aws s3 ls "s3://${BUCKET_A}"
  aws s3api list-object-versions --bucket "${BUCKET_A}"
  echo BUCKET_B
  aws s3 ls "s3://${BUCKET_B}"
  aws s3api list-object-versions --bucket "${BUCKET_B}"
}

echo
echo "Put a file in BUCKET_A"
echo "version 1" > /tmp/file1
aws s3 cp /tmp/file1 "s3://${BUCKET_A}"
echo "Allowing 10 seconds for replication"
sleep 10
list_bucket_contents

echo
echo "Change the file in BUCKET_A"
echo "version 2" > /tmp/file1
aws s3 cp /tmp/file1 "s3://${BUCKET_A}"
echo "Allowing 10 seconds for replication"
sleep 10
list_bucket_contents

# Tear down commands
{
  echo aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}"
  echo aws iam delete-policy --policy-arn "${POLICY_ARN}"
  echo aws iam delete-role --role-name ${ROLE_NAME}
} >> /tmp/teardown

echo
echo "Remember manually delete the buckets and tear down with:"
cat /tmp/teardown
rm -f /tmp/teardown

echo
echo "Cleaning up temporary files"
rm -f /tmp/access-policy.json
rm -f /tmp/trust-policy.json
rm -f /tmp/policy-output.json
rm -f /tmp/replication-policy.json
rm -f /tmp/put-bucket-replication-output.json
rm -f /tmp/file1
