#!/usr/bin/env bash
# Parte 2: CPU con periodo de 60 s tras activar la monitorización detallada
source "$(dirname "$0")/config.sh"; LOG=02c-cpu-detallada.txt; : > "$EVID/$LOG"
run 'aws ec2 describe-instances --instance-ids $ID \
  --query "Reservations[0].Instances[0].Monitoring.State" --output text'
run 'INI=$(date -u -d '"'"'-15 minutes'"'"' +%FT%TZ)
FIN=$(date -u +%FT%TZ)
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUUtilization --dimensions Name=InstanceId,Value=$ID \
  --start-time $INI --end-time $FIN --period 60 \
  --statistics Average Maximum --output table \
  --query "sort_by(Datapoints,&Timestamp)[].{Hora:Timestamp,Media:Average,Max:Maximum}"'
