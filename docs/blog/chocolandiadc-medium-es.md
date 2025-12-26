# ChocolandiaDC: Mi Homelab Kubernetes de Nivel Empresarial

*Un recorrido por la infraestructura de mi homelab: desde mini PCs hasta un cluster Kubernetes completamente automatizado con GitOps, monitoreo y acceso remoto seguro.*

---

## Introducción

Hace unos meses decidí crear un homelab "serio" — no solo para jugar con tecnología, sino para aprender patrones de infraestructura empresarial en un ambiente controlado. El resultado es **ChocolandiaDC**: un cluster K3s de 4 nodos corriendo sobre mini PCs, completamente gestionado con Infrastructure as Code.

Este artículo no es un tutorial paso a paso, sino una descripción de qué tiene el cluster, cómo está organizado, y por qué elegí cada componente. Si querés replicar algo específico, en el repositorio están todos los specs y documentación técnica.

---

## La Infraestructura Física

### Los Nodos

El cluster corre sobre 4 mini PCs conectados a un router Eero mesh:

- **master1** (Control Plane primario) — Inicia el cluster con etcd embebido
- **nodo03** (Control Plane secundario) — HA para el control plane
- **nodo1** (Worker) — Ejecuta workloads
- **nodo04** (Worker) — Ejecuta workloads

La configuración de alta disponibilidad (2 control planes + 2 workers) garantiza que el cluster sobreviva a la caída de cualquier nodo individual.

### Por qué K3s y no K8s vanilla

Elegí **K3s v1.28** por varias razones prácticas:

- **Footprint reducido**: Los mini PCs tienen recursos limitados; K3s consume menos memoria
- **Instalación simplificada**: Un binario único vs múltiples componentes
- **etcd embebido**: No necesito gestionar un cluster etcd separado
- **Certificados automáticos**: K3s genera y rota certificados internos
- **OIDC integrado**: Autenticación con Google OAuth out-of-the-box

---

## Todo Está Terraformado

La premisa principal del proyecto: **nada se configura manualmente**. Todo el cluster se despliega y gestiona con OpenTofu (fork open source de Terraform).

### Estructura del Repositorio

```
chocolandia_kube/
├── terraform/
│   ├── modules/           # 20+ componentes reutilizables
│   └── environments/
│       └── chocolandiadc-mvp/
├── specs/                 # Documentación por feature
├── kubernetes/            # Manifiestos para GitOps
└── scripts/               # Automatización
```

Cada servicio tiene su propio módulo Terraform. Por ejemplo, para desplegar Traefik:

```hcl
module "traefik" {
  source = "../../modules/traefik"
  
  replicas        = 2
  loadbalancer_ip = "192.168.4.202"
  chart_version   = "30.0.2"
}
```

### Despliegue Completo

Un solo comando despliega todo el cluster desde cero:

```bash
cd terraform/environments/chocolandiadc-mvp
tofu init && tofu apply
```

Esto provisiona los 4 nodos K3s, instala todos los componentes base, configura el networking con MetalLB, y deja el cluster listo para recibir workloads.

---

## Acceso desde Afuera: Cloudflare Zero Trust

Uno de los mayores desafíos de un homelab es el acceso remoto seguro. No quería abrir puertos en mi router ni exponer servicios directamente a internet.

### La Solución: Cloudflare Tunnel

El cluster usa **Cloudflare Zero Trust** para exponer servicios de forma segura:

- **Sin puertos abiertos**: El tunnel sale desde dentro del cluster hacia Cloudflare
- **Autenticación con Google OAuth**: Solo emails autorizados pueden acceder
- **TLS automático**: Cloudflare maneja los certificados públicos
- **WAF incluido**: Protección contra ataques comunes

### Servicios Expuestos

Todos en el dominio `chocolandiadc.com`:

- **Grafana** → Dashboards de monitoreo
- **ArgoCD** → GitOps deployments
- **Homepage** → Dashboard central
- **Pi-hole** → Admin del DNS
- **Headlamp** → UI de Kubernetes
- **Longhorn** → UI de storage
- **MinIO** → Consola S3
- **Ntfy** → Notificaciones (único servicio público)

El tunnel corre como un Deployment de Kubernetes con réplicas para HA.

### Cloudflare Access

Cada servicio (excepto ntfy) está protegido:

1. Usuario intenta acceder a `grafana.chocolandiadc.com`
2. Cloudflare redirige a login con Google
3. Si el email está autorizado → acceso permitido
4. Si no → bloqueado

La lista de emails autorizados se gestiona en Terraform.

---

## Monitoreo: Prometheus + Grafana

No hay cluster serio sin observabilidad. ChocolandiaDC usa el stack estándar de la industria.

### Componentes del Stack

- **Prometheus** — Recolección de métricas (15 días de retención)
- **Grafana** — Visualización con dashboards
- **Alertmanager** — Gestión de alertas
- **Node Exporter** — Métricas de los nodos físicos
- **Kube State Metrics** — Métricas de objetos Kubernetes

Todo desplegado via el Helm chart `kube-prometheus-stack`.

### Dashboards Pre-configurados

- K3s Cluster Overview
- Node Exporter Full (CPU, RAM, disco, red por nodo)
- Kubernetes Pods por namespace
- Traefik (requests, latencias, errores)
- PostgreSQL y Redis
- Longhorn Storage
- Homelab Overview (dashboard custom)

### Alertas con Ntfy

Las alertas no sirven si no te enterás. Configuré Alertmanager para enviar notificaciones push a **Ntfy**:

```yaml
receivers:
  - name: "ntfy-homelab"
    webhook_configs:
      - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
```

Alertas configuradas: nodo caído, pod en CrashLoop, disco > 80%, certificados por expirar, PostgreSQL replication lag, Redis desconectado.

Llegan a mi teléfono en segundos.

---

## GitOps con ArgoCD

Después del setup inicial con Terraform, los deployments de aplicaciones se manejan con **ArgoCD**.

### El Flujo

1. Cambio en el repositorio (PR → merge a main)
2. ArgoCD detecta el cambio (polling cada 3 minutos)
3. Sincroniza automáticamente los manifiestos al cluster
4. Estado visible en la UI de ArgoCD

### App of Apps Pattern

El repositorio tiene un directorio `kubernetes/argocd/applications/` donde cada YAML define una aplicación. ArgoCD lee este directorio y despliega todo automáticamente.

Agregar un nuevo servicio es crear un archivo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mi-nueva-app
spec:
  source:
    repoURL: https://github.com/user/repo
    path: kubernetes/mi-nueva-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Aplicaciones Desplegadas

### Infraestructura Base

- **MetalLB** — LoadBalancer para bare-metal
- **Traefik** — Ingress controller v3.2 con TLS
- **cert-manager** — Certificados automáticos (Let's Encrypt + CA local)
- **Longhorn** — Storage distribuido con replicación
- **MinIO** — Object storage S3-compatible

### Herramientas de Desarrollo

- **Nexus** — Registry para Docker, Helm, NPM, Maven
- **LocalStack** — AWS local (S3, SQS, SNS, DynamoDB)
- **GitHub Actions Runner** — CI/CD self-hosted

### Bases de Datos

- **PostgreSQL** — Cluster HA con CloudNativePG
- **Redis** — Cache compartido con replicación

### Aplicaciones

- **Homepage** — Dashboard unificado de servicios
- **Pi-hole** — DNS con bloqueo de ads
- **Home Assistant** — Automatización del hogar
- **Govee2MQTT** — Integración de luces Govee
- **Netdata** — Monitoreo de hardware en tiempo real
- **Ntfy** — Servidor de notificaciones push

---

## Networking Interno

### MetalLB IP Pool

Para servicios que necesitan IPs fijas, uso MetalLB en modo L2:

- **192.168.4.200** → PostgreSQL Primary (5432)
- **192.168.4.201** → Pi-hole DNS (53)
- **192.168.4.202** → Traefik (80, 443)
- **192.168.4.203** → Redis (6379)

### CA Local para dominios .local

Los servicios internos (como Nexus) usan dominios `.local` que no pueden tener certificados de Let's Encrypt. Para esto, cert-manager gestiona una CA local que firma certificados para `*.chocolandiadc.local`.

Las máquinas de desarrollo tienen la CA instalada para confiar en estos certificados.

---

## Documentación Viva

Cada feature tiene su directorio en `specs/` con documentación estructurada:

```
specs/004-cloudflare-zerotrust/
├── spec.md          # Requerimientos
├── quickstart.md    # Guía de deployment
├── plan.md          # Plan de implementación
├── tasks.md         # Breakdown de tareas
└── research.md      # Investigación técnica
```

Esta documentación se sincroniza automáticamente al GitHub Wiki via GitHub Actions. Siempre actualizada y versionada junto con el código.

---

## Lo Que Aprendí

Después de varios meses construyendo ChocolandiaDC:

**1. Infrastructure as Code es indispensable**
Poder destruir y recrear todo el cluster desde cero en minutos es invaluable para experimentar.

**2. GitOps simplifica operaciones**
Después del setup inicial, todo cambio es un commit. No más `kubectl apply` manuales.

**3. El monitoreo desde el día 1**
Agregar observabilidad después es mucho más difícil. Mejor empezar con el stack completo.

**4. Cloudflare Zero Trust es increíble**
Acceso remoto seguro sin VPN ni puertos abiertos, y gratis para uso personal.

**5. Documentar mientras construís**
Escribir specs antes de implementar ayuda a pensar mejor las soluciones.

---

## Próximos Pasos

El cluster sigue evolucionando:

- Backup automatizado a S3
- Más integraciones de Home Assistant
- Posible migración a Talos Linux

Todo el código está en GitHub si querés ver los detalles o usarlo como referencia para tu propio homelab.

---

*¿Tenés preguntas sobre algún componente específico? Dejame un comentario y profundizo en ese tema.*
