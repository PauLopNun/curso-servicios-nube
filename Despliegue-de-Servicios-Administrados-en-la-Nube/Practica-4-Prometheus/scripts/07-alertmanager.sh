#!/bin/bash
# Práctica 4 - Actividad 2: Alertmanager en la instancia de Prometheus, enviando por SNS
# (antes: ./05-sns.sh <correo> y confirmar la suscripción)
# Pau López Núñez

source "$(dirname "$0")/config.sh"
AM_VERSION=0.26.0

titulo "3. Abrir el puerto 9093 en el grupo de seguridad de Prometheus"
aws ec2 authorize-security-group-ingress --group-id $SG_PROM --protocol tcp --port 9093 --cidr $MI_IP \
    --query 'SecurityGroupRules[0].{Grupo:GroupId,Puerto:FromPort,Origen:CidrIpv4}' --output table

titulo "2. Instalar Alertmanager $AM_VERSION (binario, usuario y servicio)"
en $EC2_PROM "sudo bash -s" <<SCRIPT
set -e
cd /tmp
wget -q https://github.com/prometheus/alertmanager/releases/download/v$AM_VERSION/alertmanager-$AM_VERSION.linux-amd64.tar.gz
tar xfz alertmanager-$AM_VERSION.linux-amd64.tar.gz
mv alertmanager-$AM_VERSION.linux-amd64/{alertmanager,amtool} /usr/local/bin/
id alertmanager &>/dev/null || useradd --no-create-home --shell /bin/false alertmanager
mkdir -p /etc/alertmanager /var/lib/alertmanager
cat > /etc/systemd/system/alertmanager.service <<'EOF2'
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF2
SCRIPT
mx $EC2_PROM "alertmanager --version 2>&1 | head -n 1"

titulo "4. Receptor sns_configs con el ARN del tema"
sed "s|SNS_ARN|$SNS_ARN|" $DIR/config/alertmanager.yml | en $EC2_PROM "sudo tee /etc/alertmanager/alertmanager.yml > /dev/null"
mx $EC2_PROM "sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager"
mx $EC2_PROM "cat /etc/alertmanager/alertmanager.yml"
mx $EC2_PROM "amtool check-config /etc/alertmanager/alertmanager.yml"
mx $EC2_PROM "sudo systemctl daemon-reload && sudo systemctl enable --now alertmanager 2>&1; systemctl status alertmanager --no-pager | head -n 5"

titulo "5. Bloque alerting en prometheus.yml (localhost:9093)"
en $EC2_PROM "sudo tee /etc/prometheus/prometheus.yml > /dev/null" < $DIR/config/prometheus-alertmanager.yml
mx $EC2_PROM "cat /etc/prometheus/prometheus.yml"
mx $EC2_PROM "promtool check config /etc/prometheus/prometheus.yml"
mx $EC2_PROM "sudo systemctl restart prometheus && systemctl is-active prometheus"
mx $EC2_PROM "curl -s localhost:9090/api/v1/alertmanagers"
echo
echo "Alertmanager: http://$(ip_publica $EC2_PROM):9093"
