#!/usr/bin/env bash
# Balanceador de carga de red (NLB) con estrategia Blue/Green.
# Uso: ./02-nlb-blue-green.sh crear   -> NLB con solo la instancia blue en el grupo de destino
#      ./02-nlb-blue-green.sh green   -> se registra green y, cuando está sana, se quita blue
#      ./02-nlb-blue-green.sh blue    -> vuelta atrás a la versión blue
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$ESTADO"

esperar_sano() { # id
  echo "Esperando a que $1 esté healthy..."
  aws elbv2 wait target-in-service --target-group-arn $TG_NLB --targets Id=$1,Port=80
}
estado_destinos() {
  aws elbv2 describe-target-health --target-group-arn $TG_NLB \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
}

case "${1:-crear}" in
crear)
  # Grupo de seguridad del balanceador: entrada por el puerto 80
  SG_NLB=$(aws ec2 create-security-group --group-name sec-$INI-nlb \
    --description "HTTP de entrada al NLB" --vpc-id $VPC_ID --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id $SG_NLB --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null

  # Grupo de destino TCP 80 de tipo instancia, comprobaciones de estado por defecto
  TG_NLB=$(aws elbv2 create-target-group --name tar-$INI-nlb --protocol TCP --port 80 \
    --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
  # Tiempo de drenaje corto para que el cambio de versión se vea rápido
  aws elbv2 modify-target-group-attributes --target-group-arn $TG_NLB \
    --attributes Key=deregistration_delay.timeout_seconds,Value=10 >/dev/null

  # Al principio solo se registra la instancia blue
  aws elbv2 register-targets --target-group-arn $TG_NLB --targets Id=$ID_BLUE,Port=80

  # Balanceador de red, expuesto a internet, en dos zonas de disponibilidad
  NLB=$(aws elbv2 create-load-balancer --name nlb-$INI --type network --scheme internet-facing \
    --subnets $SUBNET_A $SUBNET_B --security-groups $SG_NLB \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  # Balanceo entre zonas: blue y green están en zonas distintas
  aws elbv2 modify-load-balancer-attributes --load-balancer-arn $NLB \
    --attributes Key=load_balancing.cross_zone.enabled,Value=true >/dev/null

  # Agente de escucha TCP 80 que reenvía al grupo de destino
  aws elbv2 create-listener --load-balancer-arn $NLB --protocol TCP --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_NLB >/dev/null

  echo "Esperando a que el NLB esté activo..."
  aws elbv2 wait load-balancer-available --load-balancer-arns $NLB
  DNS_NLB=$(aws elbv2 describe-load-balancers --load-balancer-arns $NLB --query 'LoadBalancers[0].DNSName' --output text)
  printf 'SG_NLB=%s\nTG_NLB=%s\nNLB=%s\nDNS_NLB=%s\n' $SG_NLB $TG_NLB $NLB $DNS_NLB >> "$ESTADO"
  esperar_sano $ID_BLUE
  estado_destinos
  echo "NLB: http://$DNS_NLB"
  ;;
green)
  # Despliegue de la versión nueva: se añade green y, cuando está sana, se retira blue
  aws elbv2 register-targets --target-group-arn $TG_NLB --targets Id=$ID_GREEN,Port=80
  esperar_sano $ID_GREEN
  aws elbv2 deregister-targets --target-group-arn $TG_NLB --targets Id=$ID_BLUE,Port=80
  aws elbv2 wait target-deregistered --target-group-arn $TG_NLB --targets Id=$ID_BLUE,Port=80
  estado_destinos
  ;;
blue)
  # Vuelta atrás: blue sigue encendida, así que se puede recuperar al momento
  aws elbv2 register-targets --target-group-arn $TG_NLB --targets Id=$ID_BLUE,Port=80
  esperar_sano $ID_BLUE
  aws elbv2 deregister-targets --target-group-arn $TG_NLB --targets Id=$ID_GREEN,Port=80
  aws elbv2 wait target-deregistered --target-group-arn $TG_NLB --targets Id=$ID_GREEN,Port=80
  estado_destinos
  ;;
esac
