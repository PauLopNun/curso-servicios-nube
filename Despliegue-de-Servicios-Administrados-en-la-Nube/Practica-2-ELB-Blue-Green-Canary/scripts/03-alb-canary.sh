#!/usr/bin/env bash
# Balanceador de aplicaciones (ALB) con estrategia Canary: dos grupos de destino
# (blue y green) y un agente de escucha que reparte el tráfico por pesos.
# Uso: ./03-alb-canary.sh crear          -> 100 % blue
#      ./03-alb-canary.sh pesos 90 10    -> 90 % blue, 10 % green (y así sucesivamente)
set -euo pipefail
source "$(dirname "$0")/config.sh"
source "$ESTADO"

pesos() { # peso_blue peso_green
  aws elbv2 modify-listener --listener-arn $LISTENER_ALB --default-actions \
    "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=$TG_BLUE,Weight=$1},{TargetGroupArn=$TG_GREEN,Weight=$2}]}" >/dev/null
  echo "Pesos: blue $1 / green $2"
}

case "${1:-crear}" in
crear)
  SG_ALB=$(aws ec2 create-security-group --group-name sec-$INI-alb \
    --description "HTTP de entrada al ALB" --vpc-id $VPC_ID --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id $SG_ALB --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null

  TG_BLUE=$(aws elbv2 create-target-group --name tar-$INI-blue --protocol HTTP --port 80 \
    --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
  TG_GREEN=$(aws elbv2 create-target-group --name tar-$INI-green --protocol HTTP --port 80 \
    --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
  aws elbv2 register-targets --target-group-arn $TG_BLUE --targets Id=$ID_BLUE
  aws elbv2 register-targets --target-group-arn $TG_GREEN --targets Id=$ID_GREEN

  ALB=$(aws elbv2 create-load-balancer --name alb-$INI --type application --scheme internet-facing \
    --subnets $SUBNET_A $SUBNET_B --security-groups $SG_ALB \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  LISTENER_ALB=$(aws elbv2 create-listener --load-balancer-arn $ALB --protocol HTTP --port 80 \
    --default-actions "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=$TG_BLUE,Weight=100},{TargetGroupArn=$TG_GREEN,Weight=0}]}" \
    --query 'Listeners[0].ListenerArn' --output text)

  echo "Esperando a que el ALB esté activo..."
  aws elbv2 wait load-balancer-available --load-balancer-arns $ALB
  aws elbv2 wait target-in-service --target-group-arn $TG_BLUE --targets Id=$ID_BLUE
  aws elbv2 wait target-in-service --target-group-arn $TG_GREEN --targets Id=$ID_GREEN
  DNS_ALB=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB --query 'LoadBalancers[0].DNSName' --output text)
  printf 'SG_ALB=%s\nTG_BLUE=%s\nTG_GREEN=%s\nALB=%s\nLISTENER_ALB=%s\nDNS_ALB=%s\n' \
    $SG_ALB $TG_BLUE $TG_GREEN $ALB $LISTENER_ALB $DNS_ALB >> "$ESTADO"
  echo "Pesos: blue 100 / green 0"
  echo "ALB: http://$DNS_ALB"
  ;;
pesos)
  pesos $2 $3
  ;;
esac
