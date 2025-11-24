# LocalStack API Contract

**Feature**: 015-dev-tools-local
**Service**: LocalStack Community Edition
**Base URL**: `https://localstack.homelab.local`

## Overview

LocalStack exposes AWS-compatible APIs on a single endpoint (port 4566). All AWS SDK calls work by changing the endpoint URL.

## Health Check

```
GET /_localstack/health
```

**Response** (200 OK):
```json
{
  "services": {
    "s3": "running",
    "sqs": "running",
    "sns": "running",
    "dynamodb": "running",
    "lambda": "running"
  },
  "version": "3.0.0"
}
```

---

## AWS CLI Configuration

### Environment Variables

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=https://localstack.homelab.local
```

### AWS CLI Profile (~/.aws/config)

```ini
[profile localstack]
region = us-east-1
output = json
endpoint_url = https://localstack.homelab.local
```

```ini
# ~/.aws/credentials
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

**Usage**:
```bash
aws --profile localstack s3 ls
```

---

## S3 API Examples

### Create Bucket

```bash
aws --endpoint-url=https://localstack.homelab.local \
    s3 mb s3://my-bucket
```

### Upload File

```bash
aws --endpoint-url=https://localstack.homelab.local \
    s3 cp myfile.txt s3://my-bucket/
```

### List Objects

```bash
aws --endpoint-url=https://localstack.homelab.local \
    s3 ls s3://my-bucket/
```

### Download File

```bash
aws --endpoint-url=https://localstack.homelab.local \
    s3 cp s3://my-bucket/myfile.txt ./downloaded.txt
```

---

## SQS API Examples

### Create Queue

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sqs create-queue --queue-name my-queue
```

**Response**:
```json
{
  "QueueUrl": "https://localstack.homelab.local/000000000000/my-queue"
}
```

### Send Message

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sqs send-message \
    --queue-url https://localstack.homelab.local/000000000000/my-queue \
    --message-body "Hello World"
```

### Receive Message

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sqs receive-message \
    --queue-url https://localstack.homelab.local/000000000000/my-queue
```

---

## SNS API Examples

### Create Topic

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sns create-topic --name my-topic
```

**Response**:
```json
{
  "TopicArn": "arn:aws:sns:us-east-1:000000000000:my-topic"
}
```

### Subscribe to Topic

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:000000000000:my-topic \
    --protocol sqs \
    --notification-endpoint arn:aws:sqs:us-east-1:000000000000:my-queue
```

### Publish Message

```bash
aws --endpoint-url=https://localstack.homelab.local \
    sns publish \
    --topic-arn arn:aws:sns:us-east-1:000000000000:my-topic \
    --message "Hello from SNS"
```

---

## DynamoDB API Examples

### Create Table

```bash
aws --endpoint-url=https://localstack.homelab.local \
    dynamodb create-table \
    --table-name Users \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

### Put Item

```bash
aws --endpoint-url=https://localstack.homelab.local \
    dynamodb put-item \
    --table-name Users \
    --item '{"id": {"S": "user1"}, "name": {"S": "John Doe"}}'
```

### Get Item

```bash
aws --endpoint-url=https://localstack.homelab.local \
    dynamodb get-item \
    --table-name Users \
    --key '{"id": {"S": "user1"}}'
```

---

## Lambda API Examples

### Create Function (from ZIP)

```bash
# Create function code
echo 'exports.handler = async (event) => ({ statusCode: 200, body: "Hello" });' > index.js
zip function.zip index.js

# Deploy function
aws --endpoint-url=https://localstack.homelab.local \
    lambda create-function \
    --function-name my-function \
    --runtime nodejs18.x \
    --handler index.handler \
    --zip-file fileb://function.zip \
    --role arn:aws:iam::000000000000:role/lambda-role
```

### Invoke Function

```bash
aws --endpoint-url=https://localstack.homelab.local \
    lambda invoke \
    --function-name my-function \
    --payload '{"key": "value"}' \
    response.json
```

---

## SDK Configuration Examples

### Python (boto3)

```python
import boto3

# Create client pointing to LocalStack
s3 = boto3.client(
    's3',
    endpoint_url='https://localstack.homelab.local',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# Use normally
s3.create_bucket(Bucket='my-bucket')
```

### JavaScript (AWS SDK v3)

```javascript
import { S3Client, CreateBucketCommand } from "@aws-sdk/client-s3";

const client = new S3Client({
  endpoint: "https://localstack.homelab.local",
  region: "us-east-1",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test",
  },
  forcePathStyle: true,
});

await client.send(new CreateBucketCommand({ Bucket: "my-bucket" }));
```

### Java (AWS SDK v2)

```java
S3Client s3 = S3Client.builder()
    .endpointOverride(URI.create("https://localstack.homelab.local"))
    .region(Region.US_EAST_1)
    .credentialsProvider(StaticCredentialsProvider.create(
        AwsBasicCredentials.create("test", "test")))
    .build();
```

---

## Notes

- **Credentials**: LocalStack accepts any credentials (use `test`/`test`)
- **Region**: Default is `us-east-1`
- **Account ID**: LocalStack uses `000000000000`
- **Persistence**: Data persists across restarts when PERSISTENCE=1
