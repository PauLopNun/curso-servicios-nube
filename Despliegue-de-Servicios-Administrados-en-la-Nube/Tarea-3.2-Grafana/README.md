<div align="center">

# Tarea 3.2 - Visualización de datos con Grafana

![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)
![EC2](https://img.shields.io/badge/EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

Dashboard de Grafana sobre las métricas de Prometheus y tres alertas (CPU, memoria y disco) que se provocan y vuelven a Normal. Todo en una instancia `t3.small` con Node Exporter, Prometheus y Grafana.

## Despliegue

El script [`user_data_todo_en_uno.sh`](scripts/user_data_todo_en_uno.sh) instala Node Exporter y Prometheus, añade Grafana con el repositorio de [`user_data_grafana.txt`](scripts/user_data_grafana.txt) y deja preparados por *provisioning*:

- La fuente de datos `prometheus`, por la IP privada.
- El dashboard *Sistema ec2-pln-grafana*, con CPU, memoria, disco y red.
- El grupo de alertas `alertas-nodo`, evaluado cada minuto con un *pending period* de 1 minuto.

| Grupo `sec-pln-grafana` | Origen |
|:--|:--|
| 3000 (Grafana) | Mi IP pública |
| 9090 (Prometheus) y 9100 (Node Exporter) | El propio grupo |

## Alertas

| Alerta | Umbral | Prueba | Valor máximo | Ciclo |
|:--|:-:|:--|:-:|:--|
| CPU alta | 70 % | `stress-ng --cpu 2` 5 min | 97 % | Pending, Alerting, Normal |
| Memoria alta | 80 % | `stress-ng --vm --vm-populate --vm-hang 0` 6 min | 88 % | Pending, Alerting, Normal |
| Disco casi lleno | 75 % | `fallocate` hasta el 85 % | 85 % | Pending, Alerting, Normal |

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/user_data_todo_en_uno.sh`](scripts/user_data_todo_en_uno.sh) | Instalación completa con dashboard y alertas |
| [`scripts/user_data_grafana.txt`](scripts/user_data_grafana.txt) | Datos de usuario de Grafana del enunciado |
| [`evidencias/pruebas-alertas.txt`](evidencias/pruebas-alertas.txt) | Salidas de las pruebas y horas de cada cambio de estado |
| [`capturas/`](capturas) | Capturas de cada paso |
| [`entrega/grafana_t3.2_lopez_nunez.pdf`](entrega/grafana_t3.2_lopez_nunez.pdf) | Documento de entrega |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
