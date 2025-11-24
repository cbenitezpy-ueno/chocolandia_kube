# Quickstart: LocalStack and Container Registry

**Feature**: 015-dev-tools-local
**Date**: 2025-11-23

## Prerequisites

- K3s cluster running and accessible via kubectl
- OpenTofu installed
- Docker CLI installed on workstation
- AWS CLI installed (for LocalStack testing)

---

## 1. Deploy the Services

```bash
cd /Users/cbenitez/chocolandia_kube

# Initialize and apply OpenTofu
cd terraform/environments/chocolandiadc-mvp
tofu init
tofu plan
tofu apply
```

---

## 2. Configure DNS (Pi-hole)

Add these DNS records to Pi-hole:

| Hostname | Target |
|----------|--------|
| registry.homelab.local | 192.168.4.202 |
| registry-ui.homelab.local | 192.168.4.202 |
| localstack.homelab.local | 192.168.4.202 |

**Via Pi-hole Admin**:
1. Go to Local DNS → DNS Records
2. Add each hostname pointing to Traefik IP

---

## 3. Using the Container Registry

### Login

```bash
docker login registry.homelab.local
# Username: admin
# Password: <your-password>
```

### Push an Image

```bash
# Tag your image
docker tag myapp:latest registry.homelab.local/myapp:v1.0.0

# Push to local registry
docker push registry.homelab.local/myapp:v1.0.0
```

### Pull an Image

```bash
docker pull registry.homelab.local/myapp:v1.0.0
```

### Browse Images (Web UI)

Open in browser: `https://registry-ui.homelab.local`

---

## 4. Using LocalStack

### Configure AWS CLI

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

### Test S3

```bash
# Create bucket
aws --endpoint-url=https://localstack.homelab.local s3 mb s3://test-bucket

# Upload file
echo "Hello LocalStack" > test.txt
aws --endpoint-url=https://localstack.homelab.local s3 cp test.txt s3://test-bucket/

# List bucket contents
aws --endpoint-url=https://localstack.homelab.local s3 ls s3://test-bucket/

# Download file
aws --endpoint-url=https://localstack.homelab.local s3 cp s3://test-bucket/test.txt downloaded.txt
```

### Test SQS

```bash
# Create queue
aws --endpoint-url=https://localstack.homelab.local sqs create-queue --queue-name test-queue

# Send message
aws --endpoint-url=https://localstack.homelab.local sqs send-message \
  --queue-url https://localstack.homelab.local/000000000000/test-queue \
  --message-body "Hello SQS"

# Receive message
aws --endpoint-url=https://localstack.homelab.local sqs receive-message \
  --queue-url https://localstack.homelab.local/000000000000/test-queue
```

### Test DynamoDB

```bash
# Create table
aws --endpoint-url=https://localstack.homelab.local dynamodb create-table \
  --table-name TestTable \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Put item
aws --endpoint-url=https://localstack.homelab.local dynamodb put-item \
  --table-name TestTable \
  --item '{"id": {"S": "1"}, "name": {"S": "Test Item"}}'

# Get item
aws --endpoint-url=https://localstack.homelab.local dynamodb get-item \
  --table-name TestTable \
  --key '{"id": {"S": "1"}}'
```

### Check Health

```bash
curl https://localstack.homelab.local/_localstack/health
```

---

## 5. Use in Kubernetes Deployments

### Create ImagePullSecret

```bash
kubectl create secret docker-registry registry-creds \
  --docker-server=registry.homelab.local \
  --docker-username=admin \
  --docker-password=<your-password> \
  -n your-namespace
```

### Reference in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: registry.homelab.local/myapp:v1.0.0
  imagePullSecrets:
  - name: registry-creds
```

---

## 6. Use in Application Code

### Python Example

```python
import boto3

# Create S3 client pointing to LocalStack
s3 = boto3.client(
    's3',
    endpoint_url='https://localstack.homelab.local',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# Use like normal AWS S3
s3.create_bucket(Bucket='my-app-bucket')
s3.upload_file('data.json', 'my-app-bucket', 'data.json')
```

---

## 7. Troubleshooting

### Registry: Authentication Failed

```bash
# Verify credentials
kubectl get secret registry-auth -n registry -o jsonpath='{.data.htpasswd}' | base64 -d
```

### LocalStack: Service Not Running

```bash
# Check health endpoint
curl https://localstack.homelab.local/_localstack/health

# Check pod logs
kubectl logs -n localstack deployment/localstack
```

### Cannot Pull Images in K3s

Ensure `/etc/rancher/k3s/registries.yaml` is configured on each node:

```yaml
mirrors:
  "registry.homelab.local":
    endpoint:
      - "https://registry.homelab.local"
configs:
  "registry.homelab.local":
    auth:
      username: admin
      password: <your-password>
```

Then restart K3s:
```bash
sudo systemctl restart k3s  # or k3s-agent on workers
```

---

## 8. Registry Garbage Collection (Manual)

When storage fills up:

```bash
# Enter registry pod
kubectl exec -it -n registry deployment/registry -- sh

# Dry run
registry garbage-collect /etc/docker/registry/config.yml --dry-run

# Execute cleanup
registry garbage-collect /etc/docker/registry/config.yml
```

---

## Verification Checklist

- [ ] `docker login registry.homelab.local` succeeds
- [ ] Can push/pull images to registry
- [ ] Registry UI shows pushed images
- [ ] `aws s3 ls` against LocalStack works
- [ ] SQS send/receive works
- [ ] DynamoDB create table/put item works
- [ ] K3s pods can pull from local registry
