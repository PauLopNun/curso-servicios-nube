#!/usr/bin/env bash
# Paso 7 y limpieza: borrar la copia de seguridad y terminar la instancia
set -euo pipefail
source "$(dirname "$0")/config.sh"
LOG="$EVID/06-limpiar.txt"; : > "$LOG"

run aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT"
run aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId'
run aws ec2 terminate-instances --instance-ids "$INSTANCIA" \
  --query 'TerminatingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]' --output table
run aws ec2 wait instance-terminated --instance-ids "$INSTANCIA"
# El volumen raíz tenía DeleteOnTermination=true, así que desaparece con la instancia
run aws ec2 describe-volumes --filters Name=volume-id,Values="$VOLUMEN" --query 'Volumes[].VolumeId'
rm -f "$ESTADO"
