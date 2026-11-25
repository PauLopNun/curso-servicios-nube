#!/bin/bash
# Ejecuta un comando en una instancia a través de Session Manager y muestra la salida.
# Sirve cuando el rol no tiene ssm:SendCommand pero sí ssm:StartSession.
# Requiere el Session Manager plugin instalado en el equipo.
#
# Uso: ./ssm-ejecutar.sh <instance-id> "<comando>" [timeout-segundos]
# Ej.: ./ssm-ejecutar.sh i-0123456789abcdef0 "sudo tail -n 5 /var/log/suricata/fast.log"

INSTANCIA="$1"
COMANDO="$2"
TIMEOUT="${3:-90}"
REGION="${AWS_REGION:-us-east-1}"

PARAMS=$(mktemp)
python3 -c 'import json,sys; print(json.dumps({"command":[sys.argv[1]]}))' "$COMANDO" > "$PARAMS"

# 'script' crea un pseudo-terminal: sin él, start-session termina con "EOF"
timeout "$TIMEOUT" script -qfc "aws ssm start-session --region $REGION --target $INSTANCIA \
  --document-name AWS-StartInteractiveCommand --parameters file://$PARAMS" /dev/null < /dev/null 2>&1 \
  | grep -vE '^(Starting|Exiting) session'

rm -f "$PARAMS"
