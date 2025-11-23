# Registry API Contract

**Feature**: 015-dev-tools-local
**Service**: Docker Registry v2
**Base URL**: `https://registry.homelab.local`

## Authentication

All endpoints require Basic Authentication:
```
Authorization: Basic base64(username:password)
```

## Endpoints

### Health Check

```
GET /v2/
```

**Response** (200 OK):
```json
{}
```

**Response** (401 Unauthorized):
```json
{
  "errors": [{
    "code": "UNAUTHORIZED",
    "message": "authentication required"
  }]
}
```

---

### List Repositories

```
GET /v2/_catalog
```

**Response** (200 OK):
```json
{
  "repositories": [
    "myapp",
    "nginx-custom",
    "beersystem"
  ]
}
```

---

### List Tags for Repository

```
GET /v2/{name}/tags/list
```

**Parameters**:
- `name` (path): Repository name (e.g., `myapp`)

**Response** (200 OK):
```json
{
  "name": "myapp",
  "tags": [
    "latest",
    "v1.0.0",
    "v1.1.0"
  ]
}
```

**Response** (404 Not Found):
```json
{
  "errors": [{
    "code": "NAME_UNKNOWN",
    "message": "repository name not known to registry"
  }]
}
```

---

### Get Manifest

```
GET /v2/{name}/manifests/{reference}
```

**Parameters**:
- `name` (path): Repository name
- `reference` (path): Tag or digest

**Headers**:
```
Accept: application/vnd.docker.distribution.manifest.v2+json
```

**Response** (200 OK):
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "config": {
    "mediaType": "application/vnd.docker.container.image.v1+json",
    "size": 7023,
    "digest": "sha256:abc123..."
  },
  "layers": [
    {
      "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
      "size": 32654,
      "digest": "sha256:def456..."
    }
  ]
}
```

---

### Push Manifest

```
PUT /v2/{name}/manifests/{reference}
```

**Headers**:
```
Content-Type: application/vnd.docker.distribution.manifest.v2+json
```

**Response** (201 Created):
```
Location: /v2/myapp/manifests/sha256:abc123...
Docker-Content-Digest: sha256:abc123...
```

---

### Delete Manifest

```
DELETE /v2/{name}/manifests/{reference}
```

**Response** (202 Accepted):
```
(empty body)
```

---

## Docker CLI Usage

### Login

```bash
docker login registry.homelab.local
# Enter username and password when prompted
```

### Push Image

```bash
# Tag image for local registry
docker tag myapp:latest registry.homelab.local/myapp:v1.0.0

# Push to registry
docker push registry.homelab.local/myapp:v1.0.0
```

### Pull Image

```bash
docker pull registry.homelab.local/myapp:v1.0.0
```

---

## Kubernetes Usage

### ImagePullSecret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

### Pod with Local Registry Image

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: registry.homelab.local/myapp:v1.0.0
  imagePullSecrets:
  - name: registry-credentials
```
