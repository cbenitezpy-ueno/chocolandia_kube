# Headlamp OIDC Authentication

This document explains how Headlamp is configured with OIDC (OpenID Connect) for Google OAuth authentication.

## Overview

Instead of manually extracting and pasting Kubernetes ServiceAccount tokens, users can now log in to Headlamp using their Google account. This provides a seamless authentication experience similar to Grafana and other web applications.

## Architecture

Headlamp's OIDC authentication consists of two layers:

### Layer 1: Cloudflare Zero Trust Access
- Verifies **WHO** you are (identity verification)
- Uses Google OAuth via Cloudflare Access
- Session duration: 24 hours
- Configured at infrastructure level (Cloudflare tunnel module)

### Layer 2: Kubernetes OIDC + RBAC
- Verifies **WHAT** you can do (authorization)
- K3s API server validates Google OAuth tokens
- RBAC policies grant permissions based on email address
- Users get read-only "view" ClusterRole by default

## How It Works

1. **User accesses** `https://headlamp.chocolandiadc.com`
2. **Cloudflare Access** redirects to Google OAuth login
3. **Google authenticates** user and returns ID token
4. **Cloudflare** validates token and creates session (24h)
5. **User reaches Headlamp** UI with "Sign in with OIDC" button
6. **Headlamp** redirects to K3s API server OAuth flow
7. **K3s API server** redirects to Google OAuth
8. **Google** returns ID token to K3s
9. **K3s validates** token (issuer, client ID, signature)
10. **K3s extracts** email from token (username claim)
11. **Kubernetes RBAC** checks ClusterRoleBinding for that email
12. **Access granted** with read-only "view" permissions

## Configuration

### K3s API Server (OIDC Provider)

The K3s API server is configured with these OIDC flags:

```bash
--kube-apiserver-arg=oidc-issuer-url=https://accounts.google.com
--kube-apiserver-arg=oidc-client-id=134798906093-c3v4k7mgtofkneru6r31sa7rgkupfm2j.apps.googleusercontent.com
--kube-apiserver-arg=oidc-username-claim=email
--kube-apiserver-arg=oidc-groups-claim=groups
--kube-apiserver-arg=oidc-username-prefix=-
```

**Configuration Location**: `terraform/environments/chocolandiadc-mvp/terraform.tfvars`

### Headlamp (OIDC Client)

Headlamp is configured as an OIDC client via Helm values:

```yaml
config:
  oidc:
    clientID: "134798906093-c3v4k7mgtofkneru6r31sa7rgkupfm2j.apps.googleusercontent.com"
    clientSecret: "GOCSPX-..."  # Sensitive, stored in terraform.tfvars
    issuerURL: "https://accounts.google.com"
    scopes: "email,profile,openid"
```

**Configuration Location**: `terraform/modules/headlamp/main.tf`

### RBAC (Authorization)

Each authorized email gets a ClusterRoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-cbenitez-at-gmail.com-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view  # Built-in read-only role
subjects:
- kind: User
  name: cbenitez@gmail.com  # Email from Google OAuth token
```

**Configuration Location**: `terraform/modules/headlamp/oidc-rbac.tf`

## Permissions

Users authenticated via OIDC receive the Kubernetes built-in `view` ClusterRole, which provides:

✅ **Can do:**
- View pods, services, deployments, configmaps
- View logs from pods
- View resource metrics (CPU, memory)
- View ingress routes and certificates
- View persistent volumes and claims

❌ **Cannot do:**
- Create, update, or delete resources
- View secrets (for security)
- Modify RBAC policies
- Access node shell (kubectl exec)
- Port-forward to pods

## Usage

### First-Time Login

1. Navigate to `https://headlamp.chocolandiadc.com`
2. Authenticate via Cloudflare Access (Google OAuth)
3. Click **"Sign in with OIDC"** button in Headlamp
4. Authorize Headlamp to access your Google profile
5. You're logged in with read-only access!

### Subsequent Logins

- Cloudflare Access session lasts 24 hours
- OIDC session expires when token expires (~1 hour)
- Simply refresh the page to re-authenticate

### Logout

- Clear browser cookies for `chocolandiadc.com`
- Or wait for session to expire (24h for Cloudflare, ~1h for OIDC)

## Troubleshooting

### "Sign in with OIDC" button not showing

**Symptom**: Headlamp shows token input field instead of OIDC button

**Cause**: OIDC not configured in Headlamp Helm values

**Fix**: Verify OIDC configuration:
```bash
kubectl get deployment headlamp -n headlamp -o yaml | grep -A 10 oidc
```

Should show:
```yaml
config:
  oidc:
    clientID: "..."
    issuerURL: "https://accounts.google.com"
```

### OAuth redirect error

**Symptom**: "Error: redirect_uri_mismatch" when signing in

**Cause**: Headlamp's redirect URI not authorized in Google OAuth app

**Fix**: Add authorized redirect URI in Google Cloud Console:
1. Go to https://console.cloud.google.com/apis/credentials
2. Edit OAuth 2.0 Client ID
3. Add `https://headlamp.chocolandiadc.com/oidc-callback`
4. Save

### Access denied after OIDC login

**Symptom**: Successfully authenticate but see "Forbidden" errors

**Cause**: No ClusterRoleBinding for your email address

**Fix**: Add your email to `headlamp_authorized_emails` in terraform.tfvars:
```hcl
headlamp_authorized_emails = [
  "cbenitez@gmail.com",
  "your-email@gmail.com",  # Add this
]
```

Then run `tofu apply`:
```bash
cd terraform/environments/chocolandiadc-mvp
tofu apply
```

### K3s API server not validating OIDC tokens

**Symptom**: OIDC login succeeds but API requests fail with authentication error

**Cause**: K3s API server OIDC flags not configured or incorrect

**Fix**: Verify K3s service configuration:
```bash
ssh chocolim@192.168.4.101 'sudo systemctl cat k3s | grep oidc'
```

Should show:
```
--kube-apiserver-arg=oidc-issuer-url=https://accounts.google.com
--kube-apiserver-arg=oidc-client-id=...
```

If missing, reapply OpenTofu configuration.

## Security Considerations

### Why Two Authentication Layers?

1. **Cloudflare Access (Identity)**:
   - Prevents unauthorized access to Headlamp URL
   - Uses Google OAuth for identity verification
   - Creates session (24h) to avoid repeated logins
   - Protects against bots and unauthorized users

2. **Kubernetes OIDC (Authorization)**:
   - Verifies permissions for Kubernetes API access
   - Uses same Google OAuth token for consistency
   - Enforces RBAC policies per user
   - Ensures principle of least privilege

### Token Security

- Google OAuth tokens are short-lived (~1 hour)
- Tokens never stored in browser localStorage
- K3s validates token signature with Google's public keys
- Token contains claims: email, name, picture, issued_at, expires_at

### RBAC Best Practices

- Grant minimum required permissions (view role by default)
- Create ClusterRoleBindings per user (not groups)
- Regularly audit authorized_emails list
- Remove RBAC bindings for departed users

## Adding New Users

1. **Add email to terraform.tfvars**:
   ```hcl
   headlamp_authorized_emails = [
     "cbenitez@gmail.com",
     "new-user@gmail.com",  # New user
   ]
   ```

2. **Apply OpenTofu changes**:
   ```bash
   cd terraform/environments/chocolandiadc-mvp
   tofu apply
   ```

3. **Verify ClusterRoleBinding created**:
   ```bash
   kubectl get clusterrolebinding | grep oidc
   ```

4. **User can now login** with their Google account!

## Comparison: Token vs OIDC

### Before (ServiceAccount Token):
1. Extract token: `kubectl get secret headlamp-admin-token -n headlamp -o jsonpath='{.data.token}' | base64 -d`
2. Copy long token (200+ characters)
3. Paste into Headlamp "Authentication Token" field
4. Manual process every time session expires

### After (OIDC):
1. Click "Sign in with OIDC"
2. Authenticate with Google (if not already signed in)
3. Automatic authentication
4. Session persists (Cloudflare: 24h, OIDC: ~1h)

## Related Documentation

- [Headlamp OIDC Configuration](https://headlamp.dev/docs/latest/installation/oidc/)
- [Kubernetes OIDC Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [K3s kube-apiserver Flags](https://docs.k3s.io/reference/server-config#kubernetes-apiserver)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)

## Support

For Headlamp OIDC issues:
- GitHub: https://github.com/headlamp-k8s/headlamp/issues
- Slack: kubernetes.slack.com #headlamp

For K3s OIDC issues:
- GitHub: https://github.com/k3s-io/k3s/issues
- Slack: rancher-users.slack.com #k3s
