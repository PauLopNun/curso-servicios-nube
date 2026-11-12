#!/usr/bin/env bash
# Parte 3: simulacro de fallo del host forzando el estado de la alarma
source "$(dirname "$0")/config.sh"; LOG=03-simulacro-sistema.txt; : > "$EVID/$LOG"
run 'aws cloudwatch set-alarm-state --alarm-name mon-$OWNER-sistema \
  --state-value ALARM --state-reason "Simulacro de fallo del host"'
sleep 15
run 'aws ec2 describe-instances --instance-ids $ID \
  --query "Reservations[0].Instances[0].State.Name" --output text'
run 'aws cloudwatch describe-alarm-history --alarm-name mon-$OWNER-sistema \
  --output table --query "AlarmHistoryItems[].{Hora:Timestamp,Tipo:HistoryItemType,Resumen:HistorySummary}"'
