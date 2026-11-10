#!/usr/bin/env bash
# Pasos 2 y 3: volumen raíz, zona de disponibilidad y particiones dentro de la instancia
set -euo pipefail
source "$(dirname "$0")/config.sh"
LOG="$EVID/02-informacion.txt"; : > "$LOG"

run aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Id:InstanceId,Nombre:Tags[?Key==`Name`]|[0].Value,Tipo:InstanceType,Zona:Placement.AvailabilityZone,DispositivoRaiz:RootDeviceName,VolumenRaiz:BlockDeviceMappings[0].Ebs.VolumeId}' \
  --output table

VOLUMEN=$(aws ec2 describe-instances --instance-ids "$INSTANCIA" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text)
ZONA=$(aws ec2 describe-instances --instance-ids "$INSTANCIA" \
  --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)
echo "INSTANCIA=$INSTANCIA" > "$ESTADO"; echo "VOLUMEN=$VOLUMEN" >> "$ESTADO"; echo "ZONA=$ZONA" >> "$ESTADO"

run aws ec2 describe-volumes --volume-ids "$VOLUMEN"

en_instancia sudo lsblk
en_instancia df -hT
