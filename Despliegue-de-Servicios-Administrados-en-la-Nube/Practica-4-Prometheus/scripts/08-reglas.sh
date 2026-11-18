#!/bin/bash
# Práctica 4 - Actividad 3: nuevas reglas (InstanceDown, HighMemoryUsage, LowDiskSpace)
# Uso: ./08-reglas.sh                 -> subir y validar las reglas
#      ./08-reglas.sh cpu|caida|memoria|disco|restaurar  -> provocar cada alerta en el primer nodo
# Pau López Núñez

source "$(dirname "$0")/config.sh"
NODO=${NODOS%% *}   # primer nodo descubierto por etiqueta

case "$1" in
"")
    titulo "Probar las expresiones (API de consultas, igual que la pestaña Graph)"
    for q in 'up{job="node_exporter"}' \
             '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100' \
             '(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100'; do
        echo "# $q"
        en $EC2_PROM "curl -s localhost:9090/api/v1/query --data-urlencode 'query=$q'" \
            | python3 -c 'import json,sys; [print("  ", r["metric"].get("nombre"), r["metric"].get("instance"), "=", round(float(r["value"][1]),2)) for r in json.load(sys.stdin)["data"]["result"]]'
    done
    titulo "Subir alert.rules.yml con las cuatro reglas"
    en $EC2_PROM "sudo tee /etc/prometheus/alert.rules.yml > /dev/null" < $DIR/config/alert.rules.completo.yml
    mx $EC2_PROM "sudo chown prometheus:prometheus /etc/prometheus/alert.rules.yml"
    mx $EC2_PROM "promtool check rules /etc/prometheus/alert.rules.yml"
    mx $EC2_PROM "sudo systemctl restart prometheus && systemctl is-active prometheus"

    titulo "Plantilla del correo: nombre del nodo e id de instancia solo si existen"
    sed "s|SNS_ARN|$SNS_ARN|" $DIR/config/alertmanager.yml | en $EC2_PROM "sudo tee /etc/alertmanager/alertmanager.yml > /dev/null"
    mx $EC2_PROM "amtool check-config /etc/alertmanager/alertmanager.yml | head -n 1"
    mx $EC2_PROM "sudo systemctl restart alertmanager && systemctl is-active alertmanager"
    ;;
cpu)
    titulo "HighCPUUsage: carga de CPU 300 s en $NODO (prueba de la actividad 2)"
    mx $NODO 'sudo yum install stress -y -q; nproc; stress --cpu $(nproc) --timeout 300'
    ;;
caida)
    titulo "InstanceDown: parar Node Exporter (no la instancia)"
    mx $NODO "sudo systemctl stop node_exporter; systemctl is-active node_exporter"
    ;;
memoria)
    titulo "HighMemoryUsage: ocupar la memoria durante 5 min"
    mx $NODO "free -m"
    mx $NODO 'sudo yum install stress -y -q; LIBRE=$(awk "/MemAvailable/ {print int(\$2*0.92/1024)}" /proc/meminfo); echo "stress --vm 1 --vm-bytes ${LIBRE}M --vm-keep --timeout 300"; stress --vm 1 --vm-bytes ${LIBRE}M --vm-keep --timeout 300'
    ;;
disco)
    titulo "LowDiskSpace: rellenar el disco / (en /var/tmp: /tmp es tmpfs en memoria en AL2023)"
    mx $NODO "df -h /"
    mx $NODO 'TAM=$(df --output=size,used -B1M / | awk "NR==2 {print int(\$1*0.88-\$2)}"); echo "fallocate -l ${TAM}M /var/tmp/relleno"; sudo fallocate -l ${TAM}M /var/tmp/relleno; df -h /'
    ;;
restaurar)
    titulo "Dejar el nodo como estaba"
    mx $NODO "sudo rm -f /var/tmp/relleno; sudo systemctl start node_exporter; systemctl is-active node_exporter; df -h /"
    ;;
esac
