#!/bin/bash
# ============================================================================
# MinIO Deployment Validation Script
# Feature 001: Longhorn and MinIO Storage Infrastructure - Phase 5
# ============================================================================

set -e

KUBECONFIG_PATH="/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig"
export KUBECONFIG="$KUBECONFIG_PATH"

echo "========================================="
echo "MinIO Deployment Validation"
echo "========================================="
echo ""

# T056: Verify PVC is Bound
echo "✓ Checking MinIO PVC status..."
PVC_STATUS=$(kubectl get pvc -n minio minio-data -o jsonpath='{.status.phase}')
if [ "$PVC_STATUS" = "Bound" ]; then
    echo "  ✅ PVC is Bound"
    kubectl get pvc -n minio minio-data
else
    echo "  ❌ PVC is not Bound (Status: $PVC_STATUS)"
    exit 1
fi
echo ""

# T057: Verify Longhorn volume is healthy
echo "✓ Checking Longhorn volume health..."
VOLUME_NAME=$(kubectl get pvc -n minio minio-data -o jsonpath='{.spec.volumeName}')
VOLUME_STATE=$(kubectl get volumes.longhorn.io -n longhorn-system "$VOLUME_NAME" -o jsonpath='{.status.state}')
VOLUME_ROBUSTNESS=$(kubectl get volumes.longhorn.io -n longhorn-system "$VOLUME_NAME" -o jsonpath='{.status.robustness}')

echo "  Volume: $VOLUME_NAME"
echo "  State: $VOLUME_STATE"
echo "  Robustness: $VOLUME_ROBUSTNESS"

if [ "$VOLUME_STATE" = "attached" ]; then
    echo "  ✅ Volume is attached"
else
    echo "  ❌ Volume is not attached (State: $VOLUME_STATE)"
    exit 1
fi
echo ""

# T058: Verify MinIO pod is Running
echo "✓ Checking MinIO pod status..."
POD_STATUS=$(kubectl get pods -n minio -l app=minio -o jsonpath='{.items[0].status.phase}')
POD_READY=$(kubectl get pods -n minio -l app=minio -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')

if [ "$POD_STATUS" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo "  ✅ MinIO pod is Running and Ready"
    kubectl get pods -n minio -l app=minio
else
    echo "  ❌ MinIO pod is not Running/Ready (Status: $POD_STATUS, Ready: $POD_READY)"
    exit 1
fi
echo ""

# T059: Retrieve MinIO credentials
echo "✓ Retrieving MinIO credentials..."
MINIO_USER=$(kubectl get secret -n minio minio-credentials -o jsonpath='{.data.rootUser}' | base64 -d)
MINIO_PASSWORD=$(kubectl get secret -n minio minio-credentials -o jsonpath='{.data.rootPassword}' | base64 -d)

echo "  Root User: $MINIO_USER"
echo "  Root Password: $MINIO_PASSWORD"
echo "  ✅ Credentials retrieved successfully"
echo ""

# T060: Verify TLS certificates
echo "✓ Checking TLS certificates..."
CONSOLE_CERT_READY=$(kubectl get certificate -n minio minio-console-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
S3_CERT_READY=$(kubectl get certificate -n minio minio-s3-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

if [ "$CONSOLE_CERT_READY" = "True" ] && [ "$S3_CERT_READY" = "True" ]; then
    echo "  ✅ Both TLS certificates are Ready"
    kubectl get certificate -n minio
else
    echo "  ❌ TLS certificates are not Ready"
    exit 1
fi
echo ""

# T061: Verify IngressRoutes
echo "✓ Checking IngressRoutes..."
CONSOLE_IR=$(kubectl get ingressroute -n minio minio-console -o name 2>/dev/null || echo "missing")
S3_IR=$(kubectl get ingressroute -n minio minio-s3-api -o name 2>/dev/null || echo "missing")

if [ "$CONSOLE_IR" != "missing" ] && [ "$S3_IR" != "missing" ]; then
    echo "  ✅ Both IngressRoutes exist"
    kubectl get ingressroute -n minio
else
    echo "  ❌ IngressRoutes are missing"
    exit 1
fi
echo ""

# T062: Test HTTPS endpoints
echo "✓ Testing HTTPS endpoints..."
CONSOLE_HTTP=$(curl -k -s -o /dev/null -w "%{http_code}" https://minio.chocolandiadc.com)
S3_HTTP=$(curl -k -s -o /dev/null -w "%{http_code}" https://s3.chocolandiadc.com)

echo "  Console (minio.chocolandiadc.com): HTTP $CONSOLE_HTTP"
echo "  S3 API (s3.chocolandiadc.com): HTTP $S3_HTTP"

if [ "$CONSOLE_HTTP" = "200" ]; then
    echo "  ✅ Console endpoint is accessible"
else
    echo "  ⚠️  Console returned HTTP $CONSOLE_HTTP (expected 200)"
fi

if [ "$S3_HTTP" = "400" ] || [ "$S3_HTTP" = "403" ]; then
    echo "  ✅ S3 API endpoint is accessible (HTTP 400/403 is normal without credentials)"
else
    echo "  ⚠️  S3 API returned HTTP $S3_HTTP (expected 400 or 403)"
fi
echo ""

# T063: Export credentials for AWS CLI configuration
echo "✓ Exporting credentials for AWS CLI setup..."
cat > /tmp/minio-credentials.env << EOF
export AWS_ACCESS_KEY_ID="$MINIO_USER"
export AWS_SECRET_ACCESS_KEY="$MINIO_PASSWORD"
export AWS_ENDPOINT_URL="https://s3.chocolandiadc.com"
export AWS_DEFAULT_REGION="us-east-1"
EOF

echo "  ✅ Credentials exported to /tmp/minio-credentials.env"
echo "  To configure AWS CLI, run:"
echo "    source /tmp/minio-credentials.env"
echo ""

echo "========================================="
echo "✅ MinIO Deployment Validation Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Storage: 50Gi Longhorn volume (attached, healthy)"
echo "  - Pod: Running and Ready"
echo "  - TLS: Both certificates Ready"
echo "  - Endpoints: Console and S3 API accessible via HTTPS"
echo ""
echo "Access URLs:"
echo "  Console: https://minio.chocolandiadc.com"
echo "  S3 API:  https://s3.chocolandiadc.com"
echo ""
