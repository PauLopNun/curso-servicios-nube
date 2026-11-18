<div align="center">

# Práctica 4 - Recogida de datos con Prometheus

![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)
![EC2](https://img.shields.io/badge/EC2-FF9900?style=for-the-badge&logoColor=white)
![SNS](https://img.shields.io/badge/SNS-FF4F8B?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

Monitorización de instancias EC2 con **Node Exporter** y **Prometheus**, consultas **PromQL**, alertas evaluadas por Prometheus y enviadas por correo con **Alertmanager** a través de un tema **SNS**. Todo se despliega con la AWS CLI desde los scripts de `scripts/`.

## Arquitectura final

```text
                 VPC por defecto · subred us-east-1a
 ┌──────────────────────────────────────────────────────────────┐
 │  prometheus (t3.micro, LabInstanceProfile)                   │
 │   ├─ Prometheus  :9090  ── ec2_sd_configs ──► API de EC2     │
 │   ├─ Alertmanager :9093 ── sns_configs ──► SNS ──► correo    │
 │   └─ Blackbox Exporter :9115 ── sondas HTTP ──► webs         │
 │                 │ pull /metrics cada 15 s                    │
 │                 ▼                                            │
 │  ec2-pln-nodo ×2, ec2-pln-nodo3  (Monitorizar=prometheus)    │
 │   └─ Node Exporter :9100                                     │
 └──────────────────────────────────────────────────────────────┘
```

| Grupo de seguridad | Puerto | Origen |
|:--|:-:|:--|
| `sec-pln-nodo` | 22 | Mi IP |
| `sec-pln-nodo` | 9100 | `sec-pln-prometheus` |
| `sec-pln-prometheus` | 22, 9090, 9093 | Mi IP |

## Scripts

| Script | Qué hace |
|:--|:--|
| `config.sh` | Región, AMI de Amazon Linux 2023, VPC y subred, y SSH con EC2 Instance Connect |
| `user_data_ec2.txt` / `user_data_prometheus.txt` | Datos de usuario del enunciado (Node Exporter 1.6.1 y Prometheus 2.47.0) |
| `01-nodo.sh` | Grupos de seguridad y nodo `ec2_a` |
| `02-prometheus.sh` | Sustituye `TARGET_IP` por la IP privada de `ec2_a` y lanza `prometheus` |
| `03-comprobar.sh nodo\|prometheus` | Comprobaciones del enunciado por SSH |
| `04-alerta-cpu.sh [stress]` | Regla `HighCPUUsage` y carga de CPU con `stress` |
| `05-sns.sh <correo>` | Tema `alertas-prometheus` con suscripción de correo |
| `06-etiquetas.sh [tercero]` | Actividad 1: `ec2_sd_configs` y nodos con la etiqueta `Monitorizar=prometheus` |
| `07-alertmanager.sh` | Actividad 2: Alertmanager 0.26.0 con receptor SNS |
| `08-reglas.sh [cpu\|caida\|memoria\|disco\|restaurar]` | Actividad 3: cuatro reglas y cómo provocar cada una |
| `09-blackbox.sh` | Otros exporters: Blackbox Exporter con sondas HTTP y alerta `WebsiteDown` |
| `10-limpiar.sh` | Borra todo lo creado |
| `config/` | `prometheus.yml` de cada fase, reglas y `alertmanager.yml` |

```bash
cd scripts
./01-nodo.sh && ./02-prometheus.sh && ./03-comprobar.sh nodo && ./03-comprobar.sh prometheus
./04-alerta-cpu.sh && ./04-alerta-cpu.sh stress
./05-sns.sh correo@ejemplo.com           # confirmar la suscripción en el correo
./06-etiquetas.sh && ./06-etiquetas.sh tercero
./07-alertmanager.sh && ./08-reglas.sh cpu
./08-reglas.sh && ./08-reglas.sh caida   # y luego memoria, disco, restaurar
./09-blackbox.sh
./10-limpiar.sh
```

## Resultados

- `ec2_a` en **UP** en Status > Targets y la alerta `HighCPUUsage` pasando por Inactive, Pending, Firing e Inactive.
- Actividad 1: los dos nodos con la etiqueta aparecen solos en **UP** y un tercero se añade sin tocar la configuración.
- Actividad 2: la alerta llega a Alertmanager y por correo, al dispararse (`[FIRING]`) y al resolverse (`[RESOLVED]`).
- PromQL: consultas básicas, `rate()`, agregación con `by`, `offset` y subconsultas `[15m:30s]`.
- Actividad 3: cuatro reglas cargadas; `InstanceDown` (critical), `HighMemoryUsage` y `LowDiskSpace` (warning) envían cada una su correo con la instancia afectada.
- Otros exporters: Blackbox Exporter sondea tres URL y la que no existe dispara `WebsiteDown`.

Las salidas de cada script están en `evidencias/`, las capturas en `capturas/` y el documento entregado en `entrega/`.

## Notas

- `~/.ssh/labsuser.pem` no corresponde a `vockey` en esta cuenta del laboratorio, así que se entra con **EC2 Instance Connect** (`send-ssh-public-key` con la clave propia).
- La regla de CPU agrupa por `instance, nombre, instance_id` en la actividad 3: con solo `instance` el correo no podía mostrar el nombre del nodo.
- El PDF `aws3_01_prometheus.pdf` está incompleto (11 páginas, el índice llega a la 12). Se siguieron las actividades de la presentación y se añadieron las subconsultas y Blackbox Exporter de ese índice.
- `/tmp` es `tmpfs` en Amazon Linux 2023: el fichero de relleno del disco se crea en `/var/tmp`.

---

[Volver a la asignatura](../README.md)
