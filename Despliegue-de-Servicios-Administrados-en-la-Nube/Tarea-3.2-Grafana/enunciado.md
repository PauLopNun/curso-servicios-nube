# Tarea 3.2: Visualización de datos con Grafana

- Curso: Despliegue de servicios administrados en la nube
- Documentos originales: `Materiales/aws3_02_grafana.pdf` y `Materiales/Visualización de datos con Grafana.pdf` (local)

## Partes

1. Instancia con Grafana (2 GB de memoria) y grupos de seguridad: 3000 para Grafana, 9090 para Prometheus y 9100 para Node Exporter
2. Primer acceso con `admin`/`admin` y cambio de contraseña
3. Fuente de datos Prometheus por la IP privada
4. Dashboard con paneles de CPU, memoria, disco y red
5. Alerta de CPU desde el panel: Reduce con Last, umbral 70 y pending period de 1 minuto, y provocarla con `stress`

## Actividades

1. Dashboard con tres instancias y tráfico de red
2. Alerta de disco al 75 %, visible en el panel
3. Alerta de memoria al 80 %, visible en el panel

Por indicación del profesor, se hace con una sola instancia y tres métricas vigiladas, cada una con su alerta, en lugar de tres instancias.
