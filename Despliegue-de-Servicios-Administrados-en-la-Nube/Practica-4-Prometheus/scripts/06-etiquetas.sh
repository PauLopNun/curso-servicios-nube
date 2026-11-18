#!/bin/bash
# Práctica 4 - Actividad 1: monitorización por etiquetas (ec2_sd_configs)
# Uso: ./06-etiquetas.sh             -> pasos 1 a 5 (dos nodos con la etiqueta)
#      ./06-etiquetas.sh tercero     -> lanza un tercer nodo para ver que aparece solo
# Pau López Núñez

source "$(dirname "$0")/config.sh"

lanza_nodos() {   # lanza_nodos <cantidad> <nombre>
    aws ec2 run-instances --image-id $AMI_ID --instance-type $TIPO --key-name $CLAVE \
        --subnet-id $SUBRED --security-group-ids $SG_NODO --associate-public-ip-address \
        --user-data file://$DIR/user_data_ec2.txt --count $1 \
        --metadata-options HttpTokens=required \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$2},{Key=Monitorizar,Value=prometheus}]" \
        --query 'Instances[].InstanceId' --output text
}

lista_nodos() {
    aws ec2 describe-instances --filters Name=tag:Monitorizar,Values=prometheus Name=instance-state-name,Values=pending,running \
        --query 'Reservations[].Instances[].{Nombre:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,IP_privada:PrivateIpAddress,Estado:State.Name}' \
        --output table
}

if [ "$1" = "tercero" ]; then
    titulo "Tercer nodo con la etiqueta Monitorizar=prometheus"
    guarda NODO3 "$(lanza_nodos 1 ec2-pln-nodo3)"
    aws ec2 wait instance-running --instance-ids $NODO3
    lista_nodos
    exit 0
fi

titulo "1. Eliminar la instancia ec2_a"
aws ec2 terminate-instances --instance-ids $EC2_A --query 'TerminatingInstances[0].{Id:InstanceId,Antes:PreviousState.Name,Ahora:CurrentState.Name}' --output table

titulo "2. Asociar LabInstanceProfile a la instancia de Prometheus"
aws ec2 associate-iam-instance-profile --instance-id $EC2_PROM --iam-instance-profile Name=LabInstanceProfile \
    --query 'IamInstanceProfileAssociation.{Instancia:InstanceId,Perfil:IamInstanceProfile.Arn,Estado:State}' --output table

titulo "3. Sustituir static_configs por ec2_sd_configs"
en $EC2_PROM "sudo tee /etc/prometheus/prometheus.yml > /dev/null" < $DIR/config/prometheus-ec2sd.yml
mx $EC2_PROM "cat /etc/prometheus/prometheus.yml"

titulo "4. Validar y reiniciar"
mx $EC2_PROM "promtool check config /etc/prometheus/prometheus.yml"
mx $EC2_PROM "sudo systemctl restart prometheus && systemctl is-active prometheus"

titulo "5. Lanzar dos instancias a la vez con la etiqueta Monitorizar=prometheus"
guarda NODOS "$(lanza_nodos 2 ec2-pln-nodo | tr '\t' ' ')"
aws ec2 wait instance-running --instance-ids $NODOS
lista_nodos
