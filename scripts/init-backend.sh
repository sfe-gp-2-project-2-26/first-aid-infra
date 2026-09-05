#!/bin/bash
set -e

REGION="eu-central-1"
BUCKET_NAME="medaid-terraform-state-$(uuidgen | tr 'A-Z' 'a-z' | cut -c1-8)"
TABLE_NAME="medaid-terraform-locks"

echo "Creating S3 bucket: $BUCKET_NAME in $REGION..."
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

echo "Enabling bucket versioning..."
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

echo "Enabling default encryption..."
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Creating DynamoDB table for state locking: $TABLE_NAME..."
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

echo "Done! Update environments/prod/backend.tf with:"
echo "bucket = \"$BUCKET_NAME\""
echo "dynamodb_table = \"$TABLE_NAME\""

