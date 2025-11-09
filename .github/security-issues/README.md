# Security Issues Tracker

Este directorio contiene issues de seguridad detallados identificados en la auditoría de seguridad del proyecto ChocolandiaDC K3s.

## 📋 Issues Disponibles

### 🔴 Críticos
1. **[01-k3s-token-environment-variables.md](01-k3s-token-environment-variables.md)**
   - Token del cluster expuesto en variables de entorno
   - Prioridad: Alta | Fase: 2 (Corto plazo)

2. **[02-sqlite-no-encryption-at-rest.md](02-sqlite-no-encryption-at-rest.md)**
   - Base de datos SQLite sin encriptación
   - Prioridad: Media | Fase: 3 (Mediano plazo)

### ⚠️ Altos
3. **[03-grafana-no-tls.md](03-grafana-no-tls.md)**
   - Grafana expuesto sin TLS en NodePort
   - Prioridad: Media | Fase: 2 (Corto plazo)

4. **[04-flat-network-no-segmentation.md](04-flat-network-no-segmentation.md)**
   - Red plana sin segmentación de VLANs
   - Prioridad: Baja | Fase: 4 (Largo plazo)

5. **[05-ssh-stricthostkeychecking-disabled.md](05-ssh-stricthostkeychecking-disabled.md)**
   - StrictHostKeyChecking deshabilitado en scripts SSH
   - Prioridad: Media | Fase: 2 (Corto plazo)

6. **[06-no-audit-logging.md](06-no-audit-logging.md)**
   - Sin audit logging habilitado en K3s
   - Prioridad: Media | Fase: 2 (Corto plazo)

## 🎯 Roadmap de Remediación

### Fase 1: Inmediato (✅ Completado)
- [x] Cambiar contraseña de Grafana
- [x] Corregir permisos de kubeconfig (600)
- [x] Corregir permisos de backup SQLite (600)

### Fase 2: Corto Plazo (1-2 semanas)
- [ ] #1 - Corregir exposición de token en variables de entorno
- [ ] #3 - Cambiar Grafana a ClusterIP + port-forward
- [ ] #5 - Usar `StrictHostKeyChecking=accept-new`
- [ ] #6 - Habilitar audit logging

### Fase 3: Mediano Plazo (1-2 meses)
- [ ] #2 - Habilitar encriptación de secrets en K3s
- [ ] #4 - Implementar Network Policies
- [ ] #4 - Configurar firewall en nodos (iptables)

### Fase 4: Largo Plazo (3-6 meses)
- [ ] #2 - Migrar a Feature 001 (etcd + HA)
- [ ] #4 - Migrar a Feature 001 (FortiGate + VLANs)

## 📝 Cómo Usar Estos Issues

### Opción 1: Crear Issues Manualmente en GitHub
```bash
# 1. Abre cada archivo .md
# 2. Copia el contenido
# 3. Ve a: https://github.com/cbenitezpy-ueno/chocolandia_kube/issues/new
# 4. Pega el contenido
# 5. Agrega los labels indicados en cada archivo
```

### Opción 2: Usar GitHub CLI (si está instalado)
```bash
cd .github/security-issues

# Instalar gh si no está disponible
# En macOS: brew install gh
# En Linux: https://github.com/cli/cli/releases

# Autenticarse
gh auth login

# Crear todos los issues
for file in 0*.md; do
  title=$(head -n 1 "$file" | sed 's/^# //')
  body=$(tail -n +3 "$file")

  gh issue create \
    --title "$title" \
    --body "$body" \
    --label "security"
done
```

### Opción 3: Usar Script Automatizado
```bash
# Script: create-issues.sh
#!/bin/bash

REPO="cbenitezpy-ueno/chocolandia_kube"

for file in .github/security-issues/0*.md; do
  echo "Processing $file..."

  # Extraer título (primera línea sin #)
  title=$(head -n 1 "$file" | sed 's/^# //')

  # Extraer labels de la segunda línea
  labels=$(sed -n '3p' "$file" | sed 's/\*\*Labels:\*\* //; s/`//g')

  # Contenido (desde línea 5)
  body=$(tail -n +5 "$file")

  # Crear issue con gh CLI
  gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body "$body" \
    --label "$labels"

  echo "✓ Created issue: $title"
  sleep 2  # Rate limiting
done

echo "All issues created successfully!"
```

## 📊 Matriz de Priorización

| Issue | Severidad | Impacto | Probabilidad | Prioridad | Esfuerzo |
|-------|-----------|---------|--------------|-----------|----------|
| #1 Token en env | Crítico | Alto | Media | Alta | 2h |
| #2 SQLite no encrypt | Crítico | Crítico | Baja | Media | 1 día |
| #3 Grafana no TLS | Alto | Alto | Media | Media | 2h |
| #4 Red plana | Alto | Alto | Media | Baja | 3-6 meses |
| #5 SSH checks | Alto | Alto | Baja | Media | 1h |
| #6 No audit logs | Alto | Alto | Alta | Alta | 3h |

## 🔗 Referencias

### Documentación de Seguridad
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [K3s Security Hardening](https://docs.k3s.io/security/hardening-guide)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)

### Auditoría Original
- Commit: c1bbc1c - Fix kubeconfig permissions
- Branch: `claude/como-exper-011CUxxw43P7XRpQEczzWm9c`
- Fecha: 2025-01-09

## 📧 Contacto

Para preguntas sobre estos issues de seguridad:
- **Repositorio:** https://github.com/cbenitezpy-ueno/chocolandia_kube
- **Issues:** https://github.com/cbenitezpy-ueno/chocolandia_kube/issues

---

**Última actualización:** 2025-01-09
**Generado por:** Claude Code Security Audit
