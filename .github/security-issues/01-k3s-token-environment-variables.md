# [SECURITY CRITICAL] K3s cluster token exposed in environment variables

**Labels:** `security`, `critical`, `priority:high`

## 🔴 Vulnerabilidad Crítica: Token del Cluster en Variables de Entorno

### Descripción
El token de autenticación K3S_TOKEN se exporta como variable de entorno durante la instalación del agente, lo que lo hace visible en la lista de procesos del sistema.

### Ubicación
**Archivo:** `terraform/modules/k3s-node/scripts/install-k3s-agent.sh`
**Líneas:** 109-110

```bash
export K3S_URL="$K3S_URL"
export K3S_TOKEN="$K3S_TOKEN"  # ❌ Visible en 'ps aux' y '/proc/*/environ'
```

### Riesgo
- **Nivel:** CRÍTICO
- **Impacto:** Alto - Compromiso total del cluster
- **Probabilidad:** Media - Cualquier usuario del sistema puede capturar el token

#### Vectores de Ataque
1. Usuario malicioso ejecuta `ps aux | grep K3S` durante instalación
2. Monitoreo de `/proc/*/environ` captura variables
3. Logs del sistema pueden incluir el token
4. Historial de bash puede contener el valor

### Impacto
- Nodos no autorizados pueden unirse al cluster
- No hay mecanismo de rotación del token en K3s
- Compromiso requiere reinstalación completa del cluster

### Solución Recomendada

**Opción 1: Usar archivo temporal (Recomendado)**
```bash
# Crear archivo temporal seguro
K3S_TOKEN_FILE=$(mktemp)
chmod 600 "$K3S_TOKEN_FILE"
echo "$K3S_TOKEN" > "$K3S_TOKEN_FILE"
trap "rm -f $K3S_TOKEN_FILE" EXIT

export K3S_URL="$K3S_URL"
export K3S_TOKEN_FILE  # K3s soporta K3S_TOKEN_FILE en lugar de K3S_TOKEN

# Ejecutar instalación
curl -sfL "$INSTALL_K3S_URL" | sh

# Cleanup automático con trap
```

**Opción 2: Heredoc con stdin**
```bash
curl -sfL "$INSTALL_K3S_URL" | K3S_URL="$K3S_URL" sh -s - agent <<< "$K3S_TOKEN"
```

### Verificación
```bash
# Durante la instalación, en otra terminal:
ps aux | grep -i k3s
cat /proc/$(pgrep -f k3s-agent)/environ | tr '\0' '\n' | grep K3S
```

### Referencias
- CIS Kubernetes Benchmark: 4.1.3 - Ensure that the kubelet configuration file has permissions set to 644 or more restrictive
- OWASP: A02:2021 – Cryptographic Failures
- [K3s Environment Variables Documentation](https://docs.k3s.io/reference/env-variables)

### Prioridad
- [x] Fase 2: Corto Plazo (1-2 semanas)
- [ ] Requiere testing en ambiente dev antes de producción

### Checklist
- [ ] Modificar `install-k3s-agent.sh` para usar `K3S_TOKEN_FILE`
- [ ] Agregar cleanup con trap
- [ ] Testing en nodo de prueba
- [ ] Verificar con `ps` que token no es visible
- [ ] Actualizar documentación
- [ ] Crear PR con los cambios

### Relacionado
- Vulnerabilidad de permisos de kubeconfig (RESUELTO en commit c1bbc1c)
