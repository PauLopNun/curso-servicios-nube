#!/usr/bin/env bash
# Configuración común de la actividad 2.1 (se carga con: source config.sh)
export AWS_DEFAULT_REGION=us-east-1
OWNER=pln
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVID="$DIR/../evidencias"
mkdir -p "$EVID"

# ID de la instancia mon-pln (en marcha o arrancando)
ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mon-$OWNER" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

# ARN del tema de SNS (vacío hasta la parte 4)
TOPIC=$(aws sns list-topics --output text \
  --query "Topics[?ends_with(TopicArn,':avisos-$OWNER')].TopicArn")

# Muestra el comando tal como se escribe (con sus variables y saltos de línea),
# lo ejecuta y guarda comando y salida en $EVID/$LOG
run() {
  awk '{print (c ? "> " : "$ ") $0; c = /\\$/}' <<<"$1" | tee -a "$EVID/$LOG"
  eval "$1" > >(tee -a "$EVID/$LOG") 2>&1; sleep 0.2
  echo | tee -a "$EVID/$LOG"
}
