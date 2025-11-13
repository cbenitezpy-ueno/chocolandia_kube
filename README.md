# Chocolandia Kube - Homelab Infrastructure

[![Wiki Sync](https://github.com/cbenitezpy-ueno/chocolandia_kube/actions/workflows/wiki-sync.yml/badge.svg)](https://github.com/cbenitezpy-ueno/chocolandia_kube/actions/workflows/wiki-sync.yml)

Enterprise-grade homelab infrastructure using K3s, OpenTofu, and GitOps principles.

## 🌐 Documentation

**📚 [View Full Documentation on Wiki](https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki)**

All feature documentation, quickstart guides, implementation plans, and technical details are available on the GitHub Wiki.

## 🏗️ Infrastructure Overview

This repository manages a complete homelab infrastructure with:

- **K3s Cluster**: High-availability Kubernetes cluster (3 control-plane + 1 worker node)
- **Network Security**: FortiGate 100D with VLAN segmentation
- **Infrastructure as Code**: All infrastructure managed via OpenTofu
- **GitOps Workflow**: Declarative infrastructure with version control
- **Observability**: Prometheus + Grafana monitoring stack
- **Secure Access**: Cloudflare Zero Trust tunneling

## 📦 Features

View all features on the [Wiki Homepage](https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki):

- **001**: K3s Cluster Setup - Initial cluster provisioning
- **002**: K3s MVP Eero - K3s on Eero network
- **003**: Pi-hole - DNS ad blocker
- **004**: Cloudflare Zero Trust - Secure remote access
- **005**: Traefik - Ingress controller
- **006**: Cert Manager - Automated SSL/TLS certificates
- **007**: Headlamp - Kubernetes web UI
- **008**: GitOps ArgoCD - Automated deployments
- **009**: Homepage Dashboard - Unified service dashboard
- **010**: GitHub Wiki Docs - This documentation system

## 🚀 Quick Start

Each feature has its own quickstart guide. See the [Wiki](https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki) for step-by-step deployment instructions.

### Prerequisites

- OpenTofu 1.6+
- kubectl
- Access to K3s cluster
- Git

### Deploy a Feature

```bash
# Navigate to feature terraform directory
cd terraform/modules/<feature-name>

# Initialize OpenTofu
tofu init

# Review changes
tofu plan

# Apply configuration
tofu apply
```

## 📁 Repository Structure

```
chocolandia_kube/
├── specs/                  # Feature specifications and documentation
│   └── XXX-feature-name/
│       ├── spec.md         # User scenarios and requirements
│       ├── quickstart.md   # Deployment guide
│       ├── plan.md         # Implementation plan
│       └── tasks.md        # Task breakdown
├── terraform/              # OpenTofu/Terraform configurations
│   ├── modules/            # Reusable infrastructure modules
│   └── environments/       # Environment-specific configs
├── scripts/                # Automation and utility scripts
│   └── wiki/               # Wiki sync automation
└── .github/                # GitHub Actions workflows
```

## 🔄 Documentation Workflow

Documentation is maintained in the `specs/` directory and synchronized to the GitHub Wiki.

### Update Documentation

Documentation sync happens automatically via GitHub Actions:

1. Edit files in `specs/XXX-feature-name/` directory
2. Commit and push changes to `main` branch
3. GitHub Actions automatically syncs to Wiki

**Manual sync** (optional):
```bash
./scripts/wiki/sync-to-wiki.sh --with-sidebar
```

**Do not edit Wiki pages directly** - changes will be overwritten on next sync.

See [Wiki Sync Documentation](scripts/wiki/README.md) for details.

## 🛠️ Development

### Constitution

This project follows a [constitution](/.specify/memory/constitution.md) based on 9 core principles:

1. Infrastructure as Code - OpenTofu First
2. GitOps Workflow
3. Container-First Development
4. Observability & Monitoring (Prometheus + Grafana)
5. Security Hardening
6. High Availability Architecture
7. Test-Driven Learning
8. Documentation-First
9. Network-First Security

### Feature Development

New features follow the SpecKit workflow:

```bash
# 1. Create feature specification
/speckit.specify "feature description"

# 2. Generate implementation plan
/speckit.plan

# 3. Generate task breakdown
/speckit.tasks

# 4. Implement feature
/speckit.implement
```

## 🔐 Security

- Network perimeter: FortiGate firewall (single entry/exit)
- VLAN segmentation: Management, Cluster, Services, DMZ
- Access control: Cloudflare Zero Trust with Google OAuth
- Secrets management: Kubernetes Secrets (encrypted via etcd)
- No credentials in code (environment variables only)

## 📊 Monitoring

- **Prometheus**: Metrics collection from all services
- **Grafana**: Dashboards for cluster health and resource usage
- **Headlamp**: Kubernetes web UI for cluster management
- **Homepage**: Unified dashboard for all services

Access monitoring at: https://grafana.chocolandiadc.com

## 🤝 Contributing

This is a personal homelab project for learning enterprise infrastructure patterns.

To update documentation:
1. Fork the repository
2. Create a feature branch
3. Make changes in `specs/` directory
4. Submit a pull request

## 📝 License

Personal homelab project - see individual component licenses for details.

## 🔗 Links

- **Documentation**: [GitHub Wiki](https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki)
- **Wiki Sync Scripts**: [scripts/wiki/README.md](scripts/wiki/README.md)
- **Constitution**: [.specify/memory/constitution.md](/.specify/memory/constitution.md)

---

**Built with**: OpenTofu • K3s • FortiGate • Cloudflare • Prometheus • Grafana • ArgoCD

**Managed by**: GitOps workflow with Infrastructure as Code
