#!/bin/bash
# Práctica 4 - Otros exporters: Blackbox Exporter en la instancia de Prometheus
# Comprueba URLs con sondas HTTP y añade la alerta WebsiteDown.
# Pau López Núñez

source "$(dirname "$0")/config.sh"
BB_VERSION=0.24.0

titulo "Instalar Blackbox Exporter $BB_VERSION (binario, usuario y servicio)"
en $EC2_PROM "sudo bash -s" <<SCRIPT
set -e
cd /tmp
wget -q https://github.com/prometheus/blackbox_exporter/releases/download/v$BB_VERSION/blackbox_exporter-$BB_VERSION.linux-amd64.tar.gz
tar xfz blackbox_exporter-$BB_VERSION.linux-amd64.tar.gz
mv blackbox_exporter-$BB_VERSION.linux-amd64/blackbox_exporter /usr/local/bin/
mkdir -p /etc/blackbox
mv blackbox_exporter-$BB_VERSION.linux-amd64/blackbox.yml /etc/blackbox/
id blackbox &>/dev/null || useradd --no-create-home --shell /bin/false blackbox
chown -R blackbox:blackbox /etc/blackbox /usr/local/bin/blackbox_exporter
cat > /etc/systemd/system/blackbox_exporter.service <<'EOF2'
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox
Group=blackbox
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter --config.file=/etc/blackbox/blackbox.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF2
systemctl daemon-reload
systemctl enable --now blackbox_exporter
SCRIPT
mx $EC2_PROM "systemctl status blackbox_exporter --no-pager | head -n 3"
mx $EC2_PROM "head -n 8 /etc/blackbox/blackbox.yml"
mx $EC2_PROM "curl -s 'localhost:9115/probe?module=http_2xx&target=https://prometheus.io' | grep -E '^probe_(success|http_status_code|duration_seconds)'"

titulo "Job blackbox en prometheus.yml y alerta WebsiteDown"
en $EC2_PROM "sudo tee /etc/prometheus/prometheus.yml > /dev/null" < $DIR/config/prometheus-blackbox.yml
cat $DIR/config/alert.rules.completo.yml $DIR/config/alert.rules.blackbox.yml | en $EC2_PROM "sudo tee /etc/prometheus/alert.rules.yml > /dev/null"
mx $EC2_PROM "sudo chown prometheus:prometheus /etc/prometheus/*.yml"
mx $EC2_PROM "promtool check config /etc/prometheus/prometheus.yml"
mx $EC2_PROM "sudo systemctl restart prometheus && systemctl is-active prometheus"
