# Creando un Dashboard de Homelab con Grafana: Un Estilo Inspirado en HomeDash

## Introduccion

Cuando se trata de monitorear un cluster Kubernetes en un homelab, los dashboards por defecto de Grafana cumplen su funcion, pero suelen verse muy utilitarios y les falta atractivo visual. Inspirado en el popular diseno HomeDash v3, me propuse crear un dashboard personalizado que sea tanto informativo como visualmente atractivo.

En este post, les voy a mostrar el dashboard **Chocolandia Homelab Overview** - un dashboard de Grafana personalizado disenado para monitorear un cluster K3s corriendo en mini PCs. Voy a cubrir las metricas que mostramos, el stack tecnologico que lo alimenta, y las personalizaciones que lo hacen destacar.

## El Stack Tecnologico

### Infraestructura
- **K3s v1.28**: Distribucion ligera de Kubernetes perfecta para homelabs
- **4 Intel NUC/Mini PCs**: Corriendo como nodos del cluster
- **MetalLB**: Para servicios LoadBalancer con IPs reales

### Stack de Monitoreo
- **kube-prometheus-stack** (Helm chart v55.5.0): La columna vertebral de nuestro monitoreo
  - **Prometheus**: Base de datos de series temporales que recolecta todas las metricas
  - **Grafana**: Visualizacion y dashboards
  - **node-exporter**: Metricas de hardware y sistema operativo de cada nodo
  - **kube-state-metrics**: Metricas del estado de objetos de Kubernetes
  - **Alertmanager**: Ruteo de alertas (configurado con notificaciones ntfy)

### Aplicaciones Monitoreadas
- **Pi-hole**: Bloqueo de publicidad y DNS a nivel de red
- **Traefik**: Controlador de ingress y reverse proxy
- **PostgreSQL HA**: Cluster de base de datos con CloudNativePG
- **ArgoCD**: Entrega continua con GitOps

## Secciones del Dashboard

### 1. Vista General del Cluster (Fila Superior)

La primera fila proporciona una vista rapida del estado del cluster con paneles stat que muestran **graficos sparkline detras de los valores** - un elemento visual clave tomado de HomeDash v3.

| Panel | Metrica | Color |
|-------|---------|-------|
| Nodes | `count(up{job=~".*node.*"} == 1)` | Verde |
| CPUs | `sum(count by (instance) (node_cpu_seconds_total{mode="idle"}))` | Azul |
| RAM | `sum(node_memory_MemTotal_bytes)` | Violeta |
| CPU % | `avg(100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))` | Gradiente verde-amarillo-rojo |
| RAM % | `avg((1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)` | Gradiente verde-amarillo-rojo |
| Disk % | `avg((1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)` | Gradiente azul-violeta |
| Temp | `max(node_hwmon_temp_celsius{chip=~".*coretemp.*"})` | Gradiente amarillo-naranja-rojo |
| Net RX/TX | `sum(rate(node_network_receive_bytes_total[5m]))` | Cyan/Verde |

### 2. Graficos de Series Temporales (Seccion Media)

Seis graficos mostrando datos historicos con **lineas suaves, rellenos con gradiente y leyendas en tabla**:

- **CPU Usage**: Porcentaje de utilizacion de CPU por nodo
- **Memory Usage**: Porcentaje de uso de RAM por nodo
- **Network I/O**: Trafico de red bidireccional (RX positivo, TX negativo)
- **Temperature**: Tendencias de temperatura de CPU por nodo
- **Load Average**: Promedio de carga de 1 minuto por nodo
- **Disk I/O**: Throughput de lectura/escritura por nodo

### 3. Visualizacion de Almacenamiento

- **Disk Usage by Node**: Barra horizontal mostrando porcentaje de uso de disco por nodo
- **CPU Temperature by Node**: Grafico timeseries convertido desde gauge para mejor visibilidad historica

### 4. Seccion de Aplicaciones

Aca es donde la inspiracion de HomeDash realmente brilla. Cada aplicacion tiene **3 paneles en un tema de color consistente**:

| Aplicacion | Color | Metrica de Status | Metrica 1 | Metrica 2 |
|------------|-------|-------------------|-----------|-----------|
| **Pi-hole** | Rosa (#ec4899) | Pod Running | DNS Traffic | Memory |
| **Traefik** | Cyan (#06b6d4) | Config Reload Success | Requests/s | Open Connections |
| **PostgreSQL** | Azul (#3b82f6) | Exporter Scrape OK | DB Size | Locks |
| **ArgoCD** | Verde (#22c55e) | Cluster Connection | Apps Count | Syncs/24h |

Los paneles de status muestran:
- **UP** en el color del tema de la app cuando esta saludable
- **DOWN** en rojo (#ef4444) cuando hay un problema

### 5. Tablas de Recursos

- **Top Pods by CPU**: Tabla mostrando los 10 pods que mas CPU consumen con visualizacion gauge
- **Node Hardware Inventory** (colapsado): Info detallada de hardware incluyendo Vendor, Model, IP, CPUs, RAM, Uptime, y porcentajes de CPU/RAM en tiempo real

## Personalizaciones Clave

### 1. Paneles Transparentes (Sin Bordes)

Cada panel tiene `"transparent": true` configurado, eliminando los bordes por defecto y creando un look moderno y sin costuras que se integra con el tema oscuro.

```json
{
  "transparent": true,
  "type": "stat"
}
```

### 2. Sparklines Detras de los Valores

Los paneles stat usan `colorMode: "background_solid"` con `graphMode: "area"` para mostrar mini graficos sparkline detras de los valores numericos:

```json
{
  "options": {
    "colorMode": "background_solid",
    "graphMode": "area",
    "textMode": "value_and_name"
  }
}
```

### 3. Rellenos con Gradiente de Color

Los graficos de series temporales tienen 35% de opacidad de relleno con modo gradiente para un look pulido:

```json
{
  "custom": {
    "fillOpacity": 35,
    "gradientMode": "opacity",
    "lineWidth": 1,
    "lineInterpolation": "smooth"
  }
}
```

### 4. Eje Y como Titulo

En lugar de titulos tradicionales arriba del grafico, usamos la etiqueta del eje Y como titulo, ahorrando espacio vertical:

```json
{
  "custom": {
    "axisLabel": "CPU Usage",
    "axisPlacement": "left"
  },
  "title": ""
}
```

### 5. Leyenda como Tabla Debajo de los Graficos

Las leyendas se muestran como tablas debajo del grafico con valores calculados (promedio, maximo):

```json
{
  "options": {
    "legend": {
      "displayMode": "table",
      "placement": "bottom",
      "calcs": ["mean", "max"]
    }
  }
}
```

### 6. Gradientes de Color Continuos

Para stats basados en porcentajes, usamos los modos de color continuo de Grafana para gradientes suaves:

```json
{
  "color": {
    "mode": "continuous-GrYlRd"  // Verde -> Amarillo -> Rojo
  }
}
```

Modos disponibles: `continuous-GrYlRd`, `continuous-BlPu`, `continuous-YlRd`

### 7. Mapeos de Valores para Status

Los paneles de status mapean valores numericos a texto significativo con colores apropiados:

```json
{
  "mappings": [{
    "type": "value",
    "options": {
      "0": { "text": "DOWN", "color": "#ef4444" },
      "1": { "text": "UP", "color": "#ec4899" }
    }
  }]
}
```

### 8. Deduplicando Datos de Nodos

Cuando combinamos metricas de multiples fuentes, usamos `max by (nodename)` para prevenir entradas duplicadas:

```promql
max by (nodename) (
  (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100
  * on(instance) group_left(nodename) node_uname_info
)
```

## Arquitectura de Despliegue

El dashboard se despliega como Infraestructura como Codigo usando **OpenTofu**:

```hcl
resource "kubernetes_config_map" "homelab_overview_dashboard" {
  metadata {
    name      = "homelab-overview-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"  # Detectado por el sidecar de Grafana
    }
  }

  data = {
    "homelab-overview.json" = file("${path.module}/../../dashboards/homelab-overview.json")
  }
}
```

El contenedor sidecar de Grafana automaticamente descubre ConfigMaps con el label `grafana_dashboard: "1"` y los carga como dashboards.

## El Resultado

El dashboard final proporciona:

1. **Visibilidad instantanea del estado del cluster** - Una mirada te dice si todo esta funcionando
2. **Tendencias historicas** - Graficos suaves muestran patrones a lo largo del tiempo
3. **Estado de aplicaciones** - Ves rapidamente si Pi-hole, Traefik, PostgreSQL y ArgoCD estan saludables
4. **Detalles de recursos bajo demanda** - Secciones colapsadas para cuando necesitas profundizar
5. **Estetica hermosa** - Un dashboard que realmente queres mirar

## Referencia de Fuentes de Metricas

| Prefijo de Metrica | Fuente | Descripcion |
|--------------------|--------|-------------|
| `node_*` | node-exporter | Metricas de hardware (CPU, memoria, disco, red, temperatura) |
| `kube_*` | kube-state-metrics | Estados de objetos de Kubernetes (pods, deployments) |
| `container_*` | cAdvisor (kubelet) | Uso de recursos de contenedores |
| `traefik_*` | Traefik | Metricas del controlador de ingress |
| `pg_*` | PostgreSQL Exporter | Metricas de base de datos |
| `argocd_*` | ArgoCD | Metricas de aplicaciones GitOps |

## Conclusion

Construir un dashboard personalizado de Grafana toma tiempo, pero el resultado vale la pena. Combinando el poder de las metricas de Prometheus con las capacidades de visualizacion de Grafana y algunas personalizaciones creativas, podes crear una experiencia de monitoreo que es funcional y hermosa a la vez.

Los puntos clave:
- **Usa paneles transparentes** para un look moderno sin bordes
- **Habilita sparklines** en paneles stat para tendencias de un vistazo
- **Aplica rellenos con gradiente** a las series temporales para profundidad visual
- **Agrupa paneles relacionados por color** para parseo visual rapido
- **Usa joins de PromQL** (`on() group_left()`) para combinar metricas con labels de nodos

Sientete libre de usar esto como inspiracion para tu propio dashboard de homelab. El JSON completo esta disponible en mi repositorio de GitHub.

---

*Este dashboard fue creado para el Homelab Chocolandia corriendo en K3s con kube-prometheus-stack. Construido con amor y mucho tweaking de JSON de Grafana.*
