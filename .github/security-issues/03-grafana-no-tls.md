# [SECURITY HIGH] Grafana exposed without TLS on NodePort

**Labels:** `security`, `high`, `priority:medium`, `networking`

## ⚠️ Vulnerabilidad Alta: Exposición de Grafana sin TLS

### Descripción
Grafana está expuesto vía NodePort en el puerto 30000 usando HTTP sin cifrado. Las credenciales de administrador y datos sensibles se transmiten en texto plano.

### Ubicación
**Archivo:** `terraform/environments/chocolandiadc-mvp/monitoring.tf`
**Líneas:** 82-89

```hcl
set {
  name  = "grafana.service.type"
  value = "NodePort"
}

set {
  name  = "grafana.service.nodePort"
  value = "30000"
}
```

### Riesgo
- **Nivel:** ALTO
- **Impacto:** Alto - Intercepción de credenciales
- **Probabilidad:** Media - Accesible desde toda la red 192.168.4.0/24

#### Vectores de Ataque
1. **Man-in-the-Middle (MITM):** Intercepción en red WiFi
2. **Credential Sniffing:** Captura de password admin con tcpdump/Wireshark
3. **Session Hijacking:** Robo de cookies de sesión
4. **WiFi Eavesdropping:** Red Eero es wireless, vulnerable a packet capture

### Impacto
- Credenciales de Grafana transmitidas en texto plano
- Acceso a métricas sensibles del cluster
- Posible pivoting a otros servicios
- Información de infraestructura expuesta

### Soluciones

#### Opción 1: Port-Forward (Más Segura) ⭐
```bash
# Eliminar NodePort, cambiar a ClusterIP
set {
  name  = "grafana.service.type"
  value = "ClusterIP"
}

# Acceso mediante:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Luego abrir: http://localhost:3000
```

**Ventajas:**
- ✅ Tráfico nunca sale del tunnel SSH cifrado
- ✅ No expuesto en la red
- ✅ Fácil de implementar (cambiar 1 línea)

**Desventajas:**
- ❌ Requiere kubectl y kubeconfig en cada cliente
- ❌ Acceso manual (no permanente)

#### Opción 2: TLS con Certificado Auto-firmado
```hcl
# Generar certificado
resource "tls_private_key" "grafana" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "grafana" {
  private_key_pem = tls_private_key.grafana.private_key_pem

  subject {
    common_name  = "grafana.chocolandiadc.local"
    organization = "ChocolandiaDC"
  }

  validity_period_hours = 8760 # 1 año

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "grafana_tls" {
  metadata {
    name      = "grafana-tls"
    namespace = "monitoring"
  }

  data = {
    "tls.crt" = tls_self_signed_cert.grafana.cert_pem
    "tls.key" = tls_private_key.grafana.private_key_pem
  }

  type = "kubernetes.io/tls"
}

# En monitoring.tf
set {
  name  = "grafana.ingress.enabled"
  value = "true"
}

set {
  name  = "grafana.ingress.tls[0].secretName"
  value = "grafana-tls"
}
```

#### Opción 3: Let's Encrypt con cert-manager (Producción)
```bash
# Instalar cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# ClusterIssuer para Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@chocolandiadc.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Recomendación para Feature 002 (MVP)
**Usar Opción 1 (Port-Forward)** por simplicidad y máxima seguridad.

```hcl
# Cambiar en monitoring.tf línea 82-89:
set {
  name  = "grafana.service.type"
  value = "ClusterIP"
}

# Eliminar:
# set {
#   name  = "grafana.service.nodePort"
#   value = "30000"
# }
```

### Verificación
```bash
# Verificar que Grafana NO está expuesto
nmap -p 30000 192.168.4.101
# Debe mostrar: filtered o closed

# Acceder con port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Abrir: http://localhost:3000
```

### Referencias
- OWASP: A02:2021 – Cryptographic Failures
- CIS Benchmark: 5.3.2 - Ensure that all Namespaces have Network Policies defined

### Prioridad
- [x] Fase 2: Corto Plazo (1-2 semanas)
- [ ] Para Feature 002: Cambiar a ClusterIP + port-forward
- [ ] Para Feature 001 (Producción): Implementar Ingress + cert-manager + Let's Encrypt

### Checklist
#### Opción 1 (Recomendado para MVP)
- [ ] Cambiar `grafana.service.type` a `ClusterIP` en monitoring.tf
- [ ] Eliminar configuración de `nodePort`
- [ ] Actualizar documentación con comando port-forward
- [ ] Testing de acceso vía port-forward
- [ ] Actualizar `outputs.tf` con comando port-forward

#### Opción 2/3 (Para Producción)
- [ ] Decidir entre auto-firmado o Let's Encrypt
- [ ] Instalar Ingress Controller (Nginx)
- [ ] Configurar TLS
- [ ] Testing de certificados
- [ ] Configurar DNS (grafana.chocolandiadc.local)

### Workaround Temporal
Si necesitas acceso externo urgente antes de implementar la solución:
```bash
# Usar SSH tunnel
ssh -L 3000:192.168.4.101:30000 usuario@192.168.4.101
# Acceder: http://localhost:3000
```

### Relacionado
- Issue #5 - Red plana sin segmentación
- Feature 001 - FortiGate firewall + VLANs
