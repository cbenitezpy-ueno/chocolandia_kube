# [SECURITY HIGH] Flat network without segmentation

**Labels:** `security`, `high`, `priority:low`, `networking`, `architecture`

## ⚠️ Vulnerabilidad Alta: Red Plana sin Segmentación

### Descripción
El cluster K3s está desplegado en una red Eero plana (192.168.4.0/24) sin VLANs ni segmentación. Todos los dispositivos (cluster, IoT, móviles, laptops) comparten la misma red sin aislamiento.

### Ubicación
**Red:** 192.168.4.0/24 (Eero mesh network)
**Dispositivos:** Cluster nodes + dispositivos domésticos
**Firewall:** Ninguno entre dispositivos

### Riesgo
- **Nivel:** ALTO
- **Impacto:** Alto - Lateral movement, acceso desde dispositivos comprometidos
- **Probabilidad:** Media - Cualquier dispositivo comprometido en la red

#### Vectores de Ataque
1. **Dispositivo IoT Comprometido:** Router vulnerado puede acceder al cluster
2. **Laptop Infectada:** Malware puede escanear y atacar nodos
3. **WiFi Compromise:** Ataque a red WiFi expone todo
4. **Guest Network:** Sin red de invitados separada
5. **ARP Spoofing:** Sin protección contra MitM en L2

### Impacto
- Acceso no autorizado a servicios del cluster
- Lateral movement desde dispositivos comprometidos
- Escaneo y reconnaissance sin restricciones
- Ataques de denegación de servicio internos
- Sin defensa en profundidad (defense in depth)

### Arquitectura Actual
```
┌─────────────────────────────────────────────────────────┐
│  Eero Router (192.168.4.1)                              │
│  Flat Network - 192.168.4.0/24                          │
├─────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌─────────┐      │
│  │ master1 │  │  nodo1  │  │ IoT  │  │ Laptop  │ ...  │
│  │  .101   │  │  .102   │  │ .50  │  │  .200   │      │
│  └─────────┘  └─────────┘  └──────┘  └─────────┘      │
│       ▲            ▲           ▲           ▲            │
│       └────────────┴───────────┴───────────┘            │
│              Sin firewall ni segmentación               │
└─────────────────────────────────────────────────────────┘
```

### Soluciones por Fase

#### Fase 1: Mitigación Inmediata (Semana 1) ✅
**Ya implementadas:**
- [x] Documentar dispositivos en la red
- [x] Cambiar contraseñas por defecto (Grafana)
- [x] Usar autenticación fuerte
- [x] Port-forward en lugar de NodePort

**Adicionales:**
- [ ] Auditoría de dispositivos conectados a Eero
- [ ] Deshabilitar UPnP en router Eero
- [ ] Habilitar aislamiento de clientes WiFi (AP isolation)
- [ ] Configurar red de invitados separada

#### Fase 2: Network Policies en Kubernetes (Semana 2-3)
```yaml
# Denegar todo tráfico por defecto
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Permitir solo tráfico necesario
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: grafana
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 3000
```

#### Fase 3: Firewall en Nodos (Mes 1-2)
```bash
# iptables rules en cada nodo
# Permitir solo tráfico específico

# Master1: Permitir API server solo desde nodo1 y admin laptop
sudo iptables -A INPUT -p tcp --dport 6443 -s 192.168.4.102 -j ACCEPT  # nodo1
sudo iptables -A INPUT -p tcp --dport 6443 -s 192.168.4.200 -j ACCEPT  # admin laptop
sudo iptables -A INPUT -p tcp --dport 6443 -j DROP

# Ambos nodos: Permitir SSH solo desde admin laptop
sudo iptables -A INPUT -p tcp --dport 22 -s 192.168.4.200 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP

# Persistir reglas
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

#### Fase 4: Migrar a Feature 001 (Mes 3-6) ⭐ RECOMENDADO
**Arquitectura con FortiGate:**
```
Internet
   │
   ▼
FortiGate Firewall
   │
   ├──[VLAN 10] - Management (SSH, Admin)
   │   └─── Admin Laptop (.10.100)
   │
   ├──[VLAN 20] - Kubernetes Cluster
   │   ├─── master1 (.20.10)
   │   ├─── master2 (.20.11)
   │   └─── nodo1  (.20.20)
   │
   ├──[VLAN 30] - Services (Grafana, etc)
   │   └─── Load Balancer
   │
   └──[VLAN 40] - IoT Devices
       └─── Cámaras, sensores, etc.

Rules:
- VLAN 10 → VLAN 20: Permitir SSH, kubectl
- VLAN 20 → VLAN 20: Permitir cluster traffic
- VLAN 30 → VLAN 20: Permitir ingress traffic
- VLAN 40 → VLAN 20: DENEGAR todo
```

### Mitigaciones Temporales (Sin cambio de hardware)

#### 1. Configurar Eero (Si soporta)
- Revisar configuración de Eero app
- Habilitar "Client Isolation" (si disponible)
- Configurar red de invitados
- Actualizar firmware a última versión

#### 2. Host-based Firewall
```bash
# Script: configure-firewall.sh
#!/bin/bash

# Variables
ADMIN_IP="192.168.4.200"
MASTER_IP="192.168.4.101"
NODO_IP="192.168.4.102"

# Limpiar reglas existentes
sudo iptables -F
sudo iptables -X

# Política por defecto: DROP
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Permitir loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Permitir conexiones establecidas
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir SSH desde admin
sudo iptables -A INPUT -p tcp --dport 22 -s $ADMIN_IP -j ACCEPT

# Permitir tráfico inter-cluster
sudo iptables -A INPUT -s $MASTER_IP -j ACCEPT
sudo iptables -A INPUT -s $NODO_IP -j ACCEPT

# Log dropped packets
sudo iptables -A INPUT -j LOG --log-prefix "IPTables-Dropped: "

# Guardar reglas
sudo netfilter-persistent save
```

### Verificación
```bash
# Listar dispositivos en red
sudo nmap -sn 192.168.4.0/24

# Verificar firewall rules
sudo iptables -L -n -v

# Testing de acceso
# Desde dispositivo NO autorizado:
nc -zv 192.168.4.101 6443  # Debe fallar

# Desde dispositivo autorizado:
nc -zv 192.168.4.101 6443  # Debe conectar
```

### Referencias
- [NIST SP 800-125B: Secure Virtual Network Configuration](https://csrc.nist.gov/publications/detail/sp/800-125b/final)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- CIS Benchmark: 5.3 - Network Policies and CNI

### Prioridad
- [x] Fase 1: Inmediato (mitigaciones sin hardware)
- [ ] Fase 2: Corto plazo (1 mes) - Network Policies
- [ ] Fase 3: Mediano plazo (2 meses) - Host firewall
- [ ] Fase 4: Largo plazo (6 meses) - Feature 001 con FortiGate

### Checklist
#### Fase 1
- [ ] Auditar dispositivos conectados a Eero
- [ ] Documentar IPs y hostnames
- [ ] Revisar settings de Eero (client isolation)
- [ ] Crear red de invitados

#### Fase 2
- [ ] Diseñar Network Policies por namespace
- [ ] Implementar default-deny-all
- [ ] Permitir solo tráfico necesario
- [ ] Testing exhaustivo

#### Fase 3
- [ ] Crear script configure-firewall.sh
- [ ] Testing en nodo de prueba
- [ ] Aplicar a todos los nodos
- [ ] Documentar reglas

#### Fase 4
- [ ] Planificar migración a Feature 001
- [ ] Adquirir FortiGate hardware
- [ ] Diseñar arquitectura de VLANs
- [ ] Migración sin downtime

### Nota Importante
⚠️ **Esta es una limitación arquitectural de Feature 002** que usa red doméstica Eero. Para entornos de producción, Feature 001 con FortiGate y VLANs es la solución definitiva.

### Relacionado
- Issue #3 - Grafana sin TLS
- Feature 001 - FortiGate + VLAN architecture
- Docs: Network security best practices
