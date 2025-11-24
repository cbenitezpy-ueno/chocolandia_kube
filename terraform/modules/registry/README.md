# Registry Module

Private Docker Registry v2 deployment for the K3s homelab cluster.

## Purpose

Deploy a self-hosted container registry to replace AWS ECR dependency for local development. Provides a secure, authenticated registry with HTTPS support.

## Features

- Docker Registry v2 (Official image)
- Basic authentication via htpasswd
- HTTPS via Traefik Ingress + cert-manager
- Persistent storage via local-path-provisioner
- Health endpoints for monitoring

## Usage

```hcl
module "registry" {
  source = "../../modules/registry"

  namespace    = "registry"
  storage_size = "30Gi"
  hostname     = "registry.homelab.local"
  auth_secret  = "registry-auth"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace | Kubernetes namespace | string | "registry" | no |
| storage_size | PVC storage size | string | "30Gi" | no |
| hostname | Registry hostname | string | - | yes |
| auth_secret | Name of htpasswd secret | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| registry_url | Full registry URL (https://hostname) |
| credentials_secret_name | Name of the auth secret |

## Authentication

Generate htpasswd credentials:

```bash
htpasswd -Bbn admin <password> > htpasswd
kubectl create secret generic registry-auth -n registry --from-file=htpasswd=./htpasswd
```

## Docker Client Usage

```bash
docker login registry.homelab.local
docker tag myimage:latest registry.homelab.local/myimage:v1.0.0
docker push registry.homelab.local/myimage:v1.0.0
```

## K3s Node Configuration

Configure `/etc/rancher/k3s/registries.yaml` on each node:

```yaml
mirrors:
  "registry.homelab.local":
    endpoint:
      - "https://registry.homelab.local"
configs:
  "registry.homelab.local":
    auth:
      username: admin
      password: <password>
```

## Garbage Collection

Manual garbage collection when storage fills up:

```bash
kubectl exec -it -n registry deployment/registry -- registry garbage-collect /etc/docker/registry/config.yml
```
