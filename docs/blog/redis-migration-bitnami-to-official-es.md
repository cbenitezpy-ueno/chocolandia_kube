# Migrando Redis de Bitnami a Imágenes Oficiales: Lecciones de un Cambio de Licencia Inesperado

*Diciembre 2025*

## El Problema: Cuando tu Infraestructura Deja de Funcionar

Todo comenzó durante una auditoría rutinaria de versiones en mi homelab. Tenía un cluster K3s corriendo varios servicios, entre ellos Redis usando el chart de Bitnami. Al intentar actualizar de la versión 23.2.12 a la 24.1.0, me encontré con este error críptico:

```
Error: failed to solve: bitnami/redis:8.4.0-debian-12-r0:
invalid_reference: invalid tag
```

Mi primera reacción fue pensar que era un problema temporal de Docker Hub. Pero después de investigar, descubrí algo más preocupante.

## ¿Qué Pasó con Bitnami?

En agosto de 2025, Bitnami (propiedad de VMware/Broadcom) realizó cambios significativos en su modelo de licenciamiento y distribución de imágenes. Las consecuencias:

1. **Las imágenes nuevas ya no están disponibles en Docker Hub** - Los charts de Helm siguen publicándose, pero las imágenes Docker que referencian simplemente no existen en los registros públicos.

2. **Las versiones antiguas siguen funcionando** - Si ya tenías una versión desplegada (como mi 23.2.12), sigue funcionando. Pero no puedes actualizar.

3. **Sin comunicación clara** - No hubo un anuncio prominente. Muchos nos enteramos cuando nuestros pipelines empezaron a fallar.

Esto me dejó en una situación incómoda: podía mantener mi Redis en una versión cada vez más antigua, o buscar alternativas.

## Evaluando Alternativas

Ejecuté una búsqueda de charts de Redis disponibles:

```bash
helm search hub redis --max-col-width 80
```

Encontré varias opciones:

| Chart | Descripción | Pros | Contras |
|-------|-------------|------|---------|
| **bitnami/redis** | El que ya usaba | Familiar, bien documentado | Imágenes no disponibles |
| **groundhog2k/redis** | Usa imágenes oficiales | Imágenes oficiales de Docker | Menos conocido |
| **ot-container-kit/redis** | Operador con HA | Sentinel integrado | Más complejo |
| **community-charts/redis** | Fork comunitario | Compatible con Bitnami | Mantenimiento incierto |

## Por Qué Elegí groundhog2k/redis

Después de analizar las opciones, me decidí por **groundhog2k/redis** por estas razones:

### 1. Usa Imágenes Oficiales de Docker
```yaml
image:
  registry: docker.io
  repository: redis  # La imagen oficial, no bitnami/redis
  tag: 8.4.0-alpine
```

Esto significa que dependo de las imágenes mantenidas por el proyecto Redis oficial, no de un tercero que puede cambiar sus políticas de licencia.

### 2. Configuración Similar
La estructura de valores es diferente a Bitnami, pero cubre los mismos casos de uso: persistencia, métricas Prometheus, autenticación, HA con Sentinel.

### 3. Mantenimiento Activo
El repositorio de groundhog2k tiene actualizaciones regulares y sigue las versiones de Redis de cerca.

### 4. Alpine por Defecto
Las imágenes usan Alpine Linux, resultando en contenedores más pequeños (~30MB vs ~200MB de Bitnami).

## El Proceso de Migración

### Paso 1: Crear el Nuevo Módulo de Terraform

Creé un nuevo módulo en `terraform/modules/redis-groundhog2k/` con tres archivos principales:

**variables.tf** - Configuración parametrizable:
```hcl
variable "release_name" {
  description = "Helm release name for Redis"
  type        = string
  default     = "redis"
}

variable "redis_image_tag" {
  description = "Redis Docker image tag (official redis image)"
  type        = string
  default     = "8.4.0-alpine"
}

variable "loadbalancer_ip" {
  description = "LoadBalancer IP for external access (MetalLB)"
  type        = string
  default     = ""
}
# ... más variables
```

**main.tf** - El release de Helm con la configuración:
```hcl
resource "helm_release" "redis" {
  name       = var.release_name
  repository = "https://groundhog2k.github.io/helm-charts/"
  chart      = "redis"
  version    = "2.2.1"
  namespace  = kubernetes_namespace.redis.metadata[0].name

  values = [
    yamlencode({
      image = {
        registry   = "docker.io"
        repository = "redis"
        tag        = var.redis_image_tag
      }
      # ... configuración completa
    })
  ]
}
```

### Paso 2: Migrar el Estado de Terraform

Este fue el paso más delicado. Necesitaba mover los recursos existentes al nuevo módulo sin destruir datos:

```bash
# Migrar el namespace
tofu state mv 'module.redis_shared.kubernetes_namespace.redis' \
              'module.redis.kubernetes_namespace.redis'

# Migrar el password (para no perder la contraseña existente)
tofu state mv 'module.redis_shared.random_password.redis_password' \
              'module.redis.random_password.redis_password'

# Migrar los secrets
tofu state mv 'module.redis_shared.kubernetes_secret.redis_credentials' \
              'module.redis.kubernetes_secret.redis_credentials'

# El release de Helm lo eliminamos del estado (se reinstalará)
tofu state rm 'module.redis_shared.helm_release.redis'
```

### Paso 3: Desinstalar el Release Antiguo

```bash
# Desinstalar Bitnami Redis
helm uninstall redis-shared -n redis

# Eliminar PVCs antiguos (los datos se pierden, pero Redis es cache)
kubectl delete pvc -n redis -l app.kubernetes.io/instance=redis-shared
```

### Paso 4: Aplicar el Nuevo Módulo

```bash
tofu apply -target=module.redis
```

### Paso 5: Resolver el Problema de MetalLB

Aquí me encontré con otro problema. Mi servicio LoadBalancer quedó en estado `<pending>`. El error en los eventos de MetalLB:

```
service can not have both metallb.io/loadBalancerIPs and svc.Spec.LoadBalancerIP
```

MetalLB 0.15+ ya no permite especificar el IP tanto en la anotación como en `spec.loadBalancerIP`. La solución fue usar **solo la anotación**:

```hcl
resource "kubernetes_service" "redis_external" {
  metadata {
    annotations = {
      # MetalLB 0.13+ usa metallb.io (no metallb.universe.tf)
      "metallb.io/address-pool"    = var.metallb_ip_pool
      "metallb.io/loadBalancerIPs" = var.loadbalancer_ip
    }
  }

  spec {
    type = "LoadBalancer"
    # NO incluir load_balancer_ip aquí
    external_traffic_policy = "Local"
  }
}
```

También actualicé las anotaciones de `metallb.universe.tf/*` a `metallb.io/*` ya que las anteriores están deprecadas.

## Verificación

Después de aplicar los cambios, verifiqué que todo funcionara:

```bash
# Verificar el servicio
kubectl get svc -n redis
# NAME                    TYPE           EXTERNAL-IP     PORT(S)
# redis-shared-external   LoadBalancer   192.168.4.203   6379/TCP

# Test de conectividad
kubectl run redis-test --rm -it --image=redis:8.4-alpine -- \
  redis-cli -h 192.168.4.203 -a "$REDIS_PASSWORD" PING
# PONG

# Verificar la versión
kubectl run redis-test --rm -it --image=redis:8.4-alpine -- \
  redis-cli -h 192.168.4.203 -a "$REDIS_PASSWORD" INFO server | grep redis_version
# redis_version:8.4.0
```

## Resultado Final

| Aspecto | Antes | Después |
|---------|-------|---------|
| Chart | bitnami/redis 23.2.12 | groundhog2k/redis 2.2.1 |
| Imagen | bitnami/redis:7.x | redis:8.4.0-alpine |
| Tamaño imagen | ~200MB | ~30MB |
| Dependencia | Bitnami/VMware | Proyecto Redis oficial |
| Versión Redis | 7.2.x | 8.4.0 |

## Lecciones Aprendidas

1. **No dependas de un solo proveedor de imágenes** - Siempre que sea posible, usa imágenes oficiales de los proyectos upstream.

2. **Terraform state mv es tu amigo** - Migrar infraestructura no significa destruir y recrear. Puedes mover recursos entre módulos preservando el estado.

3. **Mantén tus anotaciones actualizadas** - Las APIs de Kubernetes y sus extensiones evolucionan. `metallb.universe.tf` está deprecado en favor de `metallb.io`.

4. **Redis es cache, no base de datos** - Perder los datos de Redis durante la migración fue aceptable porque lo uso como cache. Si fuera almacenamiento persistente crítico, habría necesitado una estrategia de migración de datos.

5. **Documenta tus decisiones** - Este artículo existe porque el próximo que enfrente este problema (posiblemente yo en 6 meses) tendrá una guía clara.

## Recursos

- [groundhog2k/redis Chart](https://github.com/groundhog2k/helm-charts/tree/master/charts/redis)
- [Imágenes oficiales de Redis en Docker Hub](https://hub.docker.com/_/redis)
- [MetalLB Configuration](https://metallb.universe.tf/configuration/)
- [OpenTofu State Management](https://opentofu.org/docs/cli/commands/state/)

---

*Este artículo documenta una migración real realizada en el cluster K3s de ChocolandiaDC. El código completo está disponible en el repositorio del proyecto.*
