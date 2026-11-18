#!/bin/bash
# Práctica 4 - Comprobaciones del enunciado en cada instancia
# Uso: ./03-comprobar.sh nodo|prometheus
# Pau López Núñez

source "$(dirname "$0")/config.sh"

case "$1" in
nodo)
    titulo "ec2_a: Node Exporter"
    mx $EC2_A "systemctl status node_exporter --no-pager | head -n 6"
    mx $EC2_A "curl -s http://localhost:9100/metrics | head -n 20"
    mx $EC2_A "curl -s http://localhost:9100/metrics | grep -c '^node_'"
    ;;
prometheus)
    titulo "prometheus: servicio y configuración"
    mx $EC2_PROM "systemctl status prometheus --no-pager | head -n 6"
    mx $EC2_PROM "cat /etc/prometheus/prometheus.yml"
    mx $EC2_PROM "promtool check config /etc/prometheus/prometheus.yml"
    mx $EC2_PROM "curl -s localhost:9090/api/v1/targets | python3 -c 'import json,sys; [print(t[\"labels\"][\"job\"], t[\"scrapeUrl\"], t[\"health\"]) for t in json.load(sys.stdin)[\"data\"][\"activeTargets\"]]'"
    ;;
*) echo "Uso: $0 nodo|prometheus"; exit 1 ;;
esac
