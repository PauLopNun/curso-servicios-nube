#!/usr/bin/env bash
# Parte 4: acciones de mon-pln-sistema tras dejarla como en producción
source "$(dirname "$0")/config.sh"; LOG=04b-alarma-sistema-produccion.txt; : > "$EVID/$LOG"
run 'aws cloudwatch describe-alarms --alarm-names mon-$OWNER-sistema \
  --query "MetricAlarms[0].AlarmActions" --output table'
