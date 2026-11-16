#!/bin/bash
# Tu equipo: lanza_webmin.sh
# Lanza una instancia Webmin desde la versión predeterminada de la plantilla,
# espera a que esté en ejecución y muestra la URL del panel.
# Uso: ./lanza_webmin.sh NOMBRE     (por ejemplo: ./lanza_webmin.sh webmin-pln-03)
set -euo pipefail

NOMBRE=${1:-}
if [ -z "$NOMBRE" ]; then
  echo "Uso: $0 NOMBRE_DE_LA_INSTANCIA" >&2
  exit 1
fi

PLANTILLA='LaunchTemplateName=webmin-pln-template,Version=$Default'
ETIQUETAS="{Key=Name,Value=$NOMBRE},{Key=Proyecto,Value=UD01},{Key=Propietario,Value=pln},{Key=Aplicacion,Value=webmin}"

echo "Lanzando $NOMBRE desde la plantilla..."
ID=$(aws ec2 run-instances --launch-template "$PLANTILLA" \
  --tag-specifications "ResourceType=instance,Tags=[$ETIQUETAS]" \
  --query "Instances[0].InstanceId" --output text)
echo "Instancia: $ID"

# esperar a que esté en ejecución
aws ec2 wait instance-running --instance-ids "$ID"

# obtener la IP pública con describe-instances y --query
IP=$(aws ec2 describe-instances --instance-ids "$ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
echo "En ejecución con la IP pública $IP. Esperando a Webmin..."

# esperar a que el puerto 10000 responda (los datos de usuario tardan unos minutos)
INTENTOS=30
for i in $(seq 1 $INTENTOS); do
  if curl -sk -o /dev/null --max-time 5 "https://$IP:10000"; then
    echo "Webmin disponible en https://$IP:10000"
    exit 0
  fi
  sleep 10
done

echo "Aviso: el puerto 10000 no responde desde este equipo tras $((INTENTOS * 10)) s." >&2
echo "Revisa cloud-init, las reglas del grupo de seguridad o el cortafuegos local." >&2
echo "URL prevista: https://$IP:10000"
exit 2
