#!/bin/bash
# Crea las alarmas de CPU, memoria y disco de una instancia.
# Uso: bash alarmas.sh <nombre-de-la-instancia>
NOMBRE=$1
ID=$(aws ec2 describe-instances \
   --filters "Name=tag:Name,Values=$NOMBRE" \
             "Name=instance-state-name,Values=running" \
   --query "Reservations[0].Instances[0].InstanceId" --output text)
if [ "$ID" = "None" ]; then
   echo "No encuentro $NOMBRE en marcha"; exit 1
fi
TEMA=$(aws sns list-topics --output text \
   --query "Topics[?ends_with(TopicArn, ':web-pln-avisos')].TopicArn")
ETIQUETAS="Key=Proyecto,Value=UD02 Key=Propietario,Value=pln"

# CPU: media de 1 minuto por encima del 70 % en 2 de 3
aws cloudwatch put-metric-alarm --alarm-name $NOMBRE-cpu \
  --alarm-description "CPU de $NOMBRE por encima del 70 %" \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$ID \
  --statistic Average --period 60 \
  --evaluation-periods 3 --datapoints-to-alarm 2 \
  --threshold 70 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions $TEMA --ok-actions $TEMA \
  --tags $ETIQUETAS

# Memoria: igual que la CPU, con la métrica del agente
aws cloudwatch put-metric-alarm --alarm-name $NOMBRE-mem \
  --alarm-description "Memoria de $NOMBRE por encima del 70 %" \
  --namespace CWAgent --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value=$ID \
  --statistic Average --period 60 \
  --evaluation-periods 3 --datapoints-to-alarm 2 \
  --threshold 70 --comparison-operator GreaterThanThreshold \
  --treat-missing-data breaching \
  --alarm-actions $TEMA --ok-actions $TEMA \
  --tags $ETIQUETAS

# Disco: máximo de 5 minutos por encima del 85 %
aws cloudwatch put-metric-alarm --alarm-name $NOMBRE-disco \
  --alarm-description "Disco / de $NOMBRE por encima del 85 %" \
  --namespace CWAgent --metric-name disk_used_percent \
  --dimensions Name=InstanceId,Value=$ID \
               Name=path,Value=/ Name=fstype,Value=ext4 \
  --statistic Maximum --period 300 \
  --evaluation-periods 1 --datapoints-to-alarm 1 \
  --threshold 85 --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --alarm-actions $TEMA --tags $ETIQUETAS

echo "Alarmas de $NOMBRE ($ID) creadas"
