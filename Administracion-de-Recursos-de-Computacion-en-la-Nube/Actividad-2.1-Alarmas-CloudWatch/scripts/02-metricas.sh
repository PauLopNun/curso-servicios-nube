#!/usr/bin/env bash
# Parte 2: métricas de EC2 desde la CLI (monitorización básica)
source "$(dirname "$0")/config.sh"; LOG=${LOG:-02-metricas.txt}; : > "$EVID/$LOG"
run 'aws cloudwatch list-metrics --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=$ID \
  --query "Metrics[].MetricName" --output text | tr '"'"'\t'"'"' '"'"'\n'"'"' | sort'
run 'INI=$(date -u -d '"'"'-1 hour'"'"' +%FT%TZ)
FIN=$(date -u +%FT%TZ)
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUUtilization --dimensions Name=InstanceId,Value=$ID \
  --start-time $INI --end-time $FIN --period 300 \
  --statistics Average Maximum --output table \
  --query "sort_by(Datapoints,&Timestamp)[].{Hora:Timestamp,Media:Average,Max:Maximum}"'
run 'aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUUtilization --dimensions Name=InstanceId,Value=$ID \
  --start-time $INI --end-time $FIN --period 60 \
  --statistics Average Maximum --output table \
  --query "sort_by(Datapoints,&Timestamp)[].{Hora:Timestamp,Media:Average,Max:Maximum}"'
run 'aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name StatusCheckFailed_System --dimensions Name=InstanceId,Value=$ID \
  --start-time $INI --end-time $FIN --period 60 \
  --statistics Maximum --output table \
  --query "sort_by(Datapoints,&Timestamp)[].{Hora:Timestamp,Max:Maximum}"'
