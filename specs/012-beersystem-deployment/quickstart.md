# Quickstart: BeerSystem Deployment

**Feature**: 012-beersystem-deployment
**Date**: 2025-11-15
**Purpose**: Step-by-step deployment runbook for BeerSystem application to K3s cluster

## Prerequisites

Before starting deployment, verify the following infrastructure components are operational:

- [ ] K3s cluster is running (feature 002-k3s-mvp-eero)
  ```bash
  kubectl get nodes
  # Expected: All nodes in Ready state
  ```

- [ ] PostgreSQL cluster is running (feature 011-postgresql-cluster)
  ```bash
  kubectl get pods -n postgres
  # Expected: postgres pods running and ready
  ```

- [ ] ArgoCD is installed and accessible (feature 008-gitops-argocd)
  ```bash
  kubectl get pods -n argocd
  # Expected: argocd-server and related pods running
  ```

- [ ] Cert-manager is running (feature 006-cert-manager)
  ```bash
  kubectl get pods -n cert-manager
  # Expected: cert-manager pods running
  ```

- [ ] Traefik ingress controller is running (feature 006-cert-manager)
  ```bash
  kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
  # Expected: traefik pod running
  ```

- [ ] Cloudflare Tunnel is running and connected (feature 004-cloudflare-zerotrust)
  ```bash
  kubectl get pods -n cloudflare-tunnel  # Or wherever cloudflared runs
  # Expected: cloudflared pod running
  ```

- [ ] DNS CNAME record for beer.chocolandiadc.com points to Cloudflare Tunnel
  ```bash
  nslookup beer.chocolandiadc.com
  # Expected: Resolves to Cloudflare tunnel CNAME (*.cfargotunnel.com)
  ```

## Deployment Phases

The deployment follows a phased approach to minimize risk and enable validation at each step.

### Phase 1: Database Provisioning (OpenTofu)

**Objective**: Create `beersystem_stage` database and `beersystem_admin` user in PostgreSQL cluster

**Location**: `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/beersystem-db/`

#### 1.1. Create OpenTofu Configuration

Navigate to infrastructure repository:
```bash
cd /Users/cbenitez/chocolandia_kube
```

Create database provisioning directory:
```bash
mkdir -p terraform/environments/chocolandiadc-mvp/beersystem-db
```

Create `main.tf`:
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.21"
    }
  }
}

# Configure PostgreSQL provider to connect to cluster
provider "postgresql" {
  host            = var.postgres_host
  port            = var.postgres_port
  username        = var.postgres_admin_user
  password        = var.postgres_admin_password
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}

# Create beersystem_admin role
resource "postgresql_role" "beersystem_admin" {
  name     = "beersystem_admin"
  login    = true
  password = var.beersystem_admin_password
}

# Create beersystem_stage database
resource "postgresql_database" "beersystem_stage" {
  name              = "beersystem_stage"
  owner             = postgresql_role.beersystem_admin.name
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"
  lc_ctype          = "en_US.UTF-8"
  template          = "template0"
  connection_limit  = -1
}

# Grant database privileges
resource "postgresql_grant" "beersystem_admin_database" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]
}

# Grant schema privileges
resource "postgresql_grant" "beersystem_admin_schema" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

# Default privileges for future tables
resource "postgresql_default_privileges" "beersystem_admin_tables" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  owner       = postgresql_role.beersystem_admin.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

# Default privileges for future sequences
resource "postgresql_default_privileges" "beersystem_admin_sequences" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  owner       = postgresql_role.beersystem_admin.name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}
```

Create `variables.tf`:
```hcl
variable "postgres_host" {
  description = "PostgreSQL cluster host (service endpoint)"
  type        = string
  default     = "postgres-rw.postgres.svc.cluster.local"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_admin_user" {
  description = "PostgreSQL cluster admin username"
  type        = string
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "PostgreSQL cluster admin password"
  type        = string
  sensitive   = true
}

variable "beersystem_admin_password" {
  description = "Password for beersystem_admin database user"
  type        = string
  sensitive   = true
}
```

Create `outputs.tf`:
```hcl
output "database_name" {
  description = "Name of the created database"
  value       = postgresql_database.beersystem_stage.name
}

output "database_owner" {
  description = "Owner of the database"
  value       = postgresql_role.beersystem_admin.name
}

output "connection_string" {
  description = "PostgreSQL connection string for beersystem application"
  value       = "postgresql://${postgresql_role.beersystem_admin.name}@${var.postgres_host}:${var.postgres_port}/${postgresql_database.beersystem_stage.name}"
  sensitive   = true
}
```

Create `terraform.tfvars` (DO NOT COMMIT - add to .gitignore):
```hcl
postgres_admin_user     = "postgres"  # Or cluster admin user from feature 011
postgres_admin_password = "<POSTGRES_CLUSTER_ADMIN_PASSWORD>"  # Get from feature 011 secrets
beersystem_admin_password = "<GENERATE_STRONG_PASSWORD>"  # openssl rand -base64 32
```

#### 1.2. Generate Database Password

Generate strong password for beersystem_admin:
```bash
openssl rand -base64 32
# Copy output to terraform.tfvars and save separately for Kubernetes Secret creation
```

#### 1.3. Get PostgreSQL Cluster Admin Credentials

Retrieve postgres admin password from cluster:
```bash
# Assuming feature 011 stores credentials in a secret (adjust namespace/secret name as needed)
kubectl get secret -n postgres postgres-superuser -o jsonpath='{.data.password}' | base64 -d
```

#### 1.4. Initialize and Apply OpenTofu

Initialize OpenTofu:
```bash
cd terraform/environments/chocolandiadc-mvp/beersystem-db
tofu init
```

Validate configuration:
```bash
tofu validate
# Expected: Success! The configuration is valid.
```

Preview changes:
```bash
tofu plan
# Review output carefully - should show creation of role, database, grants
```

Apply configuration:
```bash
tofu apply
# Review plan output
# Type 'yes' to confirm
# Expected: Successfully created database and user
```

#### 1.5. Verify Database Creation

Port-forward to PostgreSQL cluster (for manual testing):
```bash
kubectl port-forward -n postgres svc/postgres-rw 5432:5432
```

Test connection in another terminal:
```bash
psql "postgresql://beersystem_admin:<password>@localhost:5432/beersystem_stage"

# Inside psql:
\conninfo  # Verify connection
\l         # List databases (beersystem_stage should appear)
\du        # List roles (beersystem_admin should appear)
CREATE TABLE test_ddl (id SERIAL PRIMARY KEY, name VARCHAR(50));
DROP TABLE test_ddl;
\q
```

---

### Phase 2: Container Image Build and Push

**Objective**: Build beersystem Docker image and push to Docker Hub registry

**Location**: `/Users/cbenitez/beersystem/`

#### 2.1. Review Dockerfile

Verify Dockerfile exists and is production-ready:
```bash
cd /Users/cbenitez/beersystem
cat Dockerfile
# Review: multi-stage build, non-root user, HEALTHCHECK, etc.
```

#### 2.2. Build Docker Image

Build image with tags:
```bash
# Latest tag (for staging)
docker build -t cbenitez/beersystem:latest .

# Version tag (for versioning)
docker build -t cbenitez/beersystem:v1.0.0 .
```

Test image locally (optional):
```bash
docker run -p 8000:8000 --env DATABASE_URL="postgresql://..." cbenitez/beersystem:latest
# Verify application starts successfully
# Ctrl+C to stop
```

#### 2.3. Push to Docker Hub

Login to Docker Hub:
```bash
docker login
# Enter username and password
```

Push images:
```bash
docker push cbenitez/beersystem:latest
docker push cbenitez/beersystem:v1.0.0
```

Verify on Docker Hub:
```bash
# Visit https://hub.docker.com/r/cbenitez/beersystem
# Confirm images appear
```

---

### Phase 3: Kubernetes Manifests Creation

**Objective**: Create Kubernetes deployment manifests in beersystem repository

**Location**: `/Users/cbenitez/beersystem/k8s/`

#### 3.1. Create k8s Directory

```bash
cd /Users/cbenitez/beersystem
mkdir -p k8s
```

#### 3.2. Create Namespace Manifest

`k8s/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: beersystem
  labels:
    app: beersystem
    environment: staging
```

#### 3.3. Create Secret Template

`k8s/secret.yaml.template` (template only, not actual secret):
```yaml
# DO NOT COMMIT ACTUAL SECRET TO GIT
# This is a template - replace <values> with actual credentials
apiVersion: v1
kind: Secret
metadata:
  name: beersystem-db-credentials
  namespace: beersystem
type: Opaque
stringData:
  DATABASE_URL: "postgresql://beersystem_admin:<PASSWORD>@postgres-rw.postgres.svc.cluster.local:5432/beersystem_stage"
  DB_HOST: "postgres-rw.postgres.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "beersystem_stage"
  DB_USER: "beersystem_admin"
  DB_PASSWORD: "<PASSWORD>"  # Replace with actual beersystem_admin password
```

Create actual secret manually (not in Git):
```bash
# Create secret.yaml from template with actual password
cp k8s/secret.yaml.template k8s/secret.yaml
# Edit k8s/secret.yaml and replace <PASSWORD> with actual password
# Apply secret:
kubectl apply -f k8s/secret.yaml
# Delete file after applying:
rm k8s/secret.yaml
```

Add secret.yaml to .gitignore:
```bash
echo "k8s/secret.yaml" >> .gitignore
```

#### 3.4. Create ConfigMap

`k8s/configmap.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: beersystem-config
  namespace: beersystem
data:
  # Application configuration (non-sensitive)
  ENVIRONMENT: "staging"
  LOG_LEVEL: "INFO"
  # Add other non-sensitive config as needed
```

#### 3.5. Create Deployment

`k8s/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beersystem
  namespace: beersystem
  labels:
    app: beersystem
    component: app
spec:
  replicas: 1  # Single replica for staging (HA later)
  selector:
    matchLabels:
      app: beersystem
      component: app
  template:
    metadata:
      labels:
        app: beersystem
        component: app
    spec:
      containers:
        - name: beersystem
          image: cbenitez/beersystem:latest
          imagePullPolicy: Always  # Always pull for staging (use specific tag for prod)

          ports:
            - name: http
              containerPort: 8000
              protocol: TCP

          env:
            # Database connection from Secret
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: beersystem-db-credentials
                  key: DATABASE_URL

            # Configuration from ConfigMap
            - name: ENVIRONMENT
              valueFrom:
                configMapKeyRef:
                  name: beersystem-config
                  key: ENVIRONMENT

            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: beersystem-config
                  key: LOG_LEVEL

          # Health checks
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2

          # Resource limits
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi

      # Security context
      securityContext:
        runAsNonRoot: true
        fsGroup: 1000
```

#### 3.6. Create Service

`k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: beersystem-service
  namespace: beersystem
  labels:
    app: beersystem
    component: service
spec:
  type: ClusterIP
  selector:
    app: beersystem
    component: app
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8000
  sessionAffinity: None
```

#### 3.7. Commit Manifests to Git

**Note**: No Kubernetes Ingress or Certificate resources needed. Cloudflare Tunnel handles routing and TLS termination.

```bash
git add k8s/
git commit -m "Add Kubernetes manifests for beersystem deployment"
git push origin main  # Or staging branch
```

---

### Phase 4: Cloudflare Tunnel Configuration

**Objective**: Add beer.chocolandiadc.com route to existing Cloudflare Tunnel configuration

**Location**: `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare/`

#### 4.1. Update Cloudflare Tunnel Ingress Rules

Navigate to Cloudflare Terraform configuration from feature 004:
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare
```

Update tunnel configuration (likely in `tunnel.tf` or `main.tf`) to add beersystem route:
```hcl
# Add to existing cloudflare_tunnel_config resource
resource "cloudflare_tunnel_config" "chocolandiadc_tunnel" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.chocolandiadc.id

  config {
    # Existing ingress rules (pihole, grafana, etc.)
    # ...

    # Add beersystem route
    ingress_rule {
      hostname = "beer.chocolandiadc.com"
      service  = "http://beersystem-service.beersystem.svc.cluster.local:80"
    }

    # Catch-all rule (must be last)
    ingress_rule {
      service = "http_status:404"
    }
  }
}
```

#### 4.2. Add DNS CNAME Record

Add DNS record for beer.chocolandiadc.com (if not auto-created):
```hcl
resource "cloudflare_record" "beersystem" {
  zone_id = var.cloudflare_zone_id
  name    = "beer"
  value   = "${cloudflare_tunnel.chocolandiadc.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true  # Enable Cloudflare proxy (orange cloud)
}
```

#### 4.3. Add Cloudflare Access Policy (Optional)

If you want authentication before accessing beersystem:
```hcl
resource "cloudflare_access_application" "beersystem" {
  zone_id          = var.cloudflare_zone_id
  name             = "BeerSystem Application"
  domain           = "beer.chocolandiadc.com"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "beersystem_allow" {
  application_id = cloudflare_access_application.beersystem.id
  zone_id        = var.cloudflare_zone_id
  name           = "Allow authorized users"
  precedence     = 1
  decision       = "allow"

  include {
    email = ["cbenitez@gmail.com"]  # Add authorized emails
  }
}
```

#### 4.4. Apply Cloudflare Configuration

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare
tofu validate
tofu plan
tofu apply
# Review changes, type 'yes' to confirm
```

#### 4.5. Verify Cloudflare Tunnel Update

Check tunnel status:
```bash
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50
# Should show new route registered for beer.chocolandiadc.com
```

Verify DNS:
```bash
nslookup beer.chocolandiadc.com
# Should resolve to Cloudflare tunnel CNAME
```

---

### Phase 5: ArgoCD Application Configuration

**Objective**: Configure ArgoCD to monitor and sync beersystem manifests

**Location**: `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/argocd-apps/`

#### 5.1. Create ArgoCD Application Manifest

```bash
cd /Users/cbenitez/chocolandia_kube
mkdir -p terraform/environments/chocolandiadc-mvp/argocd-apps
```

Create `beersystem-app.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: beersystem
  namespace: argocd
  labels:
    app: beersystem
spec:
  project: default

  source:
    repoURL: https://github.com/cbenitez/beersystem  # Replace with actual repo URL
    targetRevision: main  # Or staging branch
    path: k8s

  destination:
    server: https://kubernetes.default.svc
    namespace: beersystem

  syncPolicy:
    automated:
      prune: true  # Remove resources deleted from Git
      selfHeal: true  # Correct manual changes
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### 5.2. Apply ArgoCD Application

```bash
kubectl apply -f terraform/environments/chocolandiadc-mvp/argocd-apps/beersystem-app.yaml
```

#### 5.3. Verify ArgoCD Sync

Check ArgoCD UI:
```bash
# Get ArgoCD password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open browser to https://localhost:8080
# Login with username 'admin' and password from above
# Verify beersystem application appears and syncs successfully
```

Or check via CLI:
```bash
kubectl get application -n argocd beersystem
kubectl describe application -n argocd beersystem
```

---

### Phase 6: Verification and Testing

**Objective**: Validate complete deployment and application functionality

#### 6.1. Check Pod Status

```bash
kubectl get pods -n beersystem
# Expected: beersystem pod in Running state, READY 1/1
```

If pod is not ready, check logs:
```bash
kubectl logs -n beersystem -l app=beersystem --tail=100
```

#### 6.2. Check Service Endpoints

```bash
kubectl get endpoints -n beersystem
# Expected: beersystem-service endpoint with pod IP
```

#### 6.3. Check Cloudflare Tunnel Logs

```bash
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100 | grep beer
# Expected: Should show beer.chocolandiadc.com route registered and handling requests
```

#### 6.4. Test Application Accessibility

From external network (outside cluster):
```bash
# Test HTTPS with Cloudflare certificate
curl -I https://beer.chocolandiadc.com
# Expected: 200 OK with Cloudflare-managed TLS certificate

# Verify certificate details
openssl s_client -connect beer.chocolandiadc.com:443 -servername beer.chocolandiadc.com < /dev/null 2>/dev/null | openssl x509 -noout -text
# Expected: Certificate issued by Cloudflare (or Let's Encrypt via Cloudflare)
```

From browser:
```bash
# Open https://beer.chocolandiadc.com
# Expected: Application loads, no certificate warnings
```

#### 6.5. Test Database Connectivity

Execute database query from within application pod:
```bash
kubectl exec -it -n beersystem deploy/beersystem -- sh

# Inside pod (adjust based on app structure):
# If Python app with psycopg2:
python3 -c "import os, psycopg2; conn = psycopg2.connect(os.environ['DATABASE_URL']); print('Database connection successful'); conn.close()"

# Expected: "Database connection successful"
```

#### 6.6. Verify ArgoCD Sync Status

```bash
kubectl get application -n argocd beersystem -o jsonpath='{.status.sync.status}'
# Expected: Synced

kubectl get application -n argocd beersystem -o jsonpath='{.status.health.status}'
# Expected: Healthy
```

---

## Rollback Procedures

### Rollback Application Deployment (ArgoCD)

If deployment has issues, rollback via Git:
```bash
cd /Users/cbenitez/beersystem
git revert HEAD  # Revert last commit
git push origin main

# ArgoCD will auto-sync and rollback deployment
```

Manual rollback (bypass ArgoCD):
```bash
kubectl rollout undo deployment/beersystem -n beersystem
```

### Rollback Database Changes (OpenTofu)

**CAUTION**: This will delete database and user (data loss!)
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/beersystem-db
tofu destroy
# Type 'yes' to confirm
```

---

## Troubleshooting

### Pod CrashLoopBackOff

Check logs:
```bash
kubectl logs -n beersystem -l app=beersystem --tail=100
```

Common causes:
- Database connection failure (check DATABASE_URL secret)
- Application startup error (check app logs)
- Health check failure (verify /health endpoint)

### Certificate Not Issued

Check cert-manager logs:
```bash
kubectl logs -n cert-manager deploy/cert-manager
```

Check ACME challenge:
```bash
kubectl describe challenge -n beersystem
```

Verify DNS:
```bash
nslookup beer.chocolandiadc.com
# Must resolve to cluster ingress IP
```

Verify HTTP reachability:
```bash
curl http://beer.chocolandiadc.com/.well-known/acme-challenge/test
# Should not return 404 from Traefik (challenge route should exist during validation)
```

### 502 Bad Gateway

Check if pods are ready:
```bash
kubectl get pods -n beersystem
```

Check service endpoints:
```bash
kubectl get endpoints beersystem-service -n beersystem
# Should have pod IP listed
```

Test service internally:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://beersystem-service.beersystem.svc.cluster.local
```

### ArgoCD Sync Fails

Check application status:
```bash
kubectl describe application beersystem -n argocd
```

Check ArgoCD logs:
```bash
kubectl logs -n argocd deploy/argocd-application-controller
kubectl logs -n argocd deploy/argocd-repo-server
```

Verify Git repository access:
```bash
# If private repo, check ArgoCD repository credentials
kubectl get secret -n argocd
```

---

## Success Criteria Validation

Validate feature success criteria from spec.md:

- [ ] **SC-001**: Users can access https://beer.chocolandiadc.com with <2s response time
  ```bash
  time curl -s https://beer.chocolandiadc.com > /dev/null
  # Should complete in under 2 seconds
  ```

- [ ] **SC-002**: Application uptime tracked (monitor over 30 days)
  - Use Prometheus metrics (if enabled): `up{job="beersystem"}`

- [ ] **SC-003**: Database schema changes can be applied within 5 minutes
  - Test with sample migration

- [ ] **SC-004**: Code changes deploy via ArgoCD within 10 minutes
  - Make trivial change to k8s manifest, commit, verify sync time

- [ ] **SC-005**: Zero manual intervention for deployments
  - Verify ArgoCD auto-sync is enabled and working

- [ ] **SC-006**: Database data persists through restarts
  ```bash
  # Write test data, restart pod, verify data still exists
  ```

- [ ] **SC-007**: Application handles 100 concurrent users
  - Use load testing tool (hey, ab, wrk) to simulate traffic

---

## Monitoring and Maintenance

### Health Monitoring

Check application health:
```bash
kubectl get pods -n beersystem -w
# Watch for restarts or crashes
```

Check resource usage:
```bash
kubectl top pods -n beersystem
# Monitor CPU and memory usage
```

### Log Aggregation

View application logs:
```bash
kubectl logs -n beersystem -l app=beersystem -f
# Follow logs in real-time
```

### Certificate Renewal

Cert-manager automatically renews certificates 30 days before expiration.

Check renewal status:
```bash
kubectl get certificate beersystem-tls -n beersystem -o jsonpath='{.status.renewalTime}'
```

---

## Next Steps

After successful deployment:

1. **Enable monitoring**: Configure Prometheus scraping and Grafana dashboards (future enhancement)
2. **Implement backups**: Schedule regular database backups
3. **Load testing**: Validate performance under load
4. **HA deployment**: Scale to multiple replicas for high availability
5. **CI/CD integration**: Automate image builds and deployments via GitHub Actions
6. **Security hardening**: Add network policies, pod security policies, vulnerability scanning

---

## References

- Feature Specification: [spec.md](./spec.md)
- Implementation Plan: [plan.md](./plan.md)
- Research Decisions: [research.md](./research.md)
- Data Model: [data-model.md](./data-model.md)
- Ingress Specification: [contracts/ingress-spec.yaml](./contracts/ingress-spec.yaml)
