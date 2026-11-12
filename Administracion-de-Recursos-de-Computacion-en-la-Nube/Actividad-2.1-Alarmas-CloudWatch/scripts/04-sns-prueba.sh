#!/usr/bin/env bash
# Parte 4: ARN del tema, estado de la suscripción y mensaje de prueba
source "$(dirname "$0")/config.sh"; LOG=04-sns-prueba.txt; : > "$EVID/$LOG"
run 'TOPIC=$(aws sns list-topics --output text \
  --query "Topics[?ends_with(TopicArn,'"'"':avisos-$OWNER'"'"')].TopicArn")
echo $TOPIC'
run 'aws sns list-subscriptions-by-topic --topic-arn $TOPIC --output table \
  --query "Subscriptions[].{Protocolo:Protocol,Destino:Endpoint,Suscripcion:SubscriptionArn}"'
run 'aws sns publish --topic-arn $TOPIC \
  --subject "Prueba de avisos-pln" \
  --message "Mensaje de prueba enviado desde la AWS CLI para comprobar la suscripción."'
