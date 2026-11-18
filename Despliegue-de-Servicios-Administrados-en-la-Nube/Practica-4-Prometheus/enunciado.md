# Práctica 4: recogida de datos con Prometheus

- Documentos originales: `aws3_01_prometheus.pdf` y `Práctica 4 · Recogida de datos con Prometheus.pdf` (en `Materiales/` de la asignatura, fuera del repositorio)
- Ficheros de datos de usuario: `user_data_ec2.txt` y `user_data_prometheus.txt` (Amazon Linux)

Primera práctica de una serie de tres: Prometheus (recogida), Grafana (visualización) y Athena (integración con AWS).

## Práctica guiada

1. **Nodo a monitorizar (`ec2_a`)**: grupo de seguridad con 22 desde mi IP y 9100 desde el grupo de Prometheus.
   Instancia Amazon Linux con `user_data_ec2.txt` (Node Exporter 1.6.1, usuario `nodeusr`, servicio de systemd).
   Comprobar con `systemctl status node_exporter` y `curl -s http://localhost:9100/metrics | head -n 20`.
2. **Servidor Prometheus**: grupo de seguridad con 22 y 9090 desde mi IP. Sustituir `<IP-DE-LA-OTRA-EC2>`
   por la IP privada de `ec2_a` en `user_data_prometheus.txt` y lanzar en la misma VPC (Prometheus 2.47.0).
   Comprobar con `systemctl status prometheus`, `promtool check config` y **Status > Targets** en `UP`.
3. **PromQL**: `up`, `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_disk_read_bytes_total`,
   `rate()`, agregación con `avg by`, `offset` y las consultas de memoria, disco y red.
4. **Alerta `HighCPUUsage`**: CPU > 70 % durante 1 min (`severity: critical`), en `/etc/prometheus/alert.rules.yml`
   con `rule_files` en `prometheus.yml`. Validar, reiniciar y provocarla con `stress --cpu $(nproc) --timeout 300`:
   Inactive, Pending, Firing y vuelta a Inactive.

## Actividades

| Nº | Actividad | Qué se pide |
|:-:|:--|:--|
| 1 | Monitorización por etiquetas | Eliminar `ec2_a`, asociar `LabInstanceProfile` a Prometheus, cambiar `static_configs` por `ec2_sd_configs` (etiqueta `Monitorizar=prometheus`), validar, reiniciar y lanzar dos instancias a la vez con la etiqueta. Comprobar dos targets en UP, `up{job="node_exporter"}` con dos series y que una tercera instancia aparece sola. |
| 2 | Alertmanager | Tema SNS con suscripción de correo confirmada, Alertmanager en la instancia de Prometheus (binario, usuario y servicio), puerto 9093, receptor `sns_configs` con el ARN del tema y bloque `alerting` en `prometheus.yml`. Provocar la alerta: aparece en Alertmanager y llega un correo al dispararse y otro al resolverse. |
| 3 | Nuevas reglas de alerta | `InstanceDown` (up, 1m, critical), `HighMemoryUsage` (> 80 %, 2m, warning) y `LowDiskSpace` (/ > 80 %, 2m, warning). Probar cada expresión, validar con `promtool check rules`, ver cuatro reglas en Status > Rules y provocarlas de una en una. Un correo por alerta, con la instancia, distinguiendo warning de critical. |

Al terminar: dos nodos descubiertos por etiqueta en UP, cuatro reglas cargadas y un correo por cada alerta que se dispara.

Limitaciones del laboratorio: solo `us-east-1`/`us-west-2`, sin crear roles (se usa `LabInstanceProfile`), SNS sí y SES no.
