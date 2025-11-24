# LocalStack Module

LocalStack Community Edition deployment for AWS service emulation in the K3s homelab cluster.

## Purpose

Emulate AWS services locally for development and testing without AWS costs. Supports S3, SQS, SNS, DynamoDB, and Lambda.

## Features

- LocalStack Community Edition (Free)
- Multiple AWS services: S3, SQS, SNS, DynamoDB, Lambda
- Data persistence across restarts
- Single endpoint for all services
- HTTPS via Traefik Ingress + cert-manager

## Usage

```hcl
module "localstack" {
  source = "../../modules/localstack"

  namespace     = "localstack"
  storage_size  = "20Gi"
  hostname      = "localstack.homelab.local"
  services_list = "s3,sqs,sns,dynamodb,lambda"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace | Kubernetes namespace | string | "localstack" | no |
| storage_size | PVC storage size | string | "20Gi" | no |
| hostname | LocalStack hostname | string | - | yes |
| services_list | Comma-separated AWS services | string | "s3,sqs,sns,dynamodb,lambda" | no |

## Outputs

| Name | Description |
|------|-------------|
| endpoint_url | LocalStack endpoint URL |
| services_enabled | List of enabled AWS services |

## AWS CLI Configuration

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

## Service Examples

### S3

```bash
aws --endpoint-url=https://localstack.homelab.local s3 mb s3://my-bucket
aws --endpoint-url=https://localstack.homelab.local s3 cp file.txt s3://my-bucket/
```

### SQS

```bash
aws --endpoint-url=https://localstack.homelab.local sqs create-queue --queue-name my-queue
aws --endpoint-url=https://localstack.homelab.local sqs send-message \
  --queue-url https://localstack.homelab.local/000000000000/my-queue \
  --message-body "Hello"
```

### DynamoDB

```bash
aws --endpoint-url=https://localstack.homelab.local dynamodb create-table \
  --table-name MyTable \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Health Check

```bash
curl https://localstack.homelab.local/_localstack/health
```

## SDK Configuration (Python)

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='https://localstack.homelab.local',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)
```
