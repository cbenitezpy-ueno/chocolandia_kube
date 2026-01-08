# Quickstart: Jenkins CI

**Feature**: 029-jenkins-ci
**Date**: 2026-01-07

## Prerequisites

Before deploying Jenkins, ensure:

- [ ] K3s cluster is running (`kubectl get nodes`)
- [ ] Traefik ingress controller is deployed
- [ ] cert-manager with `local-ca` ClusterIssuer is available
- [ ] Nexus is deployed with docker-hosted repository configured
- [ ] Prometheus/Grafana monitoring stack is deployed
- [ ] ntfy is deployed for notifications
- [ ] Cloudflare Zero Trust tunnel is configured

## Deployment Steps

### 1. Deploy Jenkins Module

```bash
cd terraform/environments/chocolandiadc-mvp

# Initialize if needed
source ./backend-env.sh
tofu init

# Plan the deployment
tofu plan -target=module.jenkins

# Apply
tofu apply -target=module.jenkins
```

### 2. Get Admin Password

```bash
# From Terraform output
tofu output -raw jenkins_admin_password

# Or from Kubernetes secret
kubectl get secret -n jenkins jenkins-admin -o jsonpath='{.data.password}' | base64 -d
```

### 3. Access Jenkins

| Access Method | URL |
|---------------|-----|
| LAN (direct) | https://jenkins.chocolandiadc.local |
| Public (Cloudflare) | https://jenkins.chocolandiadc.com |
| NodePort (backup) | http://192.168.4.101:30080 |

Default credentials:
- Username: `admin`
- Password: (from step 2)

### 4. Trust Local CA (for LAN access)

If not already done:

```bash
# Export CA certificate
kubectl get secret -n cert-manager local-ca-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > chocolandia-local-ca.crt

# Trust on macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain chocolandia-local-ca.crt
```

## Verify Installation

### Check Pod Status

```bash
kubectl get pods -n jenkins
# Expected: jenkins-0 with 2/2 Ready (controller + dind sidecar)
```

### Check Services

```bash
kubectl get svc -n jenkins
# Expected: jenkins service on port 8080
```

### Check Plugins

Access Jenkins UI → Manage Jenkins → Manage Plugins → Installed

Required plugins should be listed:
- Kubernetes
- Docker Pipeline
- Maven Integration
- NodeJS
- Python (pyenv-pipeline)
- Go
- Prometheus Metrics
- Configuration as Code

### Check Tool Installations

Access Jenkins UI → Manage Jenkins → Global Tool Configuration

Should show:
- JDK installations (17, 21)
- Maven installations (3.9.x)
- NodeJS installations (18, 20)
- Go installations (1.21, 1.22)

## Create Test Pipeline

### 1. Create New Pipeline Job

- New Item → Pipeline → Name: "test-docker-build"

### 2. Pipeline Script

```groovy
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'docker.nexus.chocolandiadc.local'
        IMAGE_NAME = 'test-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    // Simple test image
                    writeFile file: 'Dockerfile', text: '''
                        FROM alpine:latest
                        RUN echo "Hello from Jenkins"
                        CMD ["echo", "Build successful"]
                    '''

                    sh "docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Push to Nexus') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-docker',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh "echo ${DOCKER_PASS} | docker login ${DOCKER_REGISTRY} -u ${DOCKER_USER} --password-stdin"
                        sh "docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }
    }

    post {
        always {
            sh "docker logout ${DOCKER_REGISTRY} || true"
            cleanWs()
        }
    }
}
```

### 3. Run Build

- Click "Build Now"
- Check Console Output
- Verify image in Nexus: https://nexus.chocolandiadc.local → Browse → docker-hosted

## Example Pipelines by Language

### Java/Maven Project

```groovy
pipeline {
    agent any
    tools {
        jdk 'JDK17'
        maven 'Maven3'
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/myapp:${BUILD_NUMBER} .'
            }
        }
    }
}
```

### Node.js Project

```groovy
pipeline {
    agent any
    tools {
        nodejs 'NodeJS20'
    }
    stages {
        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/myapp:${BUILD_NUMBER} .'
            }
        }
    }
}
```

### Python Project

```groovy
pipeline {
    agent any
    stages {
        stage('Setup Python') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }
        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest
                '''
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/myapp:${BUILD_NUMBER} .'
            }
        }
    }
}
```

### Go Project

```groovy
pipeline {
    agent any
    tools {
        go 'Go1.22'
    }
    stages {
        stage('Build') {
            steps {
                sh 'go build -o app .'
            }
        }
        stage('Test') {
            steps {
                sh 'go test ./...'
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/myapp:${BUILD_NUMBER} .'
            }
        }
    }
}
```

## Monitoring

### Prometheus Metrics

Jenkins exposes metrics at `/prometheus`. ServiceMonitor is configured to scrape automatically.

### Grafana Dashboard

Import Jenkins dashboard (ID: 9964) from Grafana.com:

1. Grafana → Dashboards → Import
2. Enter ID: 9964
3. Select Prometheus data source
4. Import

### Alerts

Configured alerts:
- `JenkinsDown`: Jenkins not responding > 5 min
- `JenkinsBuildFailed`: Build failure detected
- `JenkinsQueueStuck`: Jobs stuck > 10 min

Notifications sent to ntfy topic: `homelab-alerts`

## Troubleshooting

### Jenkins Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n jenkins jenkins-0

# Check logs
kubectl logs -n jenkins jenkins-0 -c jenkins
kubectl logs -n jenkins jenkins-0 -c dind
```

### Docker Build Failing

```bash
# Check DinD sidecar
kubectl exec -n jenkins jenkins-0 -c dind -- docker info

# Check Docker socket
kubectl exec -n jenkins jenkins-0 -c jenkins -- ls -la /var/run/docker.sock
```

### Cannot Push to Nexus

1. Verify credentials exist:
   ```bash
   kubectl get secret -n jenkins nexus-docker-credentials
   ```

2. Test Nexus connectivity:
   ```bash
   kubectl exec -n jenkins jenkins-0 -c jenkins -- curl -I https://docker.nexus.chocolandiadc.local/v2/
   ```

3. Check Nexus docker-hosted repository is configured

### Plugins Not Loading

1. Check plugin installation logs in Jenkins startup
2. Manually install via Manage Jenkins → Manage Plugins
3. Restart Jenkins pod: `kubectl delete pod -n jenkins jenkins-0`

## Cleanup

To remove Jenkins:

```bash
tofu destroy -target=module.jenkins

# Or manually
kubectl delete namespace jenkins
```

**Warning**: This will delete all Jenkins data including job configurations and build history.
