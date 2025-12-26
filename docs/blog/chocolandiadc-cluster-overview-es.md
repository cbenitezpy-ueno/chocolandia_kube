# ChocolandiaDC: Mi Homelab Kubernetes de Nivel Empresarial

> Un recorrido por la infraestructura de mi homelab: desde mini PCs hasta un cluster Kubernetes completamente automatizado con GitOps, monitoreo y acceso remoto seguro.

## Introducción

Hace unos meses decidí crear un homelab "serio" - no solo para jugar con tecnología, sino para aprender patrones de infraestructura empresarial en un ambiente controlado. El resultado es **ChocolandiaDC**: un cluster K3s de 4 nodos corriendo sobre mini PCs, completamente gestionado con Infrastructure as Code.

Este artículo no es un tutorial paso a paso, sino una descripción de qué tiene el cluster, cómo está organizado, y por qué elegí cada componente. Si querés replicar algo específico, en el repositorio están todos los specs y documentación técnica.

## La Infraestructura Física

### Los Nodos

El cluster corre sobre 4 mini PCs conectados a un router Eero mesh:

| Nodo | Rol | IP | Descripción |
|------|-----|-----|-------------|
| master1 | Control Plane (primario) | 192.168.4.x | Inicia el cluster con etcd embebido |
| nodo03 | Control Plane (secundario) | 192.168.4.x | HA para el control plane |
| nodo1 | Worker | 192.168.4.x | Ejecuta workloads |
| nodo04 | Worker | 192.168.4.x | Ejecuta workloads |

La configuración de alta disponibilidad (2 control planes + 2 workers) garantiza que el cluster sobreviva a la caída de cualquier nodo individual.

### Por qué K3s y no K8s vanilla

Elegí **K3s v1.28** por varias razones prácticas:

- **Footprint reducido**: Los mini PCs tienen recursos limitados; K3s consume menos memoria
- **Instalación simplificada**: Un binario único vs múltiples componentes
- **etcd embebido**: No necesito gestionar un cluster etcd separado
- **Certificados automáticos**: K3s genera y rota certificados internos
- **OIDC integrado**: Autenticación con Google OAuth out-of-the-box

## Todo Está Terraformado

La premisa principal del proyecto: **nada se configura manualmente**. Todo el cluster se despliega y gestiona con OpenTofu (fork open source de Terraform).

### Estructura del Repositorio

```
chocolandia_kube/
├── terraform/
│   ├── modules/           # Componentes reutilizables
│   │   ├── k3s-node/      # Provisioning de nodos K3s
│   │   ├── cloudflare-tunnel/
│   │   ├── traefik/
│   │   ├── cert-manager/
│   │   ├── argocd/
│   │   ├── homepage/
│   │   ├── postgresql-cluster/
│   │   ├── redis-shared/
│   │   └── ... (20+ módulos)
│   └── environments/
│       └── chocolandiadc-mvp/  # Configuración del cluster
├── specs/                 # Documentación por feature
├── kubernetes/            # Manifiestos para GitOps
└── scripts/               # Automatización y validación
```

Cada servicio tiene su propio módulo Terraform con variables configurables. Por ejemplo, para desplegar Traefik:

```hcl
module "traefik" {
  source = "../../modules/traefik"
  
  replicas        = 2
  loadbalancer_ip = "192.168.4.202"
  chart_version   = "30.0.2"  # Traefik v3.2.0
}
```

### Despliegue Completo

Un solo comando despliega todo el cluster desde cero:

```bash
cd terraform/environments/chocolandiadc-mvp
tofu init
tofu apply
```

Esto provisiona los 4 nodos K3s, instala todos los componentes base, configura el networking con MetalLB, y deja el cluster listo para recibir workloads.

## Acceso desde Afuera: Cloudflare Zero Trust

Uno de los mayores desafíos de un homelab es el acceso remoto seguro. No quería abrir puertos en mi router ni exponer servicios directamente a internet.

### La Solución: Cloudflare Tunnel

El cluster usa **Cloudflare Zero Trust** para exponer servicios de forma segura:

- **Sin puertos abiertos**: El tunnel sale desde dentro del cluster hacia Cloudflare
- **Autenticación con Google OAuth**: Solo emails autorizados pueden acceder
- **TLS automático**: Cloudflare maneja los certificados públicos
- **WAF incluido**: Protección contra ataques comunes

Los servicios expuestos a internet (todos en el dominio chocolandiadc.com):

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Grafana | grafana.chocolandiadc.com | Dashboards de monitoreo |
| ArgoCD | argocd.chocolandiadc.com | GitOps deployments |
| Homepage | home.chocolandiadc.com | Dashboard central |
| Pi-hole | pihole.chocolandiadc.com | Admin del DNS |
| Headlamp | headlamp.chocolandiadc.com | UI de Kubernetes |
| Longhorn | longhorn.chocolandiadc.com | UI de storage |
| MinIO | minio.chocolandiadc.com | Consola S3 |
| Ntfy | ntfy.chocolandiadc.com | Notificaciones (público) |

El tunnel corre como un Deployment de Kubernetes con replicas para HA. La configuración de ingress es declarativa:

```hcl
ingress_rules = [
  {
    hostname = "grafana.chocolandiadc.com"
    service  = "http://grafana.monitoring.svc.cluster.local:3000"
  },
  # ... más servicios
]
```

### Cloudflare Access

Cada servicio (excepto ntfy que es público) está protegido con Cloudflare Access:

1. Usuario intenta acceder a `grafana.chocolandiadc.com`
2. Cloudflare redirige a login con Google
3. Si el email está en la lista autorizada → acceso permitido
4. Si no → bloqueado

La lista de emails autorizados se gestiona en Terraform, facilitando agregar o remover accesos.

## Monitoreo: Prometheus + Grafana

No hay cluster serio sin observabilidad. ChocolandiaDC usa el stack estándar de la industria.

### Componentes del Stack

- **Prometheus**: Recolección de métricas (15 días de retención)
- **Grafana**: Visualización con dashboards
- **Alertmanager**: Gestión de alertas
- **Node Exporter**: Métricas de los nodos físicos
- **Kube State Metrics**: Métricas de objetos Kubernetes

Todo desplegado via el Helm chart `kube-prometheus-stack`.

### Dashboards Incluidos

El cluster viene con dashboards pre-configurados:

- **K3s Cluster Overview**: Estado general del cluster
- **Node Exporter Full**: Métricas detalladas por nodo (CPU, RAM, disco, red)
- **Kubernetes Pods**: Estado de pods por namespace
- **Traefik**: Requests, latencias, errores del ingress
- **PostgreSQL**: Métricas de la base de datos
- **Redis**: Performance del cache
- **Longhorn**: Estado del storage distribuido
- **Homelab Overview**: Dashboard custom con métricas clave

### Alertas con Ntfy

Las alertas no sirven si no te enterás. Configuré Alertmanager para enviar notificaciones a **Ntfy** (servicio self-hosted de push notifications):

```yaml
receivers:
  - name: "ntfy-homelab"
    webhook_configs:
      - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
        send_resolved: true
```

Alertas configuradas:
- Nodo caído
- Pod en CrashLoop
- Uso de disco > 80%
- Certificados próximos a expirar
- PostgreSQL replication lag
- Redis desconectado

Llegan a mi teléfono en segundos.

## GitOps con ArgoCD

Después del setup inicial con Terraform, los deployments de aplicaciones se manejan con **ArgoCD**. El flujo:

1. Cambio en el repositorio (PR → merge a main)
2. ArgoCD detecta el cambio (polling cada 3 minutos)
3. Sincroniza automáticamente los manifiestos al cluster
4. Estado visible en la UI de ArgoCD

### App of Apps Pattern

El repositorio tiene un directorio `kubernetes/argocd/applications/` donde cada YAML define una aplicación. ArgoCD lee este directorio y despliega todas las apps automáticamente.

Por ejemplo, agregar un nuevo servicio es crear un archivo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mi-nueva-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/cbenitezpy-ueno/chocolandia_kube
    path: kubernetes/mi-nueva-app
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: mi-nueva-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Aplicaciones Desplegadas

### Infraestructura Base

| Componente | Descripción |
|------------|-------------|
| **MetalLB** | LoadBalancer para bare-metal (pool: 192.168.4.200-210) |
| **Traefik** | Ingress controller v3.2 con TLS |
| **cert-manager** | Certificados automáticos (Let's Encrypt + CA local) |
| **Longhorn** | Storage distribuido con replicación |
| **MinIO** | Object storage compatible con S3 |

### Herramientas de Desarrollo

| Componente | Descripción |
|------------|-------------|
| **Nexus** | Registry para Docker, Helm, NPM, Maven |
| **LocalStack** | AWS local (S3, SQS, SNS, DynamoDB) |
| **GitHub Actions Runner** | CI/CD self-hosted |

### Bases de Datos

| Componente | Descripción |
|------------|-------------|
| **PostgreSQL** | Cluster HA con CloudNativePG |
| **Redis** | Cache compartido con replicación |

### Aplicaciones

| Componente | Descripción |
|------------|-------------|
| **Homepage** | Dashboard unificado de servicios |
| **Pi-hole** | DNS con bloqueo de ads |
| **Home Assistant** | Automatización del hogar |
| **Govee2MQTT** | Integración de luces Govee |
| **Netdata** | Monitoreo de hardware en tiempo real |
| **Ntfy** | Servidor de notificaciones push |
| **Beersystem** | Aplicación propia (demo) |

## Networking Interno

### MetalLB IP Pool

Para servicios que necesitan IPs fijas (DNS, database, etc.), uso MetalLB en modo L2:

| IP | Servicio | Puerto |
|----|----------|--------|
| 192.168.4.200 | PostgreSQL Primary | 5432 |
| 192.168.4.201 | Pi-hole DNS | 53 |
| 192.168.4.202 | Traefik | 80, 443 |
| 192.168.4.203 | Redis | 6379 |

### CA Local para .local

Los servicios internos (como Nexus) usan dominios `.local` que no pueden tener certificados de Let's Encrypt. Para esto, cert-manager gestiona una CA local:

- `docker.nexus.chocolandiadc.local` → Certificado firmado por CA local
- `nexus.chocolandiadc.local` → Certificado firmado por CA local

Las máquinas de desarrollo tienen la CA instalada para confiar en estos certificados.

## Documentación Viva

Cada feature tiene su directorio en `specs/` con documentación estructurada:

```
specs/004-cloudflare-zerotrust/
├── spec.md          # Requerimientos y user stories
├── quickstart.md    # Guía rápida de deployment
├── plan.md          # Plan de implementación
├── tasks.md         # Breakdown de tareas
├── research.md      # Investigación técnica
└── data-model.md    # Diagrama de datos
```

Esta documentación se sincroniza automáticamente al GitHub Wiki via GitHub Actions. Así siempre está actualizada y versionada junto con el código.

## Conclusiones

Después de varios meses construyendo ChocolandiaDC, algunos aprendizajes:

1. **Infrastructure as Code es indispensable**: Poder destruir y recrear todo el cluster desde cero en minutos es invaluable para experimentar
2. **GitOps simplifica operaciones**: Después del setup inicial, todo cambio es un commit; no más `kubectl apply` manuales
3. **El monitoreo desde el día 1**: Agregar observabilidad después es mucho más difícil; mejor empezar con el stack completo
4. **Cloudflare Zero Trust es increíble**: Acceso remoto seguro sin VPN ni puertos abiertos, y gratis para uso personal
5. **Documentar mientras construís**: Escribir specs antes de implementar ayuda a pensar mejor las soluciones

El cluster sigue evolucionando. Próximos pasos: backup automatizado a S3, más integraciones de Home Assistant, y quizás migrar a Talos Linux.

Todo el código está en [GitHub](https://github.com/cbenitezpy-ueno/chocolandia_kube) si querés ver los detalles o usarlo como referencia para tu propio homelab.

---

*¿Tenés preguntas sobre algún componente específico? Dejame un comentario y profundizo en ese tema.*
