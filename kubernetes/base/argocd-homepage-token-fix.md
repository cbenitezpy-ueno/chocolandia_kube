# ArgoCD Homepage Widget Token Fix

## Problem
The Homepage ArgoCD widget was showing "API Error Information" because the JWT token expired.

## Root Cause
- Original token had expiration date (`exp` field in JWT)
- Token expired on Nov 14, 2025 at 06:31
- ArgoCD admin account didn't have `apiKey` capability enabled by default

## Solution

### 1. Enable apiKey capability for admin account

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"accounts.admin":"apiKey"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

### 2. Generate non-expiring token via API

```bash
# Get session token
SESSION_TOKEN=$(curl -k -s -X POST http://argocd-server.argocd.svc.cluster.local/api/v1/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<admin-password>"}' | jq -r '.token')

# Generate account token (no expiration)
ACCOUNT_TOKEN=$(curl -k -s -X POST \
  http://argocd-server.argocd.svc.cluster.local/api/v1/account/admin/token \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"homepage-widget"}' | jq -r '.token')

echo $ACCOUNT_TOKEN
```

### 3. Update Homepage secret

```bash
# Base64 encode the new token
ENCODED_TOKEN=$(echo -n "$ACCOUNT_TOKEN" | base64)

# Update secret
kubectl patch secret homepage-widgets -n homepage --type='json' \
  -p='[{"op": "replace", "path": "/data/HOMEPAGE_VAR_ARGOCD_TOKEN", "value": "'$ENCODED_TOKEN'"}]'

# Restart Homepage
kubectl rollout restart deployment homepage -n homepage
```

## Token Details

The new token:
- Does NOT have `exp` (expiration) field
- Has `sub: "admin:apiKey"` instead of `admin:login`
- Is stored in secret `homepage-widgets` as `HOMEPAGE_VAR_ARGOCD_TOKEN`

## Verification

Check Homepage logs for ArgoCD API errors:
```bash
kubectl logs -n homepage deployment/homepage | grep argocd
```

If working correctly, no 401 errors should appear.

## Configuration Applied

File: ArgoCD ConfigMap `argocd-cm` in namespace `argocd`
```yaml
data:
  accounts.admin: apiKey
```

This enables the admin account to generate API tokens that don't expire.
