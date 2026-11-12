#!/usr/bin/env bash
# Parte 3: evolución de la alarma con la instancia detenida y nuevo arranque
source "$(dirname "$0")/config.sh"; LOG=03b-historial-sistema.txt; : > "$EVID/$LOG"
run 'aws cloudwatch describe-alarm-history --alarm-name mon-$OWNER-sistema \
  --history-item-type StateUpdate --output table \
  --query "AlarmHistoryItems[].{Hora:Timestamp,Resumen:HistorySummary}"'
run 'aws ec2 start-instances --instance-ids $ID --output table \
  --query "StartingInstances[].{ID:InstanceId,Antes:PreviousState.Name,Ahora:CurrentState.Name}"'
