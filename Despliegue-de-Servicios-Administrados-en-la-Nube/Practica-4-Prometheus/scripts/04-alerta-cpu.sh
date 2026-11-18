#!/bin/bash
# Práctica 4 - Alerta HighCPUUsage: sube la configuración y la regla a Prometheus,
# las valida con promtool y reinicia el servicio.
# Uso: ./04-alerta-cpu.sh            -> configurar
#      ./04-alerta-cpu.sh stress     -> generar carga en ec2_a durante 300 s
# Pau López Núñez

source "$(dirname "$0")/config.sh"

if [ "$1" = "stress" ]; then
    titulo "Carga de CPU en ec2_a"
    mx $EC2_A "sudo yum install stress -y 2>&1 | tail -n 3"
    if en $EC2_A "command -v stress" > /dev/null; then
        mx $EC2_A 'nproc; stress --cpu $(nproc) --timeout 300'
    else
        echo "# stress no está en los repositorios de Amazon Linux 2023: se usa la alternativa del enunciado"
        mx $EC2_A 'nproc; for i in $(seq $(nproc)); do timeout 300 yes > /dev/null & done; sleep 5; top -bn1 | head -n 12; wait'
    fi
    exit 0
fi

titulo "Subir prometheus.yml (con rule_files) y alert.rules.yml"
sed "s/TARGET_IP/$(ip_privada $EC2_A)/" $DIR/config/prometheus-alertas.yml | en $EC2_PROM "sudo tee /etc/prometheus/prometheus.yml > /dev/null"
en $EC2_PROM "sudo tee /etc/prometheus/alert.rules.yml > /dev/null" < $DIR/config/alert.rules.yml
mx $EC2_PROM "cat /etc/prometheus/prometheus.yml"
mx $EC2_PROM "cat /etc/prometheus/alert.rules.yml"

titulo "Validar y reiniciar"
mx $EC2_PROM "sudo chown prometheus:prometheus /etc/prometheus/alert.rules.yml"
mx $EC2_PROM "promtool check config /etc/prometheus/prometheus.yml"
mx $EC2_PROM "sudo systemctl restart prometheus"
mx $EC2_PROM "systemctl status prometheus --no-pager | head -n 5"
