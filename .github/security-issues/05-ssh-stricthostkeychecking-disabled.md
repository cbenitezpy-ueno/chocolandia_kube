# [SECURITY HIGH] SSH StrictHostKeyChecking disabled in multiple scripts

**Labels:** `security`, `high`, `priority:medium`, `ssh`

## ⚠️ Vulnerabilidad Alta: StrictHostKeyChecking Deshabilitado

### Descripción
Múltiples scripts deshabilitan la verificación de host keys de SSH con `-o StrictHostKeyChecking=no`, lo que los hace vulnerables a ataques Man-in-the-Middle (MITM).

### Ubicación
**Archivos afectados:**

1. `terraform/modules/k3s-node/main.tf` - Línea 108
```bash
ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ...
```

2. `terraform/environments/chocolandiadc-mvp/scripts/backup-cluster.sh` - Líneas 92, 110, 115, 251
```bash
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ...
scp -o StrictHostKeyChecking=no -i "$SSH_KEY" ...
```

3. `scripts/setup-ssh-passwordless.sh` - Líneas 208, 216, 252, 259
```yaml
StrictHostKeyChecking no  # En SSH config
```

### Riesgo
- **Nivel:** ALTO
- **Impacto:** Alto - Compromiso de credenciales SSH
- **Probabilidad:** Baja-Media - Requiere MitM en red local

#### Vectores de Ataque
1. **ARP Spoofing:** Atacante se hace pasar por el nodo destino
2. **DNS Poisoning:** Redirige hostname a IP maliciosa
3. **Rogue DHCP:** Asigna gateway malicioso
4. **WiFi Rogue AP:** Red WiFi falsa con mismo SSID
5. **Switch Compromise:** En red Eero mesh

### Impacto
- Captura de claves SSH privadas
- Ejecución remota de código como root
- Compromiso de tokens del cluster (K3S_TOKEN)
- Instalación de backdoors en nodos

### Attack Scenario
```
1. Atacante en red 192.168.4.0/24
2. Ejecuta ARP spoofing:
   arpspoof -i eth0 -t 192.168.4.100 192.168.4.101
3. Usuario ejecuta terraform apply
4. SSH se conecta a IP del atacante (sin verificar host key)
5. Atacante captura:
   - Clave privada SSH
   - Comandos ejecutados
   - K3S_TOKEN
6. Atacante forward traffic al host real → Usuario no nota nada
```

### Soluciones

#### Opción 1: Usar accept-new (Recomendado) ⭐
```bash
# Acepta nueva clave en primera conexión, rechaza cambios
ssh -o StrictHostKeyChecking=accept-new -i "$SSH_KEY" ...
```

**Ventajas:**
- ✅ Primera conexión automática (convenience)
- ✅ Protege contra cambios de host key (security)
- ✅ Balance perfecto para infraestructura estable

**Implementar en:**
- `terraform/modules/k3s-node/main.tf`
- `terraform/environments/chocolandiadc-mvp/scripts/backup-cluster.sh`

#### Opción 2: Pre-poblar known_hosts (Más Seguro)
```bash
# Script: setup-known-hosts.sh
#!/bin/bash

MASTER_IP="192.168.4.101"
NODO_IP="192.168.4.102"

# Limpiar entradas existentes
ssh-keygen -R $MASTER_IP
ssh-keygen -R $NODO_IP
ssh-keygen -R master1
ssh-keygen -R nodo1

# Obtener y agregar host keys
ssh-keyscan -H $MASTER_IP >> ~/.ssh/known_hosts
ssh-keyscan -H $NODO_IP >> ~/.ssh/known_hosts
ssh-keyscan -H master1 >> ~/.ssh/known_hosts
ssh-keyscan -H nodo1 >> ~/.ssh/known_hosts

echo "Host keys added to known_hosts"
```

**Ventajas:**
- ✅ Máxima seguridad
- ✅ Host keys verificados siempre
- ✅ Detecta MitM inmediatamente

**Desventajas:**
- ❌ Requiere paso adicional en setup
- ❌ Falla si IP cambia (requiere actualizar)

#### Opción 3: HashKnownHosts (Para SSH Config)
```bash
# En scripts/setup-ssh-passwordless.sh
cat >> "$SSH_CONFIG_FILE" << EOF

# K3s ChocolandiaDC MVP Cluster
Host master1
    HostName $MASTER1_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking accept-new  # ✅ Cambiar de 'no'
    UserKnownHostsFile ~/.ssh/known_hosts  # ✅ Usar archivo estándar
    HashKnownHosts yes  # Ofuscar hostnames en known_hosts

Host nodo1
    HostName $NODO1_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking accept-new  # ✅ Cambiar de 'no'
    UserKnownHostsFile ~/.ssh/known_hosts  # ✅ Usar archivo estándar
    HashKnownHosts yes
EOF
```

### Recomendación
**Opción 1 (accept-new) + Opción 2 (pre-poblar en setup inicial)**

### Implementación

#### 1. Agregar a setup-ssh-passwordless.sh
```bash
# Después de línea 223 (después de test SSH)
log "Step 6: Add SSH Host Keys"
echo ""

log "Adding host keys to known_hosts..."
ssh-keyscan -H "$MASTER1_IP" >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan -H "$NODO1_IP" >> ~/.ssh/known_hosts 2>/dev/null

success "Host keys added to ~/.ssh/known_hosts"
```

#### 2. Modificar terraform/modules/k3s-node/main.tf
```hcl
# Línea 108 - Cambiar:
program = ["bash", "-c", <<-EOT
  ssh -o StrictHostKeyChecking=accept-new -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.node_ip} \
    'sudo cat /etc/rancher/k3s/k3s.yaml' | \
    sed "s/127.0.0.1/${var.node_ip}/g" | \
    jq -Rs '{content: .}'
EOT
]
```

#### 3. Modificar backup-cluster.sh
```bash
# Reemplazar TODAS las ocurrencias de:
-o StrictHostKeyChecking=no

# Por:
-o StrictHostKeyChecking=accept-new
```

### Verificación
```bash
# Simular ataque MitM (testing)
# Terminal 1 (atacante):
sudo arpspoof -i eth0 -t <admin-ip> <master-ip>

# Terminal 2 (admin):
ssh master1
# Con 'no': Conecta sin warning ❌
# Con 'accept-new' + known_hosts: Rechaza con error ✅
# Error esperado: "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"
```

### Referencias
- [OpenSSH Security Best Practices](https://www.ssh.com/academy/ssh/security)
- CVE-2015-5600: SSH MaxAuthTries bypass
- OWASP: A02:2021 - Cryptographic Failures

### Prioridad
- [x] Fase 2: Corto Plazo (1-2 semanas)
- [ ] Impacto bajo en desarrollo, crítico en producción

### Checklist
- [ ] Agregar setup de known_hosts a setup-ssh-passwordless.sh
- [ ] Cambiar `StrictHostKeyChecking` de `no` a `accept-new` en:
  - [ ] terraform/modules/k3s-node/main.tf (2 ocurrencias)
  - [ ] scripts/backup-cluster.sh (6+ ocurrencias)
  - [ ] scripts/setup-ssh-passwordless.sh (SSH config template)
- [ ] Testing en cluster de desarrollo
- [ ] Verificar que terraform apply funciona correctamente
- [ ] Documentar procedimiento para nuevos nodos
- [ ] Crear script para actualizar known_hosts

### Workaround si Hay Problemas
```bash
# Si terraform falla con host key verification:

# Opción A: Agregar manualmente
ssh-keyscan -H <node-ip> >> ~/.ssh/known_hosts

# Opción B: Limpiar y re-agregar
ssh-keygen -R <node-ip>
ssh-keyscan -H <node-ip> >> ~/.ssh/known_hosts

# Opción C: Para troubleshooting temporal (NO PRODUCCIÓN)
export ANSIBLE_HOST_KEY_CHECKING=False  # Si usas Ansible
```

### Relacionado
- Issue #4 - Red plana sin segmentación (facilita MitM)
- Issue #1 - Token en variables de entorno (captura durante MitM)
- Docs: SSH security hardening guide
