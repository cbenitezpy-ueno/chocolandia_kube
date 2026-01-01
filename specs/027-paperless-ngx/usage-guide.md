# Guía de Uso: Paperless-ngx

Sistema de gestión documental con OCR automático e integración con escáneres de red.

## Acceso Rápido

| Tipo | URL | Descripción |
|------|-----|-------------|
| Internet | https://paperless.chocolandiadc.com | Acceso via Cloudflare Zero Trust |
| LAN | https://paperless.chocolandiadc.local | Acceso directo desde la red local |
| SMB | `smb://192.168.4.201/consume` | Carpeta para escáner |

## Credenciales

### Recuperar credenciales

```bash
cd ~/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Cargar variables de entorno
source ./backend-env.sh

# Usuario y password de la web (admin)
echo "Usuario: admin"
echo "Password: $(tofu output -raw paperless_admin_password)"

# Usuario y password del SMB (scanner)
echo "Usuario: scanner"
echo "Password: $(tofu output -raw paperless_samba_password)"
```

### Tabla de credenciales

| Servicio | Usuario | Comando para obtener password |
|----------|---------|-------------------------------|
| Web UI | `admin` | `tofu output -raw paperless_admin_password` |
| SMB Share | `scanner` | `tofu output -raw paperless_samba_password` |

## Uso Básico

### 1. Subir documentos manualmente

1. Acceder a https://paperless.chocolandiadc.com
2. Iniciar sesión con usuario `admin`
3. Click en el botón **Upload** (esquina superior derecha)
4. Arrastrar archivos PDF, imágenes o documentos escaneados
5. El OCR procesará automáticamente el documento

### 2. Configurar escáner de red

Configurar el escáner para guardar en carpeta SMB:

| Configuración | Valor |
|---------------|-------|
| Servidor/Host | `192.168.4.201` |
| Puerto | `445` |
| Carpeta compartida | `consume` |
| Usuario | `scanner` |
| Password | *(ver sección Credenciales)* |
| Formato | PDF (recomendado) |

**Flujo automático:**
1. El escáner guarda el documento en `smb://192.168.4.201/consume`
2. Paperless detecta el nuevo archivo (polling cada minuto)
3. OCR procesa el documento (español + inglés)
4. El documento aparece en la bandeja de entrada

### 3. Organizar documentos

**Correspondents (Remitentes):**
- Crear remitentes para categorizar por origen (ej: "Banco", "ANDE", "ESSAP")

**Document Types (Tipos):**
- Crear tipos de documento (ej: "Factura", "Contrato", "Recibo")

**Tags (Etiquetas):**
- Usar etiquetas para clasificación adicional

**Storage Paths:**
- Configurar rutas de almacenamiento personalizadas

### 4. Buscar documentos

- Usar la barra de búsqueda para texto completo (OCR)
- Filtrar por fecha, tipo, remitente o etiquetas
- Búsqueda avanzada con operadores: `tag:factura AND correspondent:banco`

## Administración

### Ver logs del pod

```bash
# Logs de Paperless-ngx
kubectl logs -n paperless deployment/paperless-ngx -c paperless-ngx -f

# Logs del sidecar Samba
kubectl logs -n paperless deployment/paperless-ngx -c samba -f
```

### Reiniciar el servicio

```bash
kubectl rollout restart deployment/paperless-ngx -n paperless
```

### Verificar estado

```bash
# Estado del pod
kubectl get pods -n paperless

# Estado de los servicios
kubectl get svc -n paperless

# Verificar conexión a base de datos
kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 -c "from django.db import connection; connection.ensure_connection(); print('DB OK')"
```

### Acceder al shell de Django

```bash
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 manage.py shell
```

### Crear usuario adicional

```bash
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 manage.py createsuperuser
```

### Resetear password de admin

```bash
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 manage.py changepassword admin
```

## Backup y Restore

### Backup manual de documentos

```bash
# Exportar todos los documentos
kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 manage.py document_exporter /tmp/backup

# Copiar backup al local
kubectl cp paperless/$(kubectl get pod -n paperless -l app.kubernetes.io/name=paperless-ngx -o jsonpath='{.items[0].metadata.name}'):/tmp/backup ./paperless-backup -c paperless-ngx
```

### Restore de documentos

```bash
# Copiar backup al pod
kubectl cp ./paperless-backup paperless/$(kubectl get pod -n paperless -l app.kubernetes.io/name=paperless-ngx -o jsonpath='{.items[0].metadata.name}'):/tmp/backup -c paperless-ngx

# Importar documentos
kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 manage.py document_importer /tmp/backup
```

### Backup automático (Velero)

Los PVCs de Paperless están incluidos en el backup nocturno de Velero:
- `paperless-ngx-data` (5Gi) - Configuración y Whoosh search index
- `paperless-ngx-media` (40Gi) - Documentos originales y thumbnails
- `paperless-ngx-consume` (5Gi) - Carpeta de intake del escáner

## Monitoreo

### Prometheus Metrics

Paperless expone métricas en `/metrics`:

```bash
# Ver métricas disponibles
kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  curl -s localhost:8000/metrics | head -50
```

### Alertas configuradas

| Alerta | Condición | Severidad |
|--------|-----------|-----------|
| PaperlessDown | Servicio no responde por 5 min | Critical |
| PaperlessHighMemory | Uso de memoria > 90% por 10 min | Warning |

### Dashboard de Grafana

Las métricas de Paperless se pueden visualizar en Grafana:
1. Acceder a https://grafana.chocolandiadc.com
2. Explorar métricas con prefijo `paperless_` o `django_`

## Troubleshooting

### El escáner no puede conectar al SMB

1. Verificar que el servicio Samba está corriendo:
   ```bash
   kubectl get svc samba-smb -n paperless
   # Debe mostrar EXTERNAL-IP: 192.168.4.201
   ```

2. Verificar logs del sidecar Samba:
   ```bash
   kubectl logs -n paperless deployment/paperless-ngx -c samba
   ```

3. Probar conexión desde otra máquina Linux:
   ```bash
   smbclient //192.168.4.201/consume -U scanner
   ```

### Documentos no se procesan (OCR)

1. Verificar cola de Celery:
   ```bash
   kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
     celery -A paperless inspect active
   ```

2. Verificar conexión a Redis:
   ```bash
   kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
     python3 -c "import os, redis; r=redis.from_url(os.environ['PAPERLESS_REDIS']); print('Redis OK:', r.ping())"
   ```

3. Revisar logs de tareas:
   ```bash
   kubectl logs -n paperless deployment/paperless-ngx -c paperless-ngx | grep -i "consume\|ocr"
   ```

### Error de conexión a base de datos

1. Verificar conexión desde el pod:
   ```bash
   kubectl exec -n paperless deployment/paperless-ngx -c paperless-ngx -- \
     python3 -c "from django.db import connection; connection.ensure_connection(); print('DB OK')"
   ```

2. Verificar secret de credenciales:
   ```bash
   kubectl get secret paperless-credentials -n paperless -o yaml
   ```

### Pod en CrashLoopBackOff

1. Ver eventos del pod:
   ```bash
   kubectl describe pod -n paperless -l app.kubernetes.io/name=paperless-ngx
   ```

2. Ver logs del último crash:
   ```bash
   kubectl logs -n paperless deployment/paperless-ngx -c paperless-ngx --previous
   ```

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     Paperless Namespace                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Deployment: paperless-ngx              │    │
│  │  ┌─────────────────┐  ┌─────────────────────────┐  │    │
│  │  │  paperless-ngx  │  │    samba (sidecar)      │  │    │
│  │  │    container    │  │      container          │  │    │
│  │  │   Port: 8000    │  │     Port: 445           │  │    │
│  │  └────────┬────────┘  └───────────┬─────────────┘  │    │
│  │           │                       │                 │    │
│  │           └───────────┬───────────┘                 │    │
│  │                       │                             │    │
│  │  ┌────────────────────┼────────────────────────┐   │    │
│  │  │           Shared Volumes                     │   │    │
│  │  │  ┌─────────┐ ┌──────────┐ ┌─────────────┐   │   │    │
│  │  │  │  data   │ │  media   │ │   consume   │   │   │    │
│  │  │  │  5Gi    │ │  40Gi    │ │    5Gi      │   │   │    │
│  │  │  └─────────┘ └──────────┘ └─────────────┘   │   │    │
│  │  └─────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────┐  ┌───────────────────────────────┐    │
│  │ Service: ClusterIP│  │ Service: LoadBalancer         │    │
│  │ paperless-ngx:8000│  │ samba-smb:445                 │    │
│  └─────────┬────────┘  │ External: 192.168.4.201       │    │
│            │           └───────────────────────────────┘    │
└────────────┼────────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────┐  ┌────────────────────────┐
│  Traefik Ingress       │  │  Cloudflare Tunnel     │
│  .chocolandiadc.local  │  │  .chocolandiadc.com    │
└────────────────────────┘  └────────────────────────┘

External Dependencies:
┌────────────────────┐  ┌────────────────────┐
│  PostgreSQL        │  │  Redis             │
│  192.168.4.204     │  │  192.168.4.203     │
│  Database: paperless│  │  Cache + Celery    │
└────────────────────┘  └────────────────────┘
```

## Referencias

- [Paperless-ngx Documentation](https://docs.paperless-ngx.com/)
- [Paperless-ngx GitHub](https://github.com/paperless-ngx/paperless-ngx)
