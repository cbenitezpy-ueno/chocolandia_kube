# Research: Cluster Version Audit & Update Plan

**Branch**: `020-cluster-version-audit` | **Date**: 2025-12-23

## Research Summary

Este documento consolida la investigación sobre rutas de actualización, breaking changes, y mejores prácticas para cada componente del cluster.

---

## 1. K3s Upgrade Path (v1.28.3 → v1.33.7)

### Decision
Actualizar K3s de forma incremental: v1.28 → v1.30 → v1.32 → v1.33

### Rationale
- K3s soporta saltos de hasta 2 versiones menores de forma segura
- Saltar más versiones aumenta riesgo de incompatibilidades API
- Cada salto permite validar estabilidad antes de continuar

### Breaking Changes Identificados

| Versión | Breaking Change | Acción Requerida |
|---------|-----------------|------------------|
| v1.31 → v1.32 | Traefik v2 → v3 | Revisar configuración de middlewares (ya tenemos Traefik v3, no aplica) |
| v1.31+ | Containerd 2.0 | Si hay templates custom de containerd, migrar a config-v3.toml.tmpl |
| v1.32 | AuthorizeNodeWithSelectors | Puede requerir `--kube-apiserver-arg=feature-gates=AuthorizeNodeWithSelectors=false` durante transición |
| v1.32 | Kine v0.13.0 | Mejora performance con PostgreSQL (positivo para nosotros) |
| v1.33 | API Deprecations | Revisar Kubernetes API deprecation guide |

### Alternatives Considered
1. **Actualizar directamente a v1.33**: Rechazado - demasiados cambios acumulados, alto riesgo
2. **Usar system-upgrade-controller**: Considerado para futuro, pero primera actualización manual para aprender el proceso
3. **Quedarse en v1.28**: Rechazado - vulnerabilidades de seguridad conocidas

### Sources
- [K3s Upgrade Guide](https://docs.k3s.io/upgrades)
- [K3s v1.33 Release Notes](https://docs.k3s.io/release-notes/v1.33.X)
- [K3s v1.32 Release Notes](https://docs.k3s.io/release-notes/v1.32.X)

---

## 2. Longhorn Upgrade Path (v1.5.5 → v1.10.1)

### Decision
Actualizar Longhorn de forma incremental: v1.5 → v1.6 → v1.7 → v1.8 → v1.9 → v1.10

### Rationale
- **Longhorn NO soporta saltar versiones menores** - restricción hard del producto
- Cada versión incluye migraciones de schema que deben ejecutarse en orden
- Downgrade NO está soportado, cada upgrade es permanente

### Breaking Changes Identificados

| Versión | Breaking Change | Acción Requerida |
|---------|-----------------|------------------|
| v1.8 → v1.9 | Migración automática a v1beta2 | Verificar que todos los CRs migren correctamente |
| v1.9 → v1.10 | CRD v1beta1 removal | **MANUAL**: Migrar CRs a v1beta2 ANTES de actualizar |
| v1.10.0 | Bug en share-manager | Usar imagen `longhorn-manager:v1.10.0-hotfix-1` o v1.10.1 |
| Todos | No downgrade | Hacer backup de etcd antes de cada actualización |

### Critical Pre-Upgrade Steps para v1.10
```bash
# Verificar que no hay recursos v1beta1
kubectl get --raw="/apis/longhorn.io/v1beta1" || echo "v1beta1 not found (good)"

# Verificar health de volúmenes
kubectl -n longhorn-system get volumes.longhorn.io
```

### Alternatives Considered
1. **Saltar a v1.10 directamente**: Imposible - Longhorn bloquea este upgrade
2. **Quedarse en v1.5**: Rechazado - versión muy antigua con bugs conocidos
3. **Migrar a otro storage**: No evaluado, fuera de alcance

### Sources
- [Longhorn Upgrade Guide v1.10](https://longhorn.io/docs/1.10.0/deploy/upgrade/)
- [Longhorn Important Notes](https://longhorn.io/docs/1.10.1/important-notes/)
- [Issue #11886 - CRD Migration](https://github.com/longhorn/longhorn/issues/11886)

---

## 3. ArgoCD Upgrade (v2.9.0 → v3.2.2)

### Decision
Actualizar ArgoCD de v2.9 → v2.14 → v3.0 → v3.2

### Rationale
- ArgoCD v3.0 es un upgrade de bajo riesgo con breaking changes menores
- Necesario pasar por v2.14 primero como versión estable pre-v3
- v3.x tiene mejor rendimiento y nuevas características

### Breaking Changes Identificados

| Cambio | Impacto | Acción Requerida |
|--------|---------|------------------|
| Fine-Grained RBAC | Policies ya no aplican a sub-resources | Revisar RBAC policies, agregar `update/*` y `delete/*` si necesario |
| Logs RBAC | Enforcement obligatorio | Agregar `logs, get` a roles que necesiten ver logs |
| Resource Exclusions | Nuevos defaults | Revisar si afecta resources gestionados |
| Legacy Metrics Removed | `argocd_app_sync_status`, etc. | Actualizar dashboards de Grafana a usar `argocd_app_info` |
| Dex RBAC Subject | Cambio en claim usado | Verificar autenticación después de upgrade |
| Repos en argocd-cm | Deprecado | Migrar a Secrets/ConfigMaps separados |

### Upgrade Command
```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.2/manifests/install.yaml
```
**Nota**: `--server-side --force-conflicts` requerido por tamaño de CRDs

### Alternatives Considered
1. **Quedarse en v2.9**: Posible pero pierde soporte pronto
2. **FluxCD**: No evaluado, cambio de herramienta fuera de alcance

### Sources
- [ArgoCD v2.14 to 3.0 Upgrade Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/)
- [ArgoCD 3.0 Release Candidate Blog](https://blog.argoproj.io/argo-cd-v3-0-release-candidate-a0b933f4e58f)

---

## 4. kube-prometheus-stack Upgrade (55.5.0 → 80.6.0)

### Decision
Actualizar kube-prometheus-stack en pasos intermedios, con backup de dashboards

### Rationale
- 25 versiones de diferencia = muchos breaking changes
- Grafana dashboards custom pueden perderse si no se hace backup
- CRDs cambian entre versiones mayores

### Breaking Changes Esperados

| Área | Potencial Impacto | Mitigación |
|------|-------------------|------------|
| CRDs | Incompatibilidades de schema | Aplicar CRDs manualmente antes de upgrade |
| Labels | Campos inmutables cambiados | Delete + Apply en lugar de Apply directo |
| Grafana | Dashboards perdidos | Export JSON de todos los dashboards antes |
| kube-state-metrics | Métricas renombradas | Actualizar queries de Prometheus |
| node-exporter | Cambios en metrics | Verificar alertas existentes |

### Pre-Upgrade Steps
```bash
# Backup de dashboards de Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
# Exportar dashboards via API o UI

# Backup de CRDs
kubectl get crd | grep -E "prometheus|alertmanager|servicemonitor" | \
  xargs -I{} kubectl get crd {} -o yaml > crds-backup.yaml
```

### Alternatives Considered
1. **Actualizar de golpe**: Alto riesgo de pérdida de datos
2. **Reinstalar desde cero**: Más limpio pero pierde historial de métricas
3. **Mantener versión actual**: Rechazado - muy desactualizado

### Sources
- [kube-prometheus-stack Chart](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [UPGRADE.md](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/UPGRADE.md)

---

## 5. Ubuntu Security Patches

### Decision
Aplicar `apt upgrade` con parches de seguridad, mantener kernel 6.8.x LTS

### Rationale
- Ubuntu 24.04.3 ya es la última point release
- Parches de diciembre 2025 corrigen 70+ CVEs
- No hay necesidad de HWE kernel sin requerimientos de hardware específicos

### CVEs Críticos Corregidos
- CVE-2025-38666, CVE-2025-37958, CVE-2025-40018 (19 dic 2025)
- CVE-2025-22060, CVE-2025-39682 + 70 más (16 dic 2025)
- Vulnerabilidades en AF_UNIX socket, Overlay filesystem, Network traffic control

### Rollback Strategy
```bash
# Si kernel falla, seleccionar versión anterior en GRUB
# En consola física o IPMI:
# - Reiniciar servidor
# - Mantener SHIFT durante boot
# - Seleccionar "Advanced options for Ubuntu"
# - Elegir kernel anterior
```

### Sources
- [Ubuntu Security Notices](https://ubuntu.com/security/notices)
- [Ubuntu Kernel Lifecycle](https://ubuntu.com/kernel/lifecycle)

---

## 6. Otras Actualizaciones (Bajo Riesgo)

### cert-manager v1.13.3 → v1.19.2
- **Breaking Changes**: CRDs deben actualizarse primero
- **Strategy**: `kubectl apply -f crds/` antes de helm upgrade

### Traefik v3.1.0 → v3.6.5
- **Breaking Changes**: Revisar middlewares deprecated
- **Strategy**: Helm upgrade directo, validar IngressRoutes

### Redis 8.2.3 → 8.4.0
- **Breaking Changes**: Minor, revisar changelog
- **Strategy**: Helm upgrade con `--atomic`

### PostgreSQL 18.1.9 → 18.2.0
- **Breaking Changes**: Ninguno significativo (patch)
- **Strategy**: Helm upgrade estándar

---

## Resumen de Dependencias de Upgrade

```text
Ubuntu patches ──┐
                 │
                 ├──▶ K3s v1.28 → v1.30 ──▶ K3s v1.30 → v1.32 ──▶ K3s v1.32 → v1.33
                 │
Backups ─────────┘         │
                           │
                           ▼
                    Longhorn v1.5 → v1.6 → v1.7 → v1.8 → v1.9 → v1.10
                           │
                           ▼
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   cert-manager    kube-prometheus     ArgoCD v2→v3
         │                 │                 │
         ▼                 ▼                 ▼
      Traefik           Redis          PostgreSQL
         │                 │                 │
         └─────────────────┼─────────────────┘
                           ▼
                    Apps (pihole, homepage, etc.)
```

---

## 7. Compatibility Matrix

| Component | Min K8s | Max K8s | Target Version | Verified |
|-----------|---------|---------|----------------|----------|
| Longhorn | 1.25 | 1.33 | v1.10.1 | Yes |
| ArgoCD | 1.28 | 1.33 | v3.2.2 | Yes |
| cert-manager | 1.25 | 1.33 | v1.19.2 | Yes |
| Traefik | 1.26 | 1.33 | v3.6.5 | Yes |
| kube-prometheus-stack | 1.28 | 1.33 | 80.6.0 | Yes |
| MetalLB | 1.25 | 1.33 | v0.15.3 | Yes |

**Conclusion**: All target versions are compatible with K3s v1.33.7

---

## 8. OpenTofu Compliance Notes

Per Constitution Principle I (Infrastructure as Code - OpenTofu First), all upgrades must use OpenTofu modules:

| Component | OpenTofu Module | Version Variable | Status |
|-----------|-----------------|------------------|--------|
| Longhorn | `module.longhorn` | `chart_version` | READY |
| kube-prometheus-stack | `helm_release.kube_prometheus_stack` | `local.prometheus_stack_version` | READY |
| cert-manager | `module.cert_manager` | `chart_version` | READY |
| Traefik | `module.traefik` | `chart_version` | READY |
| ArgoCD | `module.argocd` | `argocd_chart_version` | READY |
| MetalLB | `module.metallb` | `chart_version` | NEW MODULE |
| Redis | `module.redis_shared` | Needs `chart_version` variable | TODO |
| PostgreSQL | `module.postgres_ha` | Needs `chart_version` variable | TODO |

**Upgrade Pattern**:
```bash
# 1. Edit version in module or variable
# 2. Plan
tofu plan -target=module.<name>
# 3. Apply
tofu apply -target=module.<name>
```

---

## 9. Container Image Pinning

| Image | Current Tag | Pin To | OpenTofu Location |
|-------|-------------|--------|-------------------|
| pihole/pihole | latest | 2025.11.1 | `modules/pihole/main.tf` |
| ghcr.io/gethomepage/homepage | latest | v1.8.0 | `modules/homepage/main.tf` |
| sonatype/nexus3 | latest | 3.87.1 | `modules/nexus/main.tf` |
| home-assistant | stable | 2025.12.4 | `modules/home-assistant/main.tf` |
| cloudflared | latest | 2024.12.2 | `modules/cloudflare-tunnel/main.tf` |
| localstack | latest | 4.0.3 | `modules/localstack/main.tf` |
