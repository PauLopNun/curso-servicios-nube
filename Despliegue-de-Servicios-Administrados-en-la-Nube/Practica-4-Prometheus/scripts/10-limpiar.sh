#!/bin/bash
# Práctica 4 - Borra todo lo creado: instancias, grupos de seguridad y tema SNS
# Pau López Núñez

source "$(dirname "$0")/config.sh"

titulo "Terminando instancias"
IDS=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=pending,running,stopped \
              "Name=tag:Name,Values=ec2_a,prometheus,ec2-pln-nodo,ec2-pln-nodo3" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then
    aws ec2 terminate-instances --instance-ids $IDS --query 'TerminatingInstances[].InstanceId' --output text
    aws ec2 wait instance-terminated --instance-ids $IDS
fi

titulo "Borrando grupos de seguridad (primero el del nodo, que referencia al de Prometheus)"
aws ec2 delete-security-group --group-id $SG_NODO > /dev/null && echo "$SG_NODO borrado"
aws ec2 delete-security-group --group-id $SG_PROM > /dev/null && echo "$SG_PROM borrado"

if [ -n "$SNS_ARN" ]; then
    titulo "Borrando el tema SNS (y su suscripción)"
    aws sns delete-topic --topic-arn $SNS_ARN && echo "$SNS_ARN borrado"
fi

rm -f "$ESTADO"
