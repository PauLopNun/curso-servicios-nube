#!/usr/bin/env bash
# Parte 5: estado e historial de las alarmas y créditos de CPU tras stress-ng
source "$(dirname "$0")/config.sh"; LOG=05-cpu-cli.txt; : > "$EVID/$LOG"
run 'aws cloudwatch describe-alarms --alarm-name-prefix mon-$OWNER \
  --output table --query "MetricAlarms[].{Nombre:AlarmName,Estado:StateValue,Metrica:MetricName}"'
run 'aws cloudwatch describe-alarm-history --alarm-name mon-$OWNER-cpu \
  --history-item-type StateUpdate --output table \
  --query "AlarmHistoryItems[].{Hora:Timestamp,Resumen:HistorySummary}"'
run 'INI=$(date -u -d '"'"'-40 minutes'"'"' +%FT%TZ)
FIN=$(date -u +%FT%TZ)
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUCreditBalance --dimensions Name=InstanceId,Value=$ID \
  --start-time $INI --end-time $FIN --period 300 --statistics Average \
  --output table --query "sort_by(Datapoints,&Timestamp)[].{Hora:Timestamp,Creditos:Average}"'
