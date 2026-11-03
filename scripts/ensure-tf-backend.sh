#!/usr/bin/env bash
set -euo pipefail

# Create (or reuse) the S3 bucket and DynamoDB table used for Terraform state.
# Prints backend-config flags that callers can pass to `terraform init`.

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
PROJECT="${PROJECT:-devops-assignment}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-${PROJECT}-tfstate-${ACCOUNT_ID}}"
TABLE="${TF_LOCK_TABLE:-${PROJECT}-tf-lock}"

echo "Ensuring Terraform state bucket s3://${BUCKET} in ${REGION}" >&2

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket already exists." >&2
else
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Lock table ${TABLE} already exists." >&2
else
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" >/dev/null
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

echo "bucket=${BUCKET}"
echo "region=${REGION}"
echo "dynamodb_table=${TABLE}"
echo "encrypt=true"
