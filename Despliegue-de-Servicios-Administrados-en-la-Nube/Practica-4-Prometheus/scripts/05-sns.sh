#!/bin/bash
# Práctica 4 - Actividad 2 (1): tema SNS con suscripción de correo
# Uso: ./05-sns.sh <correo>
# Pau López Núñez

source "$(dirname "$0")/config.sh"
CORREO=${1:?Uso: $0 <correo>}

titulo "Tema SNS alertas-prometheus"
guarda SNS_ARN "$(aws sns create-topic --name alertas-prometheus \
    --tags Key=Name,Value=sns-pln --query 'TopicArn' --output text)"
echo "Tema: $SNS_ARN"
aws sns subscribe --topic-arn $SNS_ARN --protocol email --notification-endpoint "$CORREO" \
    --query 'SubscriptionArn' --output text
echo "Confirma la suscripción desde el enlace del correo y comprueba:"
echo "aws sns list-subscriptions-by-topic --topic-arn $SNS_ARN"
