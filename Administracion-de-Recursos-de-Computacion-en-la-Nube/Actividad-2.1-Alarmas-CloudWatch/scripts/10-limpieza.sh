#!/usr/bin/env bash
# Parte 9: borrar lo que cuesta o sobra y detener la instancia (el resto se conserva)
source "$(dirname "$0")/config.sh"; LOG=10-limpieza.txt; : > "$EVID/$LOG"
run 'ASC=$(aws ec2 describe-application-status-checks --output text \
  --query "ApplicationStatusChecks[?Tags[?Key=='"'"'Name'"'"' && Value=='"'"'apache-$OWNER'"'"']].ApplicationStatusCheckId")
aws ec2 disassociate-application-status-check --application-status-check-id $ASC \
  --instance-ids $ID >/dev/null
aws ec2 delete-application-status-check --application-status-check-id $ASC && echo "apache-$OWNER ($ASC) borrada"'
run 'aws cloudwatch delete-alarms --alarm-names mon-$OWNER-cpu-cli'
run 'aws ec2 stop-instances --instance-ids $ID --output table \
  --query "StoppingInstances[].{ID:InstanceId,Antes:PreviousState.Name,Ahora:CurrentState.Name}"'
run 'aws cloudwatch describe-alarms --alarm-name-prefix mon-$OWNER --output table \
  --query "MetricAlarms[].{Nombre:AlarmName,Estado:StateValue}"'
