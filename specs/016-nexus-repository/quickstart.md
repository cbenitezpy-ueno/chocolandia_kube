# Quickstart: Nexus Repository Manager

**Feature**: 016-nexus-repository
**Date**: 2025-11-24

## Prerequisites

- K3s cluster running with kubectl access
- OpenTofu 1.6+ installed
- cert-manager deployed (for TLS certificates)
- Traefik ingress controller deployed
- Pi-hole DNS configured for *.chocolandiadc.local

## Deployment

### 1. Deploy Nexus Module

```bash
cd terraform/environments/chocolandiadc-mvp

# Review the plan
tofu plan -target=module.nexus

# Apply changes
tofu apply -target=module.nexus
```

### 2. Initial Setup

After deployment (~2 minutes for Nexus to start):

1. Access Nexus UI: https://nexus.chocolandiadc.local
2. Login with default credentials:
   - Username: `admin`
   - Password: Retrieved from pod (see below)

```bash
# Get initial admin password
kubectl exec -n nexus deployment/nexus -- cat /nexus-data/admin.password
```

3. Complete setup wizard:
   - Change admin password
   - Configure anonymous access (disable for security)

### 3. Create Repositories

In Nexus UI (Settings > Repository > Repositories):

**Docker Repository**:
- Create hosted repository: `docker-hosted`
- Enable HTTP connector on port 8082
- Deployment policy: Allow redeploy

**Helm Repository**:
- Create hosted repository: `helm-hosted`

**NPM Repository**:
- Create hosted repository: `npm-hosted`

**Maven Repositories**:
- Create hosted repository: `maven-releases` (Release policy)
- Create hosted repository: `maven-snapshots` (Snapshot policy)

**APT Repository**:
- Create hosted repository: `apt-hosted`
- Distribution: `focal` (or your target)

## Usage Examples

### Docker

```bash
# Login to registry
docker login docker.nexus.chocolandiadc.local
# Username: admin
# Password: <your-password>

# Tag and push image
docker tag myapp:latest docker.nexus.chocolandiadc.local/myapp:latest
docker push docker.nexus.chocolandiadc.local/myapp:latest

# Pull image
docker pull docker.nexus.chocolandiadc.local/myapp:latest
```

### Helm

```bash
# Add repository
helm repo add nexus https://nexus.chocolandiadc.local/repository/helm-hosted/ \
  --username admin --password <your-password>

# Package and push chart
helm package mychart/
curl -u admin:<password> \
  https://nexus.chocolandiadc.local/repository/helm-hosted/ \
  --upload-file mychart-1.0.0.tgz

# Install from repository
helm repo update
helm install myrelease nexus/mychart
```

### NPM

```bash
# Configure registry
npm config set registry https://nexus.chocolandiadc.local/repository/npm-hosted/
npm config set //nexus.chocolandiadc.local/repository/npm-hosted/:_auth $(echo -n 'admin:<password>' | base64)

# Publish package
npm publish

# Install package
npm install mypackage
```

### Maven

Add to `~/.m2/settings.xml`:

```xml
<settings>
  <servers>
    <server>
      <id>nexus</id>
      <username>admin</username>
      <password>YOUR_PASSWORD</password>
    </server>
  </servers>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>https://nexus.chocolandiadc.local/repository/maven-releases/</url>
    </mirror>
  </mirrors>
</settings>
```

Deploy artifact:

```bash
mvn deploy -DaltDeploymentRepository=nexus::default::https://nexus.chocolandiadc.local/repository/maven-releases/
```

### APT

On Debian/Ubuntu client:

```bash
# Add repository
echo "deb https://nexus.chocolandiadc.local/repository/apt-hosted/ focal main" | \
  sudo tee /etc/apt/sources.list.d/nexus.list

# Add authentication (if required)
echo 'machine nexus.chocolandiadc.local login admin password YOUR_PASSWORD' | \
  sudo tee /etc/apt/auth.conf

# Update and install
sudo apt update
sudo apt install mypackage
```

## Validation

Run validation script:

```bash
./scripts/dev-tools/validate-nexus.sh
```

Or manual checks:

```bash
# Check pod status
kubectl get pods -n nexus

# Check service endpoints
kubectl get svc -n nexus

# Test web UI access
curl -I https://nexus.chocolandiadc.local

# Test Docker registry
curl -I https://docker.nexus.chocolandiadc.local/v2/

# Check Prometheus metrics
curl https://nexus.chocolandiadc.local/service/metrics/prometheus
```

## Troubleshooting

### Nexus not starting

```bash
# Check pod logs
kubectl logs -n nexus deployment/nexus

# Common issues:
# - Insufficient memory (increase resource limits)
# - PVC not bound (check storage class)
# - Port conflicts
```

### Docker push fails

```bash
# Ensure Docker repository has HTTP connector on port 8082
# Ensure you're logged in: docker login docker.nexus.chocolandiadc.local
# Check Nexus logs for auth errors
```

### Certificate issues

```bash
# Check certificate status
kubectl get certificate -n nexus

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

## Cleanup

To remove Nexus (preserves PVC data by default):

```bash
tofu destroy -target=module.nexus
```

To also remove data:

```bash
kubectl delete pvc -n nexus nexus-data
```

## Related Documentation

- [Spec](./spec.md) - Feature specification
- [Plan](./plan.md) - Implementation plan
- [Data Model](./data-model.md) - Resource definitions
- [Nexus Documentation](https://help.sonatype.com/repomanager3)
