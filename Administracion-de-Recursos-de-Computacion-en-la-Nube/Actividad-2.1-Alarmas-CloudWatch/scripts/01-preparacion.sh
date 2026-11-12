#!/usr/bin/env bash
# Parte 1: ID de la instancia y comprobación de Apache
source "$(dirname "$0")/config.sh"; LOG=01-preparacion.txt; : > "$EVID/$LOG"
run 'OWNER=pln
ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mon-$OWNER" \
  "Name=instance-state-name,Values=pending,running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)
echo $ID'
run 'aws ec2 describe-instances --instance-ids $ID --output table \
  --query "Reservations[0].Instances[0].{ID:InstanceId,Estado:State.Name,Tipo:InstanceType,IP:PublicIpAddress}"'
run 'IP=$(aws ec2 describe-instances --instance-ids $ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
curl -sI http://$IP | head -3'
