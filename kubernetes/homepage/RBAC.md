# Homepage RBAC Permissions Explanation

Detailed explanation of Role-Based Access Control (RBAC) permissions for Homepage Dashboard.

## Overview

Homepage requires read-only access to various Kubernetes resources to display service status, metrics, and infrastructure information. This document explains the RBAC configuration, permission scope, and security rationale.

## RBAC Architecture

```
ServiceAccount (homepage)
    ↓
    ├─→ ClusterRoleBinding ──→ ClusterRole (homepage-cluster-viewer)
    │                              ├── nodes
    │                              ├── namespaces
    │                              ├── persistentvolumes
    │                              ├── ingresses (cluster-wide)
    │                              └── metrics (nodes, pods)
    │
    └─→ 6x RoleBindings ──→ 6x Roles (homepage-viewer)
              ↓                    ├── services, pods, pods/log
              ↓                    ├── deployments, replicasets, statefulsets, daemonsets
              ↓                    ├── ingresses
              ↓                    ├── certificates (cert-manager CRD)
              ↓                    └── applications (ArgoCD CRD)
              ↓
        Monitored Namespaces:
        - traefik
        - cert-manager
        - argocd
        - headlamp
        - homepage
        - monitoring
```

## ServiceAccount

**Resource**: `ServiceAccount homepage` in namespace `homepage`

**Purpose**: Identity for Homepage pods when accessing Kubernetes API.

**Configuration**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: homepage
  namespace: homepage
```

**Used by**: Homepage Deployment pod (`spec.serviceAccountName: homepage`)

---

## ClusterRole: homepage-cluster-viewer

**Scope**: Cluster-wide (all namespaces)

**Purpose**: Read access to cluster-level resources that don't belong to specific namespaces.

### Permissions Granted

#### 1. Nodes Access

```yaml
rule:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display cluster node information in dashboard widgets
- Node count
- Node status (Ready, NotReady)
- Node capacity (total CPU/memory)

**Security**: Read-only, no modification possible

#### 2. Namespaces Access

```yaml
rule:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: List and discover namespaces for service organization
- Namespace names
- Namespace status
- Namespace labels

**Security**: Read-only, cannot create/delete namespaces

#### 3. Persistent Volumes Access

```yaml
rule:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display storage information (cluster-wide PVs)
- PV capacity
- PV status (Available, Bound, Released)
- Storage class information

**Security**: Read-only, cannot modify or access PV data

**Note**: Not currently displayed in Homepage widgets, but available for future enhancements.

#### 4. Metrics Access

```yaml
rule:
  - apiGroups: ["metrics.k8s.io"]
    resources: ["nodes", "pods"]
    verbs: ["get", "list"]
```

**Purpose**: Display resource usage metrics from metrics-server
- Node CPU usage percentage
- Node memory usage percentage
- Pod CPU usage
- Pod memory usage

**Security**: Read-only metrics, no control over pods or nodes

**Requirement**: metrics-server must be installed in cluster

#### 5. Ingresses (Cluster-wide)

```yaml
rule:
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display ingress information across all namespaces
- Ingress hostnames
- Ingress backends
- TLS configuration

**Security**: Read-only, cannot modify ingress rules

---

## Role: homepage-viewer (per namespace)

**Scope**: Namespace-scoped (one Role per monitored namespace)

**Purpose**: Read access to resources within specific namespaces where services are deployed.

### Monitored Namespaces

Homepage monitors resources in the following namespaces:

1. **traefik**: Reverse proxy and ingress controller
2. **cert-manager**: TLS certificate management
3. **argocd**: GitOps continuous delivery
4. **headlamp**: Kubernetes web UI
5. **homepage**: Homepage dashboard itself
6. **monitoring**: Prometheus, Grafana, Alertmanager

### Permissions Granted (per namespace)

#### 1. Core Resources

```yaml
rule:
  - apiGroups: [""]
    resources: ["services", "pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

**Resources**:
- **services**: Service endpoints, ports, selectors
- **pods**: Pod status, phase, container information
- **pods/log**: Pod logs (read-only)

**Purpose**:
- Display service status widgets
- Show pod count and health
- Troubleshoot issues via log access

**Security**:
- Read-only access
- Cannot execute commands in pods
- Cannot modify pods or services

#### 2. Apps Resources

```yaml
rule:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
```

**Resources**:
- **deployments**: Deployment status, replicas, strategy
- **replicasets**: ReplicaSet replicas and pods
- **statefulsets**: StatefulSet replicas and persistence
- **daemonsets**: DaemonSet node coverage

**Purpose**:
- Display deployment status (ready/desired replicas)
- Show workload health across different controller types
- Track rolling updates

**Security**:
- Read-only access
- Cannot scale deployments
- Cannot trigger rollouts or rollbacks

#### 3. Ingresses (Namespaced)

```yaml
rule:
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display ingress routes for services in monitored namespaces

**Security**: Read-only, cannot modify routing rules

#### 4. Certificates (cert-manager CRD)

```yaml
rule:
  - apiGroups: ["cert-manager.io"]
    resources: ["certificates"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display TLS certificate status
- Certificate expiry dates
- Issuer information
- Ready status

**Security**:
- Read-only access to certificate metadata
- Cannot access private keys (stored in Secrets)
- Cannot issue or revoke certificates

**Requirement**: cert-manager must be installed

#### 5. ArgoCD Applications (CRD)

```yaml
rule:
  - apiGroups: ["argoproj.io"]
    resources: ["applications"]
    verbs: ["get", "list", "watch"]
```

**Purpose**: Display ArgoCD application sync status
- Sync status (Synced, OutOfSync)
- Health status (Healthy, Progressing, Degraded)
- Application metadata

**Security**:
- Read-only access
- Cannot trigger syncs
- Cannot modify application definitions

**Requirement**: ArgoCD must be installed

---

## Security Rationale

### Principle of Least Privilege

Homepage is granted **only** the minimum permissions required for its functionality:

1. **Read-only access**: No create, update, or delete permissions
2. **No Secret access**: Cannot read Secrets containing sensitive data
3. **No ConfigMap modification**: Cannot alter cluster configuration
4. **No exec permission**: Cannot execute commands in pods (except via pods/log read)
5. **Scoped namespaces**: Only monitors explicitly defined namespaces

### What Homepage CANNOT Do

❌ **Cannot modify any resources**:
- Cannot scale deployments
- Cannot delete pods
- Cannot edit services or ingresses
- Cannot trigger ArgoCD syncs

❌ **Cannot access sensitive data**:
- Cannot read Secrets
- Cannot read private keys from certificates
- Cannot access environment variables with credentials

❌ **Cannot affect cluster operation**:
- Cannot drain or cordon nodes
- Cannot delete namespaces
- Cannot modify RBAC permissions

❌ **Cannot execute code**:
- Cannot exec into pods
- Cannot port-forward
- Cannot attach to running containers

### What Homepage CAN Do

✅ **Read resource metadata**:
- Pod names, status, labels
- Service endpoints
- Deployment replica counts

✅ **Read resource metrics**:
- CPU and memory usage
- Pod count
- Node utilization

✅ **Read logs**:
- Pod logs via `pods/log` subresource
- Historical logs (not live tail)

✅ **Query CRDs**:
- cert-manager Certificates
- ArgoCD Applications

---

## Adding New Namespaces

To monitor a new namespace:

### 1. Update rbac.yaml

Add new namespace to `for_each` loop:

```yaml
# Role for service discovery (created in each monitored namespace)
resource "kubernetes_role" "homepage_viewer" {
  for_each = toset([
    "traefik",
    "cert-manager",
    "argocd",
    "headlamp",
    "homepage",
    "monitoring",
    "new-namespace"  # Add new namespace here
  ])

  # ... rest of Role definition
}

# RoleBinding (one per monitored namespace)
resource "kubernetes_role_binding" "homepage_viewer" {
  for_each = toset([
    "traefik",
    "cert-manager",
    "argocd",
    "headlamp",
    "homepage",
    "monitoring",
    "new-namespace"  # Add new namespace here
  ])

  # ... rest of RoleBinding definition
}
```

### 2. Verify RBAC After Deploy

```bash
# Check Role exists
kubectl get role homepage-viewer -n new-namespace

# Check RoleBinding exists
kubectl get rolebinding homepage-viewer -n new-namespace

# Test permissions
kubectl auth can-i list pods \
  --namespace=new-namespace \
  --as=system:serviceaccount:homepage:homepage
# Should output: yes
```

---

## Troubleshooting RBAC

### Test Specific Permission

```bash
kubectl auth can-i <verb> <resource> \
  --namespace=<namespace> \
  --as=system:serviceaccount:homepage:homepage
```

**Examples**:

```bash
# Test pod listing in traefik namespace
kubectl auth can-i list pods --namespace=traefik \
  --as=system:serviceaccount:homepage:homepage

# Test deployment access in argocd namespace
kubectl auth can-i get deployments.apps --namespace=argocd \
  --as=system:serviceaccount:homepage:homepage

# Test metrics access (cluster-wide)
kubectl auth can-i get pods.metrics.k8s.io \
  --as=system:serviceaccount:homepage:homepage

# Test Certificate CRD access
kubectl auth can-i list certificates.cert-manager.io --namespace=cert-manager \
  --as=system:serviceaccount:homepage:homepage
```

### Common Permission Errors

#### Error: "Forbidden: User 'system:serviceaccount:homepage:homepage' cannot list pods in namespace 'new-namespace'"

**Cause**: Namespace not in monitored_namespaces or Role not created.

**Solution**: Add namespace to rbac.yaml and apply.

#### Error: "Forbidden: User 'system:serviceaccount:homepage:homepage' cannot get certificates.cert-manager.io"

**Cause**: Missing CRD API group in Role.

**Solution**: Verify cert-manager.io API group is in Role definition:
```yaml
- apiGroups: ["cert-manager.io"]
  resources: ["certificates"]
  verbs: ["get", "list", "watch"]
```

#### Error: "Forbidden: User 'system:serviceaccount:homepage:homepage' cannot get pods.metrics.k8s.io"

**Cause**: Missing metrics.k8s.io API group in ClusterRole.

**Solution**: Verify metrics access in ClusterRole:
```yaml
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
```

---

## RBAC Best Practices

### 1. Regular Permission Audits

Periodically review granted permissions:

```bash
# List all Roles
kubectl get roles --all-namespaces | grep homepage

# List all RoleBindings
kubectl get rolebindings --all-namespaces | grep homepage

# List ClusterRole
kubectl get clusterrole homepage-cluster-viewer

# List ClusterRoleBinding
kubectl get clusterrolebinding homepage-cluster-viewer
```

### 2. Monitor Failed Permission Attempts

Check Homepage logs for permission errors:

```bash
kubectl logs -n homepage -l app=homepage --tail=100 | grep -i "forbidden\|unauthorized"
```

### 3. Document Custom Permissions

If adding custom permissions beyond this guide, document:
- Why the permission is needed
- What resource it accesses
- Security implications
- Alternative approaches considered

### 4. Use Namespaced Roles When Possible

Prefer **Roles** over **ClusterRoles** for namespace-specific permissions:

✅ **Good**: Role in specific namespace
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-namespace
```

❌ **Avoid**: ClusterRole when namespace scope is sufficient
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: too-broad
```

---

## Security Contacts

If you discover a security issue with Homepage RBAC permissions:

1. **Review this document** to verify intended behavior
2. **Check Homepage logs** for unauthorized access attempts
3. **Audit RBAC resources** using kubectl commands above
4. **Report to cluster administrator** if permissions seem excessive

---

## Additional Resources

- **Kubernetes RBAC Documentation**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **kubectl auth can-i**: https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access
- **ServiceAccount Authentication**: https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
