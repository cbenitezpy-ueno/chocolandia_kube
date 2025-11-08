# Research: K3s HA Cluster with Terraform

**Feature**: 001-k3s-cluster-setup
**Date**: 2025-11-08
**Purpose**: Document technology choices, best practices, and architectural decisions for K3s HA cluster implementation

## Technology Decisions

### Decision 1: K3s over Full Kubernetes (K8s)

**Decision**: Use K3s as the Kubernetes distribution

**Rationale**:
- **Lightweight**: K3s binary is <70MB vs K8s multi-GB, ideal for resource-constrained mini-PCs
- **Embedded etcd**: K3s includes embedded etcd, simplifying HA setup (no separate etcd cluster)
- **Single binary**: Easy to install and upgrade, reduces operational complexity
- **Production-ready**: CNCF-certified Kubernetes distribution, fully compliant
- **Perfect for edge/homelab**: Designed for edge, IoT, and resource-constrained environments
- **Learning value**: Teaches Kubernetes concepts without heavy infrastructure overhead

**Alternatives Considered**:
- **Full Kubernetes (kubeadm)**: More complex setup, requires separate etcd cluster for HA, heavier resource footprint. Rejected due to higher operational complexity for learning environment.
- **MicroK8s**: Canonical's lightweight K8s, similar to K3s but less mature HA story for bare-metal. K3s has better documentation and community support for HA on bare-metal.
- **Kind (Kubernetes in Docker)**: Containerized K8s, great for local dev but not suitable for multi-node bare-metal clusters.

**References**:
- K3s Documentation: https://docs.k3s.io/
- K3s HA Setup: https://docs.k3s.io/datastore/ha-embedded

---

### Decision 2: Terraform over Ansible/Other IaC Tools

**Decision**: Use Terraform as the exclusive Infrastructure as Code tool

**Rationale**:
- **Declarative**: Terraform's declarative syntax clearly expresses desired state
- **Plan preview**: `terraform plan` shows changes before apply, critical for learning and safety
- **State tracking**: Terraform state provides single source of truth for infrastructure
- **Idempotent**: Terraform handles resource creation, update, and deletion intelligently
- **Wide provider ecosystem**: Terraform providers for SSH provisioning, Kubernetes, Helm
- **Learning value**: Terraform is industry-standard IaC tool, highly marketable skill

**Alternatives Considered**:
- **Ansible**: Procedural (vs declarative), no built-in state tracking, requires inventory management. Good for configuration management but less suited for infrastructure provisioning.
- **Pulumi**: Multi-language IaC (Python, TypeScript, Go), but HCL syntax is clearer for infrastructure definition and has larger community.
- **Manual scripts (bash)**: No state management, error-prone, not idempotent. Suitable for small tasks but not complex infrastructure.

**Implementation Notes**:
- Use Terraform `null_resource` with `remote-exec` provisioner for SSH-based K3s installation
- Terraform Helm provider for Prometheus/Grafana deployment
- Terraform Kubernetes provider for post-deployment configuration (RBAC, resource limits)
- Local state file initially, with option to migrate to remote backend (S3, Terraform Cloud) later

**References**:
- Terraform Docs: https://developer.hashicorp.com/terraform
- Terraform SSH Provisioner: https://developer.hashicorp.com/terraform/language/resources/provisioners/remote-exec
- Terraform Helm Provider: https://registry.terraform.io/providers/hashicorp/helm

---

### Decision 3: 3+1 Topology (3 Control-Plane + 1 Worker)

**Decision**: Deploy 3 control-plane nodes and 1 worker node

**Rationale**:
- **Etcd quorum**: Etcd requires minimum 3 nodes for fault tolerance (tolerates 1 failure, maintains quorum with 2/3 nodes)
- **HA guarantee**: 3 control-plane nodes ensure Kubernetes API survives single node failure
- **Resource efficiency**: Maximizes learning value with 4 available nodes (3+1 uses all nodes effectively)
- **Best practice alignment**: 3 control-plane nodes is production-standard minimum for HA
- **Learning focus**: Teaches distributed consensus (etcd quorum) and HA architecture

**Alternatives Considered**:
- **2 control-plane + 2 workers**: Insufficient for HA (etcd cannot tolerate 1 failure with only 2 nodes)
- **4 control-plane**: Wastes resources, no workers for workload separation (though etcd quorum works with 4, losing 1 node still maintains quorum)
- **1 control-plane + 3 workers**: Not HA, single point of failure

**Etcd Quorum Math**:
- Formula: Quorum = (N/2) + 1
- 3 nodes: Quorum = 2, tolerates 1 failure ✅
- 2 nodes: Quorum = 2, tolerates 0 failures ❌

**References**:
- Etcd Documentation: https://etcd.io/docs/v3.5/faq/#what-is-failure-tolerance
- K3s HA Architecture: https://docs.k3s.io/architecture#high-availability-with-an-external-db

---

### Decision 4: Prometheus + Grafana Monitoring Stack

**Decision**: Deploy Prometheus for metrics collection and Grafana for visualization

**Rationale**:
- **Industry standard**: Prometheus is de facto monitoring solution for Kubernetes
- **Native Kubernetes support**: Prometheus scrapes metrics from kubelet, apiserver, etcd automatically
- **Pull-based architecture**: Prometheus pulls metrics from targets, simplifying firewall rules
- **PromQL**: Powerful query language for metrics analysis and alerting
- **Grafana integration**: Pre-built Kubernetes dashboards, rich visualization capabilities
- **Learning value**: Core cloud-native observability stack, essential skill for Kubernetes operators

**Prometheus Components**:
- **Prometheus Server**: Metrics collection, storage, querying
- **Node Exporter**: Hardware/OS metrics from mini-PCs (CPU, memory, disk, network)
- **Kube-State-Metrics**: Kubernetes object state metrics (deployments, pods, nodes)
- **Alertmanager**: Alert routing and notification (email, Slack, etc.)

**Grafana Dashboards**:
- Cluster overview: CPU, memory, disk, network across all nodes
- Kubernetes components: apiserver, scheduler, controller-manager, kubelet health
- Etcd metrics: quorum status, leader election, latency
- Custom alerts: Node NotReady, disk space <15%, etcd quorum lost

**Alternatives Considered**:
- **ELK Stack (Elasticsearch, Logstash, Kibana)**: Log aggregation focus, heavier resource footprint. Prometheus is better for metrics and resource-efficient.
- **Datadog/New Relic**: Commercial SaaS solutions, excellent features but not suitable for learning self-hosted observability.
- **Loki + Grafana**: Log aggregation, complements Prometheus but not a replacement. May add Loki later for log aggregation.

**Deployment Method**: Helm charts (kube-prometheus-stack) for production-grade deployment with sane defaults

**References**:
- Prometheus Docs: https://prometheus.io/docs/
- Kube-Prometheus-Stack Helm Chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Grafana Dashboards: https://grafana.com/grafana/dashboards/?search=kubernetes

---

### Decision 5: Local State File with Manual Backup

**Decision**: Use local Terraform state file initially, with manual backup procedures

**Rationale**:
- **Simplicity**: No remote backend setup required for initial learning
- **Full control**: State file on local disk, no dependencies on cloud services
- **Cost**: Free (no S3, Terraform Cloud costs)
- **Learning value**: Understanding state file structure and importance before abstracting to remote backend
- **Migration path**: Can migrate to remote backend (S3, Terraform Cloud) later without code changes

**State Management Practices**:
- State file location: `terraform/environments/chocolandiadc/terraform.tfstate`
- Backup: Manual copy to `terraform/environments/chocolandiadc/backups/` after each apply
- `.gitignore`: State file excluded from Git (contains sensitive data like IPs, tokens)
- State locking: Not available with local backend (acceptable for solo learning)

**Future Enhancement**: Migrate to S3 backend with state locking (DynamoDB) or Terraform Cloud for collaboration scenarios

**References**:
- Terraform State: https://developer.hashicorp.com/terraform/language/state
- Remote Backends: https://developer.hashicorp.com/terraform/language/settings/backends

---

## Best Practices & Patterns

### Terraform Module Design

**Pattern**: Reusable modules with clear input/output contracts

**Structure**:
```
terraform/modules/<module-name>/
├── main.tf       # Resource definitions
├── variables.tf  # Input variables with descriptions and validation
├── outputs.tf    # Output values for module composition
└── README.md     # Module documentation (purpose, usage, examples)
```

**Benefits**:
- Composability: Modules can be combined to build complex infrastructure
- Reusability: Same module for multiple nodes (master1, master2, master3)
- Testability: Each module can be tested independently
- Documentation: README explains module purpose and usage

**Example - k3s-node module**:
```hcl
# Input: node_name, node_ip, role (control-plane or worker), cluster_token
# Output: node_status, kubeconfig (if control-plane)
# Purpose: Provision a single K3s node via SSH
```

---

### K3s Installation Best Practices

**Installation Method**: K3s install script via SSH remote-exec

**Control-Plane Node (master1)**:
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --tls-san <master1-ip> \
  --node-name master1
```

**Additional Control-Plane Nodes (master2, master3)**:
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://<master1-ip>:6443 \
  --token <cluster-token> \
  --node-name master2
```

**Worker Node (nodo1)**:
```bash
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://<master1-ip>:6443 \
  --token <cluster-token> \
  --node-name nodo1
```

**Key Parameters**:
- `--cluster-init`: Initialize embedded etcd for HA
- `--tls-san`: Add IP/hostname to TLS certificate SAN for API access
- `--token`: Cluster join token (generated on master1, shared securely)
- `--node-name`: Explicit node hostname (master1-3, nodo1)

**References**:
- K3s Quick-Start: https://docs.k3s.io/quick-start
- K3s Server Configuration: https://docs.k3s.io/reference/server-config

---

### Terraform Provisioning Order

**Sequential Dependencies**:

1. **Phase 1**: Provision master1 (first control-plane node)
   - Install K3s with `--cluster-init`
   - Extract cluster token from `/var/lib/rancher/k3s/server/node-token`
   - Extract kubeconfig from `/etc/rancher/k3s/k3s.yaml`
   - Wait for node Ready (kubectl get nodes)

2. **Phase 2**: Provision master2 and master3 (parallel)
   - Depends on master1 cluster token
   - Join as control-plane with `--server` flag
   - Wait for etcd quorum (3/3 members)

3. **Phase 3**: Provision nodo1 (worker node)
   - Depends on control-plane being operational
   - Join as agent with `--server` flag
   - Wait for node Ready

4. **Phase 4**: Deploy monitoring stack (Prometheus + Grafana)
   - Depends on cluster having compute capacity (all nodes Ready)
   - Use Helm provider to deploy kube-prometheus-stack
   - Configure Grafana data source (Prometheus URL)
   - Import pre-built dashboards

**Terraform Dependencies**: Use `depends_on` to enforce ordering where implicit dependencies are insufficient

---

### Testing Strategy

**Test Levels**:

1. **Terraform Validation** (Pre-Apply)
   ```bash
   terraform fmt -check
   terraform validate
   terraform plan -out=tfplan
   ```

2. **Cluster Health Tests** (Post-Apply Phase 1-3)
   ```bash
   kubectl get nodes --context=chocolandiadc
   # Expected: All nodes Ready
   kubectl get pods -A
   # Expected: All system pods Running
   ```

3. **HA Failover Tests** (Post-Apply Phase 2)
   ```bash
   # Shutdown master1
   ssh master1 sudo shutdown -h now

   # Verify API still accessible via master2/master3
   kubectl get nodes --context=chocolandiadc
   # Expected: master1 NotReady, master2/master3 Ready, API responsive
   ```

4. **Monitoring Stack Tests** (Post-Apply Phase 4)
   ```bash
   # Check Prometheus targets
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   curl http://localhost:9090/api/v1/targets
   # Expected: All targets up

   # Check Grafana accessibility
   kubectl port-forward -n monitoring svc/grafana 3000:80
   curl http://localhost:3000/api/health
   # Expected: HTTP 200 OK
   ```

5. **Workload Deployment Test** (Smoke Test)
   ```bash
   kubectl run nginx --image=nginx --context=chocolandiadc
   kubectl wait --for=condition=Ready pod/nginx --timeout=60s
   kubectl delete pod nginx
   # Expected: Pod reaches Running state within 60s
   ```

**Automated Test Scripts**: All tests scripted in `scripts/` directory with clear pass/fail output

---

## Security Considerations

### SSH Key Management

- **Requirement**: Passwordless SSH access to all mini-PCs
- **Setup**: Copy SSH public key to `~/.ssh/authorized_keys` on each mini-PC
- **Terraform**: Use SSH private key from `~/.ssh/id_rsa` (or specify custom path)
- **Security**: Private key never committed to Git, referenced via variable

### Cluster Token Security

- **Generation**: K3s auto-generates token in `/var/lib/rancher/k3s/server/node-token`
- **Retrieval**: Terraform reads token via SSH remote-exec after master1 installation
- **Distribution**: Token passed to additional nodes via Terraform variable
- **Storage**: Token stored in Terraform state (sensitive), never in Git

### Kubeconfig Security

- **Generation**: K3s auto-generates kubeconfig in `/etc/rancher/k3s/k3s.yaml`
- **Retrieval**: Terraform copies kubeconfig to local machine, updates server URL
- **Storage**: Kubeconfig stored locally in `~/.kube/config` (merged or separate context)
- **Permissions**: Kubeconfig file permissions set to 0600 (owner read/write only)

### Secrets Management

- **Prometheus/Grafana**: Credentials stored as Kubernetes Secrets
- **Grafana Admin Password**: Auto-generated, retrievable via `kubectl get secret`
- **Terraform Secrets**: Use `sensitive = true` for variables containing credentials

---

## Performance & Resource Planning

### Node Resource Allocation

**Control-Plane Nodes (master1-3)**:
- K3s control-plane: ~500MB RAM, 1 CPU core
- Etcd: ~300MB RAM, 0.5 CPU core
- System overhead: ~200MB RAM
- **Total**: ~1GB RAM, 1.5 CPU cores per control-plane node
- **Remaining**: ~3GB RAM, 0.5 CPU cores for system pods and monitoring

**Worker Node (nodo1)**:
- K3s agent: ~200MB RAM, 0.5 CPU core
- System overhead: ~100MB RAM
- **Total**: ~300MB RAM, 0.5 CPU cores
- **Remaining**: ~3.7GB RAM, 1.5 CPU cores for workload pods

**Monitoring Stack (deployed to all nodes)**:
- Prometheus: ~1GB RAM, 1 CPU core (metrics storage and queries)
- Grafana: ~200MB RAM, 0.5 CPU core (visualization)
- Node Exporter (per node): ~50MB RAM, 0.1 CPU core
- Kube-State-Metrics: ~100MB RAM, 0.2 CPU core

**Total Cluster Capacity**:
- 4 nodes × 4GB RAM = 16GB total
- Control-plane overhead: ~3GB (3 nodes × 1GB)
- Worker overhead: ~0.3GB
- Monitoring stack: ~2GB
- **Available for workloads**: ~10GB RAM for learning workloads

---

## Open Questions & Future Research

### Q1: Persistent Storage Strategy

**Question**: Should we deploy Longhorn for distributed block storage, or rely on K3s local-path provisioner?

**Current Decision**: Start with local-path provisioner (K3s default), evaluate Longhorn if persistent storage requirements emerge

**Future Research**:
- Longhorn installation and configuration
- Backup and disaster recovery for persistent volumes
- Performance impact of distributed storage on mini-PCs

### Q2: Cluster Networking (CNI)

**Question**: Use K3s default Flannel CNI, or switch to Calico for NetworkPolicy support?

**Current Decision**: Use Flannel (K3s default) for simplicity. Calico adds complexity and resource overhead.

**Future Research**:
- NetworkPolicy implementation with Flannel
- Calico installation if advanced network policies needed
- Performance comparison: Flannel vs Calico on bare-metal

### Q3: Ingress Controller

**Question**: Deploy Traefik (K3s default) or NGINX Ingress Controller?

**Current Decision**: Use Traefik (K3s default) for initial deployment

**Future Research**:
- Traefik configuration for Grafana/Prometheus ingress
- NGINX Ingress Controller as alternative
- Cert-manager for TLS certificate automation (Let's Encrypt)

---

## Conclusion

This research phase has resolved all technical unknowns required for implementation:

1. ✅ K3s selected as Kubernetes distribution
2. ✅ Terraform chosen as IaC tool
3. ✅ 3+1 topology (3 control-plane + 1 worker) justified
4. ✅ Prometheus + Grafana monitoring stack selected
5. ✅ Local Terraform state with manual backup
6. ✅ Best practices documented for modules, K3s installation, testing
7. ✅ Security considerations addressed (SSH keys, tokens, kubeconfig)
8. ✅ Resource allocation planned for 4-node cluster

**Next Phase**: Proceed to Phase 1 (Design & Contracts) to define data models, Terraform contracts, and quickstart guide.
