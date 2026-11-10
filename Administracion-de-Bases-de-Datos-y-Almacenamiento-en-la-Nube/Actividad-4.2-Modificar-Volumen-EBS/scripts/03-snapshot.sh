#!/usr/bin/env bash
# Paso 4: copia de seguridad del volumen antes de modificarlo
set -euo pipefail
source "$(dirname "$0")/config.sh"
LOG="$EVID/03-snapshot.txt"; : > "$LOG"

run aws ec2 create-snapshot --volume-id "$VOLUMEN" \
  --description "Copia de $VOLUMEN antes de ampliarlo a $TAM_FINAL GB" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$NOMBRE_SNAP}]"
SNAPSHOT=$(aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Name,Values="$NOMBRE_SNAP" \
  --query 'Snapshots[0].SnapshotId' --output text)
echo "SNAPSHOT=$SNAPSHOT" >> "$ESTADO"

# Seguimiento del estado hasta que la copia esté completa
while :; do
  run aws ec2 describe-snapshots --snapshot-ids "$SNAPSHOT" \
    --query 'Snapshots[].[SnapshotId,VolumeId,VolumeSize,State,Progress]' --output table
  [ "$(aws ec2 describe-snapshots --snapshot-ids "$SNAPSHOT" --query 'Snapshots[0].State' --output text)" = completed ] && break
  sleep 15
done
