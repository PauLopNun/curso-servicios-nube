#!/usr/bin/env bash
# Ampliación: copia de la alarma de CPU creada con put-metric-alarm
source "$(dirname "$0")/config.sh"; LOG=09-ampliacion-cli.txt; : > "$EVID/$LOG"
run 'aws cloudwatch put-metric-alarm --alarm-name mon-$OWNER-cpu-cli \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$ID \
  --statistic Average --period 60 --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 5 --datapoints-to-alarm 3 \
  --treat-missing-data missing \
  --alarm-actions $TOPIC --ok-actions $TOPIC'
run 'aws cloudwatch describe-alarms --alarm-name-prefix mon-$OWNER-cpu --output table \
  --query "MetricAlarms[].{Nombre:AlarmName,Metrica:MetricName,Est:Statistic,Per:Period,Umbral:Threshold,Op:ComparisonOperator,M:DatapointsToAlarm,N:EvaluationPeriods,Ausentes:TreatMissingData}"'
run 'aws cloudwatch describe-alarms --alarm-names mon-$OWNER-sistema mon-$OWNER-instancia \
  --output table --query "MetricAlarms[].{Nombre:AlarmName,Acciones:join('"'"', '"'"',AlarmActions)}"'
