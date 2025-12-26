# Automatizando el Cooling del Rack con Govee, Home Assistant y Prometheus

Cuando tenes un homelab corriendo 24/7 en un rack, el control de temperatura se vuelve critico. Los mini PCs generan calor, y sin un sistema de ventilacion adecuado, las temperaturas pueden subir rapidamente afectando el rendimiento y la vida util del hardware.

En este post les cuento como integre un enchufe inteligente Govee con Home Assistant para encender automaticamente un ventilador de rack cuando la temperatura de CPU supera cierto umbral. Lo interesante es que toda la logica se basa en metricas que ya estaba recolectando con Prometheus para mis dashboards de Grafana.

**El objetivo principal fue aprender como automatizar acciones fisicas (prender un ventilador) basandome en metricas de monitoreo de infraestructura.**

---

## La Arquitectura

[INSERTAR IMAGEN: architecture-diagram.png]

El flujo es asi:

1. **node_exporter** corre en cada nodo y expone la temperatura de CPU
2. **Prometheus** recolecta y almacena esas metricas
3. **Home Assistant** lee las metricas de Prometheus usando una integracion
4. Cuando la temperatura supera el umbral, Home Assistant envia un comando via **MQTT**
5. **govee2mqtt** recibe el comando y controla el enchufe Govee
6. El enchufe enciende el ventilador del rack

---

## El Stack Tecnologico

### Monitoreo

- **[Prometheus](https://prometheus.io/)** — Base de datos de series temporales
- **[node_exporter](https://github.com/prometheus/node_exporter)** — Exporta metricas de hardware incluyendo temperatura de CPU
- **[Grafana](https://grafana.com/)** — Visualizacion de dashboards
- **[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)** — Helm chart que instala todo el stack de monitoreo

### Automatizacion

- **[Home Assistant](https://www.home-assistant.io/)** — Plataforma de automatizacion del hogar
- **[HACS](https://hacs.xyz/)** — Home Assistant Community Store para instalar integraciones de la comunidad
- **[ha-prometheus-sensor](https://github.com/binarylogicllc/ha-prometheus-sensor)** — Integracion para leer metricas de Prometheus directamente en Home Assistant

### Comunicacion IoT

- **[Mosquitto](https://mosquitto.org/)** — Broker MQTT open source
- **[govee2mqtt](https://github.com/wez/govee2mqtt)** — Bridge entre dispositivos Govee y MQTT/Home Assistant

### Hardware

- **Govee H5083** — Enchufe inteligente WiFi ([Govee Developer API](https://developer.govee.com/))

---

## Como Funciona

### Paso 1: Recoleccion de Metricas

`node_exporter` corre en cada nodo del cluster K3s y expone metricas de hardware. La metrica de temperatura de CPU se ve asi:

```
node_hwmon_temp_celsius{chip=~".*coretemp.*"}
```

Prometheus scrappea estas metricas cada 15 segundos y las almacena. Las mismas metricas alimentan mis dashboards de Grafana.

### Paso 2: Home Assistant Lee Prometheus

Usando la integracion **ha-prometheus-sensor** (instalada via HACS), Home Assistant puede leer directamente las metricas de Prometheus. Esto crea un sensor llamado "Node CPU Temperature" dentro de Home Assistant.

La ventaja de este approach es que reutilizas las mismas metricas que ya tenes para tus dashboards de Grafana. No hay duplicacion de datos ni configuracion adicional de sensores.

### Paso 3: Govee2MQTT Descubre Dispositivos

`govee2mqtt` es un bridge que conecta dispositivos Govee con Home Assistant via MQTT. Al iniciarse:

- Se autentica con la API de Govee usando tu API key
- Descubre todos tus dispositivos Govee automaticamente
- Los publica como entidades en Home Assistant via MQTT
- Soporta control local (LAN) para menor latencia

El enchufe Govee H5083 aparece automaticamente en Home Assistant como un switch.

### Paso 4: La Automatizacion

[INSERTAR IMAGEN: automation-flow.png]

En Home Assistant → Settings → Automations, configure dos automatizaciones simples:

**Encender ventilador:** Cuando la temperatura >= 50°C

**Apagar ventilador:** Cuando la temperatura < 49°C

La diferencia de 1°C entre encendido y apagado es intencional. Esto se llama histeresis y evita que el ventilador este prendiendo y apagando constantemente cuando la temperatura oscila alrededor del umbral.

Ejemplo conceptual del YAML:

```yaml
automation:
  - alias: "Rack Cooling ON"
    trigger:
      - platform: numeric_state
        entity_id: sensor.node_cpu_temperature
        above: 50
    action:
      - service: switch.turn_on
        target:
          entity_id: switch.govee_h5083_plug

  - alias: "Rack Cooling OFF"
    trigger:
      - platform: numeric_state
        entity_id: sensor.node_cpu_temperature
        below: 49
    action:
      - service: switch.turn_off
        target:
          entity_id: switch.govee_h5083_plug
```

---

## Despliegue en Kubernetes

Todo el stack corre en un cluster K3s y esta desplegado con OpenTofu (fork open source de Terraform):

- **Home Assistant**: Deployment con PersistentVolume para configuracion
- **Mosquitto**: Deployment con ConfigMap y PersistentVolume
- **govee2mqtt**: Deployment con `hostNetwork: true` para descubrimiento LAN

El detalle importante es que govee2mqtt necesita acceso a la red del host para poder descubrir dispositivos Govee en la LAN local usando multicast/broadcast.

---

## Por Que Este Approach?

### Ventajas

**Reutilizacion de metricas.** Las mismas metricas de Prometheus que uso para dashboards ahora disparan acciones fisicas. No necesito sensores adicionales.

**Descubrimiento automatico.** govee2mqtt detecta dispositivos sin configuracion manual. Solo necesitas el API key de Govee.

**Control local.** Menor latencia y funciona sin internet para dispositivos con soporte LAN.

**Escalabilidad.** Puedo agregar mas automatizaciones basadas en cualquier metrica de Prometheus (uso de disco, memoria, etc).

### Alternativas Consideradas

- **Grafana Alerting + Webhook a Home Assistant**: Funcionaria, pero agrega complejidad. Grafana no esta disenado para controlar dispositivos.
- **Sensor de temperatura Govee dedicado**: Podria usar un sensor Govee, pero ya tengo las metricas en Prometheus.

---

## Como Replicar Esto

Si queres implementar algo similar, estos son los pasos clave:

1. **Obtene tu Govee API Key**: En la app Govee → Perfil → About Us → Apply for API Key

2. **Instala HACS en Home Assistant**: Es el gateway a integraciones de la comunidad como ha-prometheus-sensor

3. **Asegurate de tener metricas de temperatura**: `node_exporter` debe estar corriendo en tus nodos con acceso a sensores de hardware

4. **Configura govee2mqtt**: Necesita estar en la misma red LAN que tus dispositivos Govee para control local

5. **Crea las automatizaciones**: En Home Assistant → Settings → Automations

---

## Conclusiones

Esta integracion demuestra como un stack de monitoreo de infraestructura (Prometheus/Grafana) puede extenderse para controlar el mundo fisico. La clave es **ha-prometheus-sensor** que actua como puente entre el mundo de DevOps y el mundo de home automation.

No es la unica forma de hacerlo, pero me gusto porque reutiliza infraestructura existente sin agregar sensores dedicados.

---

## Links de Referencia

- [Home Assistant](https://www.home-assistant.io/)
- [govee2mqtt](https://github.com/wez/govee2mqtt)
- [ha-prometheus-sensor](https://github.com/binarylogicllc/ha-prometheus-sensor)
- [HACS - Home Assistant Community Store](https://hacs.xyz/)
- [Mosquitto MQTT Broker](https://mosquitto.org/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Govee Developer API](https://developer.govee.com/)

---

*Esta integracion fue creada para el Homelab Chocolandia. Un experimento para aprender como conectar el monitoreo de infraestructura con automatizacion del hogar.*
