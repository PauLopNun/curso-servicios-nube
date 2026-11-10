#!/usr/bin/env bash
# Pasos 5 y 6: ampliar el volumen a 10 GB y después la partición y el sistema de archivos
set -euo pipefail
source "$(dirname "$0")/config.sh"
LOG="$EVID/04-modificar-volumen.txt"; : > "$LOG"

run aws ec2 modify-volume --volume-id "$VOLUMEN" --size "$TAM_FINAL"

# modifying -> optimizing -> completed. El tamaño nuevo ya se puede usar desde optimizing,
# pero el enunciado pide esperar a completed.
while :; do
  run aws ec2 describe-volumes-modifications --volume-ids "$VOLUMEN" \
    --query 'VolumesModifications[].[VolumeId,ModificationState,OriginalSize,TargetSize,Progress]' --output table
  [ "$(aws ec2 describe-volumes-modifications --volume-ids "$VOLUMEN" \
    --query 'VolumesModifications[0].ModificationState' --output text)" = completed ] && break
  sleep 20
done
run aws ec2 describe-volumes --volume-ids "$VOLUMEN" --query 'Volumes[].[VolumeId,Size,VolumeType,State]' --output table

LOG="$EVID/05-ampliar-sistema-archivos.txt"; : > "$LOG"
en_instancia df -hT
run aws ec2 describe-instance-types --instance-type "$TIPO" --query "InstanceTypes[].Hypervisor"
en_instancia sudo lsblk
en_instancia sudo growpart /dev/nvme0n1 1
en_instancia sudo lsblk
en_instancia sudo xfs_growfs -d /
en_instancia df -hT
