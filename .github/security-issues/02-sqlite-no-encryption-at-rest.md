# [SECURITY CRITICAL] SQLite database without encryption at rest

**Labels:** `security`, `critical`, `priority:medium`, `enhancement`

## 🔴 Vulnerabilidad Crítica: Base de Datos SQLite sin Encriptación en Reposo

### Descripción
La base de datos SQLite de K3s (`state.db`) almacena todos los secretos de Kubernetes en texto plano (base64, NO encriptación real). Cualquier persona con acceso al archivo puede extraer todas las credenciales del cluster.

### Ubicación
**Archivo:** `/var/lib/rancher/k3s/server/db/state.db` en master1
**Permisos actuales:** 600 root:root (protegido por sistema de archivos solamente)

### Riesgo
- **Nivel:** CRÍTICO
- **Impacto:** Crítico - Exposición total de secretos
- **Probabilidad:** Baja (requiere acceso root o físico)

#### Datos Sensibles Expuestos
1. Tokens de ServiceAccount
2. Credenciales de aplicaciones (passwords, API keys)
3. Certificados TLS privados
4. Contraseñas almacenadas en Secrets de Kubernetes
5. Tokens de autenticación

### Impacto
- Acceso root al sistema = acceso a todos los secretos
- Backups no encriptados exponen todos los secretos
- Discos físicos desechados sin wipear son vulnerables
- Snapshots de VM contienen secretos en texto plano

### Solución por Fases

#### Fase 1: Mitigación Inmediata (Ya implementado ✅)
- [x] Permisos 600 en state.db
- [x] Permisos 600 en backups
- [x] Warning en scripts de backup

#### Fase 2: Encriptación de K3s (Mediano Plazo)
```yaml
# /etc/rancher/k3s/config.yaml
secrets-encryption: true
```

**Implementación:**
```bash
# 1. Detener K3s
sudo systemctl stop k3s

# 2. Crear config
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml <<EOF
secrets-encryption: true
EOF

# 3. Reiniciar K3s
sudo systemctl start k3s

# 4. Re-encriptar secretos existentes
kubectl get secrets --all-namespaces -o json | \
  kubectl replace -f -
```

#### Fase 3: Migrar a etcd con Encriptación (Largo Plazo)
- Migrar de SQLite a etcd (requiere Feature 001 - HA setup)
- Configurar etcd con encriptación en reposo
- Usar external KMS provider (Vault, AWS KMS)

### Encriptación de Backups
```bash
# Agregar al final de backup-cluster.sh
log "Encrypting backup with GPG..."
tar -czf - "$BACKUP_DIR" | \
  gpg --symmetric --cipher-algo AES256 \
  -o "$BACKUP_DIR-$TIMESTAMP.tar.gz.gpg"

# Eliminar backup sin encriptar
rm -rf "$BACKUP_DIR"

log "Encrypted backup: $BACKUP_DIR-$TIMESTAMP.tar.gz.gpg"
```

### Verificación
```bash
# Verificar encriptación habilitada
sudo k3s kubectl get secrets -n kube-system \
  -o jsonpath='{.items[0].metadata.annotations.encryption\.alpha\.kubernetes\.io/encryption-provider}'

# Debe retornar: aescbc (o similar)
```

### Referencias
- [K3s Secrets Encryption](https://docs.k3s.io/security/secrets-encryption)
- [Kubernetes Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- CIS Benchmark: 1.2.33 - Ensure that the --encryption-provider-config argument is set

### Prioridad
- [ ] Fase 2: Mediano Plazo (1-2 meses) - Habilitar secrets-encryption
- [ ] Fase 3: Largo Plazo (3-6 meses) - Migrar a Feature 001 con etcd + KMS

### Checklist
#### Fase 2
- [ ] Crear configuración `/etc/rancher/k3s/config.yaml`
- [ ] Testing en cluster de desarrollo
- [ ] Documentar procedimiento de re-encriptación
- [ ] Actualizar Terraform para incluir config
- [ ] Re-encriptar secretos existentes

#### Backups Encriptados
- [ ] Modificar `backup-cluster.sh` para encriptar con GPG
- [ ] Documentar gestión de passphrases
- [ ] Testing de restore desde backup encriptado
- [ ] Almacenar passphrases en gestor seguro (1Password, Vault)

### Nota Importante
⚠️ **Esta es una limitación arquitectural de Feature 002 (MVP con SQLite)**. Para producción, se recomienda migrar a Feature 001 que incluye:
- etcd en lugar de SQLite
- HA (High Availability)
- Encriptación nativa
- Integración con KMS providers

### Relacionado
- Issue #10 - Backups sin encriptación
- Feature 001 - Migration to FortiGate + HA cluster
