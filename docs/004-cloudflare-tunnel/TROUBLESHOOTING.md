# Cloudflare Zero Trust Tunnel - Troubleshooting Guide

This guide covers common issues and solutions for the Cloudflare Zero Trust Tunnel deployment.

## Table of Contents

- [Pod Issues](#pod-issues)
- [Tunnel Connectivity](#tunnel-connectivity)
- [DNS Issues](#dns-issues)
- [OAuth Authentication Errors](#oauth-authentication-errors)
- [Access Control Issues](#access-control-issues)
- [Performance & Monitoring](#performance--monitoring)

---

## Pod Issues

### Pod Stuck in `ImagePullBackOff`

**Symptoms:**
```bash
$ kubectl get pods -n cloudflare-tunnel
NAME                          READY   STATUS             RESTARTS   AGE
cloudflared-xxx-yyy           0/1     ImagePullBackOff   0          5m
```

**Causes & Solutions:**

#### 1. DNS Resolution Failure on Node

The kubelet cannot resolve `registry-1.docker.io` to pull the image.

**Diagnosis:**
```bash
# SSH to the node
ssh user@node-ip

# Test DNS resolution
ping -c 2 registry-1.docker.io
dig @8.8.8.8 registry-1.docker.io

# Check systemd-resolved status
resolvectl status
```

**Solution A: Fix systemd-resolved (Preferred)**
```bash
# Configure DNS servers in systemd-resolved
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dns.conf <<EOF
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=192.168.1.1
EOF

sudo systemctl restart systemd-resolved
```

**Solution B: Replace /etc/resolv.conf (Quick Fix)**
```bash
# Backup and replace resolv.conf
sudo rm /etc/resolv.conf
sudo tee /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 192.168.1.1
EOF

# Manually pull image
sudo crictl pull cloudflare/cloudflared:latest

# Delete failing pod to recreate
kubectl delete pod -n cloudflare-tunnel cloudflared-xxx-yyy
```

#### 2. Network Connectivity Issues

**Diagnosis:**
```bash
# Test connectivity to Docker Hub
curl -I https://registry-1.docker.io/v2/

# Check node network configuration
ip route
ip addr show
```

**Solution:**
- Verify node has internet connectivity
- Check firewall rules
- Verify proxy settings (if applicable)

### Pod CrashLoopBackOff

**Symptoms:**
```bash
$ kubectl get pods -n cloudflare-tunnel
NAME                          READY   STATUS             RESTARTS   AGE
cloudflared-xxx-yyy           0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n cloudflare-tunnel cloudflared-xxx-yyy

# Check pod events
kubectl describe pod -n cloudflare-tunnel cloudflared-xxx-yyy
```

**Common Causes:**

#### Invalid Tunnel Credentials

**Error in logs:**
```
Failed to parse tunnel configuration: invalid credentials
```

**Solution:**
```bash
# Verify secret exists and has correct format
kubectl get secret -n cloudflare-tunnel cloudflared-credentials -o yaml

# Re-create secret if needed
tofu taint module.cloudflare_tunnel.kubernetes_secret.tunnel_credentials
tofu apply
```

#### Tunnel ID Mismatch

**Error in logs:**
```
Tunnel xxx not found
```

**Solution:**
```bash
# Destroy and recreate tunnel
tofu destroy -target=module.cloudflare_tunnel
tofu apply
```

### Pod Not Ready

**Symptoms:**
```bash
$ kubectl get pods -n cloudflare-tunnel
NAME                          READY   STATUS    RESTARTS   AGE
cloudflared-xxx-yyy           0/1     Running   0          2m
```

**Diagnosis:**
```bash
# Check readiness probe failures
kubectl describe pod -n cloudflare-tunnel cloudflared-xxx-yyy | grep -A 5 "Readiness"

# Check metrics endpoint
kubectl port-forward -n cloudflare-tunnel cloudflared-xxx-yyy 2000:2000 &
curl http://localhost:2000/ready
```

**Solution:**
- Wait for initial connection (can take 30-60s)
- If persists >5min, check logs for connection errors

---

## Tunnel Connectivity

### Tunnel Not Connecting to Cloudflare

**Symptoms:**
- Pod running but services not accessible
- Logs show connection errors

**Diagnosis:**
```bash
# Check pod logs for connection status
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50

# Look for:
# - "Connection established" (success)
# - "Failed to establish connection" (failure)
# - "Retrying connection" (transient issues)
```

**Common Errors:**

#### 1. Network Egress Blocked

**Error:**
```
Failed to connect to Cloudflare edge: dial tcp: i/o timeout
```

**Solution:**
```bash
# Verify egress to Cloudflare
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -I https://api.cloudflare.com/

# If blocked, check:
# - NetworkPolicies
# - Firewall rules
# - Proxy configuration
```

#### 2. Invalid API Token

**Error:**
```
API error: 10000 - Authentication error
```

**Solution:**
- Verify API token in terraform.tfvars
- Regenerate token in Cloudflare dashboard with correct permissions
- Re-run `tofu apply`

### Services Return 502 Bad Gateway

**Symptoms:**
- Tunnel connected
- Authentication works
- Services return 502 errors

**Diagnosis:**
```bash
# Check ingress configuration
kubectl get cm -n cloudflare-tunnel

# Verify service URLs in tunnel config
kubectl exec -n cloudflare-tunnel cloudflared-xxx-yyy -- \
  cat /etc/cloudflared/config.yml
```

**Solution A: Incorrect Service URL**
```hcl
# Fix in terraform.tfvars
ingress_rules = [
  {
    hostname = "app.example.com"
    # WRONG: service = "http://my-service:80"
    # RIGHT:
    service  = "http://my-service.namespace.svc.cluster.local:80"
  }
]
```

**Solution B: Service Not Running**
```bash
# Verify target service exists and is ready
kubectl get svc -n namespace my-service
kubectl get pods -n namespace -l app=my-service

# Check service endpoints
kubectl get endpoints -n namespace my-service
```

---

## DNS Issues

### CNAME Records Not Created

**Symptoms:**
```bash
$ dig app.example.com
# Returns NXDOMAIN or no CNAME
```

**Diagnosis:**
```bash
# Check Cloudflare records
tofu show | grep cloudflare_record

# Check Terraform state
tofu state list | grep cloudflare_record
```

**Solution:**
```bash
# Re-create DNS records
tofu taint module.cloudflare_tunnel.cloudflare_record.tunnel_dns[\"app.example.com\"]
tofu apply

# Verify in Cloudflare dashboard:
# DNS > Records > Look for app.example.com CNAME
```

### DNS Points to Wrong Tunnel

**Symptoms:**
- DNS resolves but connection fails
- Logs show "Tunnel not found"

**Solution:**
```bash
# Get correct tunnel CNAME
tofu output tunnel_cname

# Verify DNS points to correct tunnel
dig app.example.com CNAME

# If mismatch, destroy and recreate
tofu destroy -target=module.cloudflare_tunnel
tofu apply
```

---

## OAuth Authentication Errors

### "OAuth Error: Invalid Client"

**Cause:** Google OAuth credentials incorrect or misconfigured

**Solution:**
1. Verify credentials in Google Cloud Console:
   - https://console.cloud.google.com/apis/credentials
   - Check Client ID format: `<numbers>-<string>.apps.googleusercontent.com`
   - Check Client Secret is correct

2. Verify authorized redirect URI:
   ```
   https://<team-name>.cloudflareaccess.com/cdn-cgi/access/callback
   ```

3. Update terraform.tfvars and re-apply:
   ```bash
   tofu apply -target=module.cloudflare_tunnel.cloudflare_zero_trust_access_identity_provider.google_oauth
   ```

### "Access Denied" After Successful Login

**Cause:** Email not in authorized list

**Solution:**
```hcl
# Add email to authorized_emails in terraform.tfvars
authorized_emails = [
  "admin@example.com",
  "newuser@example.com"  # Add this
]
```

```bash
# Apply changes
tofu apply -target=module.cloudflare_tunnel.cloudflare_zero_trust_access_policy.email_authorization
```

### Redirect Loop After OAuth

**Cause:** Access policy misconfigured or conflicting rules

**Diagnosis:**
```bash
# Check Access policies in Cloudflare dashboard
# Zero Trust > Access > Applications > [Your App] > Policies
```

**Solution:**
```bash
# Recreate Access application and policy
tofu taint module.cloudflare_tunnel.cloudflare_zero_trust_access_application.services[\"app.example.com\"]
tofu taint module.cloudflare_tunnel.cloudflare_zero_trust_access_policy.email_authorization[\"app.example.com\"]
tofu apply
```

---

## Access Control Issues

### User Can't Access Protected Service

**Checklist:**
1. ✅ User email in `authorized_emails` list?
2. ✅ User authenticated with correct Google account?
3. ✅ Access policy applied to correct application?
4. ✅ No conflicting "Deny" policies?

**Diagnosis:**
```bash
# Check Access logs in Cloudflare dashboard
# Zero Trust > Logs > Access

# Look for:
# - Authentication attempts
# - Policy evaluations
# - Denial reasons
```

**Solution:**
```bash
# Update authorized emails
# Edit terraform.tfvars
authorized_emails = ["user@example.com"]

# Apply changes
tofu apply
```

### Session Expires Too Quickly

**Current Setting:** 24 hours (default)

**To Change:**
```hcl
# In module main.tf, modify session_duration
resource "cloudflare_zero_trust_access_application" "services" {
  # ...
  session_duration = "168h"  # 7 days
}
```

---

## Performance & Monitoring

### High Latency Through Tunnel

**Diagnosis:**
```bash
# Check pod metrics
kubectl top pods -n cloudflare-tunnel

# Check connection count in logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared | grep "connection"

# Test direct connectivity
time curl -I https://app.example.com
```

**Solutions:**

1. **Increase Replicas:**
```hcl
replica_count = 4  # More replicas = more Cloudflare edge connections
```

2. **Optimize Resource Limits:**
```hcl
resource_limits_cpu    = "1000m"  # Increase if CPU-bound
resource_limits_memory = "512Mi"  # Increase if memory-bound
```

3. **Check Backend Service:**
```bash
# Test service directly (port-forward)
kubectl port-forward -n namespace svc/my-service 8080:80
curl http://localhost:8080
```

### Prometheus Metrics Not Scraping

**Symptoms:**
- No cloudflared metrics in Prometheus
- ServiceMonitor not detecting pods

**Diagnosis:**
```bash
# Check pod annotations
kubectl get pods -n cloudflare-tunnel -o jsonpath='{.items[0].metadata.annotations}'

# Should show:
# prometheus.io/scrape: "true"
# prometheus.io/port: "2000"
# prometheus.io/path: "/metrics"

# Test metrics endpoint
kubectl port-forward -n cloudflare-tunnel cloudflared-xxx-yyy 2000:2000
curl http://localhost:2000/metrics
```

**Solution:**
- Annotations are configured automatically by module
- If using ServiceMonitor, create manually:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cloudflared
  namespace: cloudflare-tunnel
spec:
  selector:
    matchLabels:
      app: cloudflared
  endpoints:
  - port: metrics
    path: /metrics
```

---

## General Debugging

### Get Tunnel Status

```bash
# Check all resources
kubectl get all -n cloudflare-tunnel

# Check pod logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100

# Check pod describe
kubectl describe pods -n cloudflare-tunnel -l app=cloudflared

# Check Terraform outputs
cd terraform/environments/chocolandiadc-mvp
tofu output
```

### Completely Reset Tunnel

```bash
# Destroy tunnel infrastructure
cd terraform/environments/chocolandiadc-mvp
tofu destroy -target=module.cloudflare_tunnel

# Verify all resources deleted
kubectl get all -n cloudflare-tunnel  # Should be empty

# Re-create from scratch
tofu apply
```

### Enable Debug Logging

```bash
# Add to cloudflared container args in main.tf
args = [
  "tunnel",
  "--loglevel", "debug",  # Add this
  "--no-autoupdate",
  # ... rest of args
]

# Apply changes
tofu apply

# View debug logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f
```

---

## Getting Help

### Logs to Collect

When requesting help, provide:

```bash
# 1. Pod status
kubectl get pods -n cloudflare-tunnel -o wide

# 2. Pod logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=200

# 3. Pod events
kubectl describe pods -n cloudflare-tunnel -l app=cloudflared

# 4. Terraform outputs
cd terraform/environments/chocolandiadc-mvp
tofu output

# 5. Tunnel config
tofu show | grep -A 50 cloudflare_zero_trust_tunnel_cloudflared_config
```

### External Testing

Always test from outside your network:
```bash
# From mobile data or different network
curl -I https://app.example.com

# Check DNS
dig app.example.com
```

### Useful Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflare Access Documentation](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

---

## Quick Reference

### Essential Commands

```bash
# Check tunnel status
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared

# Restart cloudflared
kubectl rollout restart deployment -n cloudflare-tunnel cloudflared

# Force pull new image
kubectl delete pods -n cloudflare-tunnel -l app=cloudflared

# Check DNS
dig +short app.example.com CNAME

# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://service.namespace.svc.cluster.local:80
```

### Terraform Quick Actions

```bash
cd terraform/environments/chocolandiadc-mvp

# Re-apply configuration
tofu apply

# Re-create specific resource
tofu taint module.cloudflare_tunnel.kubernetes_deployment.cloudflared
tofu apply

# View current state
tofu show

# List all resources
tofu state list

# Destroy and recreate
tofu destroy -target=module.cloudflare_tunnel
tofu apply
```
