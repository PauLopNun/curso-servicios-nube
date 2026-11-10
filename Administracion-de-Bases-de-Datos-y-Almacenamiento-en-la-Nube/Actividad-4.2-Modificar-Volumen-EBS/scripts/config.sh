#!/usr/bin/env bash
# Configuración común de la actividad
export AWS_DEFAULT_REGION=us-east-1
NOMBRE=ec2-pln            # instancia (3 letras del servicio + iniciales)
NOMBRE_SNAP=sna-pln       # snapshot de seguridad
TIPO=t3.micro
CLAVE=vockey
PERFIL=LabInstanceProfile
TAM_INICIAL=8
TAM_FINAL=10
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVID="$DIR/../evidencias"
ESTADO="$EVID/estado.env"
mkdir -p "$EVID"

# Muestra el comando, lo ejecuta y guarda comando y salida en el fichero de evidencias $LOG
run() {
  echo "\$ $*" | tee -a "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
  echo | tee -a "$LOG"
}

# Ejecuta un comando dentro de la instancia como ec2-user con SSM Run Command (sin SSH)
en_instancia() {
  echo "[ec2-user@$NOMBRE ~]\$ $*" | tee -a "$LOG"
  local id estado
  id=$(aws ssm send-command --instance-ids "$INSTANCIA" --document-name AWS-RunShellScript \
    --parameters "commands=[\"runuser -l ec2-user -c '$*' 2>&1\"]" --query Command.CommandId --output text)
  while :; do
    sleep 2
    estado=$(aws ssm get-command-invocation --command-id "$id" --instance-id "$INSTANCIA" \
      --query Status --output text 2>/dev/null || echo Pending)
    case "$estado" in Pending|InProgress|Delayed) ;; *) break ;; esac
  done
  aws ssm get-command-invocation --command-id "$id" --instance-id "$INSTANCIA" \
    --query StandardOutputContent --output text | tee -a "$LOG"
  echo | tee -a "$LOG"
}

[ -f "$ESTADO" ] && source "$ESTADO"
true
