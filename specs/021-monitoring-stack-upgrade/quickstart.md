# Quickstart: Monitoring Stack Upgrade

**Feature**: 021-monitoring-stack-upgrade
**Date**: 2025-12-27
**Estimated Time**: 30-45 minutos

## Prerequisites

- [ ] Acceso kubectl al cluster K3s
- [ ] OpenTofu instalado y configurado
- [ ] Helm repos actualizados: `helm repo update`
- [ ] Acceso a Ntfy para verificar alertas

## Quick Verification Commands

```bash
# Verificar versión actual
helm list -n monitoring

# Verificar pods
kubectl get pods -n monitoring

# Verificar acceso a Grafana
curl -s http://<node-ip>:30000/api/health | jq

# Verificar ServiceMonitors
kubectl get servicemonitors -A --no-headers | wc -l
```

---

## Upgrade Procedure

### Step 1: Pre-Upgrade Backup (5 min)

```bash
# Exportar valores actuales
helm get values kube-prometheus-stack -n monitoring > ~/backup-monitoring-values.yaml

# Exportar ServiceMonitors
kubectl get servicemonitors -A -o yaml > ~/backup-servicemonitors.yaml

# Exportar PrometheusRules
kubectl get prometheusrules -A -o yaml > ~/backup-prometheusrules.yaml

# Snapshot de Longhorn (opcional pero recomendado)
# Usar UI de Longhorn o kubectl
```

### Step 2: Verify Pre-Upgrade State

```bash
# Contar dashboards
kubectl get cm -n monitoring -l grafana_dashboard=1 --no-headers | wc -l
# Esperado: >= 38

# Verificar retención
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.spec.retention}'
# Esperado: 15d

# Verificar NodePort
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.spec.ports[0].nodePort}'
# Esperado: 30000
```

### Step 3: Update OpenTofu Configuration

```bash
cd <repo-root>/terraform/environments/chocolandiadc-mvp

# Editar monitoring.tf
# Cambiar: local.prometheus_stack_version = "55.5.0"
# A:       local.prometheus_stack_version = "68.4.0"
```

**Cambios específicos en monitoring.tf**:

```hcl
locals {
  prometheus_stack_version = "68.4.0"  # Antes: 55.5.0
}
```

### Step 4: Validate OpenTofu Plan

```bash
export KUBECONFIG=<repo-root>/terraform/environments/chocolandiadc-mvp/kubeconfig

cd <repo-root>/terraform/environments/chocolandiadc-mvp

# Validar sintaxis
tofu validate

# Ver plan de cambios
TF_VAR_github_token="dummy" \
TF_VAR_github_app_id="dummy" \
TF_VAR_github_app_installation_id="dummy" \
TF_VAR_github_app_private_key="dummy" \
TF_VAR_govee_api_key="dummy" \
tofu plan -target=helm_release.kube_prometheus_stack
```

**Verificar que el plan muestra**:
- `helm_release.kube_prometheus_stack` will be updated
- Version change: `55.5.0` → `68.4.0`
- NO recursos destruidos inesperadamente

### Step 5: Apply Upgrade

```bash
TF_VAR_github_token="dummy" \
TF_VAR_github_app_id="dummy" \
TF_VAR_github_app_installation_id="dummy" \
TF_VAR_github_app_private_key="dummy" \
TF_VAR_govee_api_key="dummy" \
tofu apply -target=helm_release.kube_prometheus_stack
```

**Tiempo estimado**: 5-10 minutos

### Step 6: Monitor Upgrade Progress

```bash
# En terminal separada, monitorear pods
watch kubectl get pods -n monitoring

# Esperar a que todos estén Running (1/1)
```

### Step 7: Post-Upgrade Verification

```bash
# Verificar nueva versión
helm list -n monitoring
# Esperado: Chart version 68.4.0

# Verificar todos los pods Running
kubectl get pods -n monitoring
# Esperado: Todos 1/1 Running, 0 restarts

# Verificar retención preservada
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.spec.retention}'
# Esperado: 15d

# Verificar NodePort preservado
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.spec.ports[0].nodePort}'
# Esperado: 30000

# Verificar dashboards cargados
kubectl get cm -n monitoring -l grafana_dashboard=1 --no-headers | wc -l
# Esperado: >= 38
```

### Step 8: Test Alerts

```bash
# Generar alerta de prueba
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring &

curl -X POST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[
    {
      "labels": {
        "alertname": "UpgradeTestAlert",
        "severity": "info",
        "namespace": "monitoring"
      },
      "annotations": {
        "summary": "Test alert after monitoring stack upgrade",
        "description": "This is a test alert to verify Ntfy integration"
      }
    }
  ]'

# Verificar en Ntfy que llegó la notificación
# kill el port-forward cuando termine
kill %1
```

---

## Rollback Procedure (if needed)

```bash
# 1. Rollback Helm release
helm rollback kube-prometheus-stack -n monitoring

# 2. Esperar pods
kubectl get pods -n monitoring -w

# 3. O restaurar via OpenTofu
# Revertir cambio en monitoring.tf a version = "55.5.0"
TF_VAR_github_token="dummy" \
TF_VAR_github_app_id="dummy" \
TF_VAR_github_app_installation_id="dummy" \
TF_VAR_github_app_private_key="dummy" \
TF_VAR_govee_api_key="dummy" \
tofu apply -target=helm_release.kube_prometheus_stack
```

---

## Troubleshooting

### Pods not starting

```bash
# Ver eventos
kubectl describe pod <pod-name> -n monitoring

# Ver logs
kubectl logs <pod-name> -n monitoring --previous
```

### Grafana dashboards missing

```bash
# Verificar sidecar está corriendo
kubectl get pods -n monitoring | grep grafana

# Ver logs del sidecar
kubectl logs -n monitoring $(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o name) -c grafana-sc-dashboard

# Verificar labels de ConfigMaps
kubectl get cm -A -l grafana_dashboard --show-labels
```

### Alertas no llegan a Ntfy

```bash
# Verificar configuración de Alertmanager
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Verificar que Ntfy service existe
kubectl get svc ntfy -n ntfy
```

### Métricas históricas no disponibles

```bash
# Verificar PVC no fue eliminado
kubectl get pvc -n monitoring

# Verificar datos en Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring &
curl 'http://localhost:9090/api/v1/query?query=count(up)'
kill %1
```

---

## Success Checklist

- [ ] `helm list -n monitoring` muestra versión 68.4.0
- [ ] Todos los pods en Running sin restarts
- [ ] Grafana accesible en `http://<node-ip>:30000`
- [ ] Los 6+ dashboards personalizados visibles
- [ ] Query de métricas históricas (15 días) funciona
- [ ] Alerta de prueba llega a Ntfy
- [ ] `tofu plan` no muestra cambios inesperados
