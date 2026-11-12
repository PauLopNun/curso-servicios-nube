#!/usr/bin/env bash
# Parte 2: activar la monitorización detallada
source "$(dirname "$0")/config.sh"; LOG=02b-monitorizacion-detallada.txt; : > "$EVID/$LOG"
run 'aws ec2 monitor-instances --instance-ids $ID'
