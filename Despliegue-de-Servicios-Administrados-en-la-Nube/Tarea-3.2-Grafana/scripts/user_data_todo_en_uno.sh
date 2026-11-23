#!/bin/bash
# Tarea 3.2 - Grafana. Una sola instancia con Node Exporter, Prometheus y Grafana.
# Deja preparados la fuente de datos, el dashboard y las tres alertas.
# Pau López Núñez

NODE_EXPORTER_VERSION="1.6.1"
PROMETHEUS_VERSION="2.47.0"
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

yum update -y
yum install -y wget stress-ng
cd /var/tmp

# Node Exporter (puerto 9100)
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
useradd --no-create-home --shell /bin/false nodeusr
cat <<'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target
[Service]
User=nodeusr
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# Prometheus (puerto 9090)
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
tar xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
cd "prometheus-${PROMETHEUS_VERSION}.linux-amd64"
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /var/lib/prometheus
mv prometheus promtool /usr/local/bin/
mv consoles console_libraries /etc/prometheus/
cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['${IP}:9100']
EOF
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
cat <<'EOF' > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network-online.target
[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now node_exporter prometheus

# Grafana (puerto 3000), con el repositorio del fichero user_data_grafana.txt
cat <<'EOF' > /etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
EOF
yum install -y grafana

# Fuente de datos: Prometheus por la IP privada
cat <<EOF > /etc/grafana/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://${IP}:9090
    isDefault: true
EOF

# Dashboard
mkdir -p /var/lib/grafana/dashboards
cat <<'EOF' > /etc/grafana/provisioning/dashboards/sistema.yml
apiVersion: 1
providers:
  - name: sistema
    folder: Practica
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF
panel() { # id título x y unidad umbral consultas
  local escala='' umbral='"thresholdsStyle":{"mode":"off"}' pasos='[{"color":"green","value":null}]'
  [ "$5" = percent ] && escala='"min":0,"max":100,'
  if [ -n "$6" ]; then
    umbral='"thresholdsStyle":{"mode":"line"}'
    pasos="[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":$6}]"
  fi
  echo "{\"id\":$1,\"title\":\"$2\",\"type\":\"timeseries\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":9,\"w\":12,\"x\":$3,\"y\":$4},\"fieldConfig\":{\"defaults\":{\"unit\":\"$5\",${escala}\"custom\":{\"lineWidth\":2,\"fillOpacity\":10,$umbral},\"thresholds\":{\"mode\":\"absolute\",\"steps\":$pasos}},\"overrides\":[]},\"options\":{\"legend\":{\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"multi\"}},\"targets\":[$7]}"
}
q() { echo "{\"refId\":\"$1\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"$2\",\"legendFormat\":\"$3\",\"range\":true}"; }
CPU='100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)'
MEM='(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100'
DISCO='(1 - node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100'
RX='rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])'
TX='rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])'
{
  echo '{"uid":"sistema-pln","title":"Sistema ec2-pln-grafana","schemaVersion":39,"refresh":"10s","time":{"from":"now-30m","to":"now"},"panels":['
  panel 1 "Uso de CPU" 0 0 percent 70 "$(q A "$CPU" '{{instance}}')"; echo ,
  panel 2 "Memoria utilizada" 12 0 percent 80 "$(q A "$MEM" '{{instance}}')"; echo ,
  panel 3 "Disco ocupado en /" 0 9 percent 75 "$(q A "$DISCO" '{{instance}}')"; echo ,
  panel 4 "Tráfico de red" 12 9 Bps "" "$(q A "$RX" '{{instance}} recibido'),$(q B "$TX" '{{instance}} enviado')"
  echo ']}'
} > /var/lib/grafana/dashboards/sistema.json

# Alertas: consulta (A), Reduce con Last (B) y Threshold (C), pendiente de 1 minuto
regla() { # uid título panel umbral consulta
cat <<EOF
      - uid: $1
        title: $2
        condition: C
        for: 1m
        noDataState: NoData
        execErrState: Error
        annotations:
          __dashboardUid__: sistema-pln
          __panelId__: "$3"
          summary: $2 por encima del $4 %
        data:
          - refId: A
            relativeTimeRange: {from: 600, to: 0}
            datasourceUid: prometheus
            model: {refId: A, expr: '${5//\\/}', range: true, intervalMs: 15000, maxDataPoints: 43200}
          - refId: B
            relativeTimeRange: {from: 0, to: 0}
            datasourceUid: __expr__
            model: {refId: B, type: reduce, expression: A, reducer: last, datasource: {type: __expr__, uid: __expr__}}
          - refId: C
            relativeTimeRange: {from: 0, to: 0}
            datasourceUid: __expr__
            model:
              refId: C
              type: threshold
              expression: B
              datasource: {type: __expr__, uid: __expr__}
              conditions:
                - evaluator: {type: gt, params: [$4]}
EOF
}
{
  printf 'apiVersion: 1\ngroups:\n  - orgId: 1\n    name: alertas-nodo\n    folder: Practica\n    interval: 1m\n    rules:\n'
  regla alerta-cpu "CPU alta" 1 70 "$CPU"
  regla alerta-memoria "Memoria alta" 2 80 "$MEM"
  regla alerta-disco "Disco casi lleno" 3 75 "$DISCO"
} > /etc/grafana/provisioning/alerting/alertas.yml

chown -R grafana:grafana /var/lib/grafana/dashboards
systemctl enable --now grafana-server
