# Data Model: Jenkins CI Deployment

**Feature**: 029-jenkins-ci
**Date**: 2026-01-07

## Overview

This feature is infrastructure-focused. The "data model" describes Kubernetes resources and their relationships rather than application entities.

## Kubernetes Resources

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
  labels:
    app: jenkins
    managed-by: opentofu
```

### PersistentVolumeClaim

| Field | Value | Description |
|-------|-------|-------------|
| Name | jenkins-data | Jenkins home directory |
| Storage | 20Gi | Job configs, build history, plugins |
| Access Mode | ReadWriteOnce | Single pod access |
| Storage Class | local-path | local-path-provisioner |

### Deployment (via Helm)

| Component | Replicas | Image | Description |
|-----------|----------|-------|-------------|
| Jenkins Controller | 1 | jenkins/jenkins:lts-jdk17 | Main Jenkins server |
| DinD Sidecar | 1 | docker:24-dind | Docker daemon for builds |

### Services

| Name | Type | Ports | Description |
|------|------|-------|-------------|
| jenkins | ClusterIP | 8080 (HTTP), 50000 (Agent) | Jenkins web UI and agent port |

### Secrets

| Name | Type | Keys | Description |
|------|------|------|-------------|
| jenkins-admin | Opaque | password | Jenkins admin password |
| nexus-docker-credentials | Opaque | username, password | Nexus registry auth |

### Certificates (cert-manager)

| Name | Issuer | DNS Names | Description |
|------|--------|-----------|-------------|
| jenkins-tls | local-ca | jenkins.chocolandiadc.local | LAN TLS certificate |

### Traefik Resources

| Resource | Name | Description |
|----------|------|-------------|
| Middleware | jenkins-https-redirect | HTTP to HTTPS redirect |
| IngressRoute | jenkins-http | HTTP entrypoint (redirect) |
| IngressRoute | jenkins-https | HTTPS entrypoint (main) |

### Monitoring Resources

| Resource | Name | Description |
|----------|------|-------------|
| ServiceMonitor | jenkins-metrics | Prometheus scrape config |
| PrometheusRule | jenkins-alerts | Alert rules |
| ConfigMap | jenkins-grafana-dashboard | Grafana dashboard JSON |

### Cloudflare Resources

| Resource | Type | Value |
|----------|------|-------|
| Tunnel Ingress Rule | Application | jenkins.chocolandiadc.com → jenkins.jenkins.svc:8080 |
| Access Application | Zero Trust | Protected by Google OAuth |

## Resource Relationships

```
                                    ┌─────────────────────┐
                                    │  Cloudflare Tunnel  │
                                    │  (jenkins.*.com)    │
                                    └──────────┬──────────┘
                                               │
                                               ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   cert-manager  │───▶│    Traefik      │◀───│   local DNS     │
│   (local-ca)    │    │  IngressRoute   │    │ (*.local)       │
└─────────────────┘    └────────┬────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Jenkins Svc    │
                       │  (ClusterIP)    │
                       └────────┬────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PVC           │───▶│  Jenkins Pod    │◀───│  Secrets        │
│   (jenkins-data)│    │  + DinD Sidecar │    │  (credentials)  │
└─────────────────┘    └────────┬────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Nexus Registry │
                       │  (docker push)  │
                       └─────────────────┘
```

## Configuration as Code (JCasC)

Jenkins configuration is managed declaratively via JCasC plugin:

### Security Realm

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: ${JENKINS_ADMIN_PASSWORD}
```

### Authorization Strategy

```yaml
jenkins:
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
```

### Tool Installations

```yaml
tool:
  jdk:
    installations:
      - name: "JDK17"
        properties:
          - installSource:
              installers:
                - adoptOpenJdkInstaller:
                    id: "jdk-17.0.9+9"
      - name: "JDK21"
        properties:
          - installSource:
              installers:
                - adoptOpenJdkInstaller:
                    id: "jdk-21.0.1+12"
  maven:
    installations:
      - name: "Maven3"
        properties:
          - installSource:
              installers:
                - maven:
                    id: "3.9.6"
  nodejs:
    installations:
      - name: "NodeJS18"
        properties:
          - installSource:
              installers:
                - nodeJSInstaller:
                    id: "18.19.0"
      - name: "NodeJS20"
        properties:
          - installSource:
              installers:
                - nodeJSInstaller:
                    id: "20.11.0"
  go:
    installations:
      - name: "Go1.21"
        properties:
          - installSource:
              installers:
                - golangInstaller:
                    id: "1.21.6"
      - name: "Go1.22"
        properties:
          - installSource:
              installers:
                - golangInstaller:
                    id: "1.22.0"
```

### Credentials

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: "nexus-docker"
              username: ${NEXUS_USERNAME}
              password: ${NEXUS_PASSWORD}
              description: "Nexus Docker Registry"
```

### Unclassified (ntfy notifications)

```yaml
unclassified:
  location:
    url: "https://jenkins.chocolandiadc.local"
```

## Helm Values Structure

```yaml
controller:
  image: jenkins/jenkins
  tag: lts-jdk17
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

  installPlugins:
    - kubernetes
    - docker-workflow
    - docker-commons
    - pipeline-stage-view
    - workflow-aggregator
    - git
    - maven-plugin
    - nodejs
    - pyenv-pipeline
    - golang
    - prometheus
    - configuration-as-code
    - credentials-binding

  JCasC:
    configScripts:
      security: |
        # Security configuration
      tools: |
        # Tool installations
      credentials: |
        # Credentials from secrets

  sidecars:
    configAutoReload:
      enabled: true
    other:
      - name: dind
        image: docker:24-dind
        securityContext:
          privileged: true
        env:
          - name: DOCKER_TLS_CERTDIR
            value: ""
        volumeMounts:
          - name: docker-graph-storage
            mountPath: /var/lib/docker

persistence:
  enabled: true
  size: 20Gi
  storageClass: local-path

serviceAccount:
  create: true
  name: jenkins
```
