#!/bin/bash
# Práctica 4 - Paso 1: grupos de seguridad y nodo a monitorizar (ec2_a) con Node Exporter
# Pau López Núñez

source "$(dirname "$0")/config.sh"

titulo "Grupos de seguridad"
# Se crean los dos ahora porque el del nodo hace referencia al de Prometheus
guarda SG_PROM "$(aws ec2 create-security-group --group-name sec-pln-prometheus \
    --description "Prometheus: SSH y web 9090 desde mi IP" --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sec-pln-prometheus}]' \
    --query 'GroupId' --output text)"
aws ec2 authorize-security-group-ingress --group-id $SG_PROM --protocol tcp --port 22   --cidr $MI_IP > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_PROM --protocol tcp --port 9090 --cidr $MI_IP > /dev/null

guarda SG_NODO "$(aws ec2 create-security-group --group-name sec-pln-nodo \
    --description "Nodo: SSH desde mi IP y 9100 desde Prometheus" --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sec-pln-nodo}]' \
    --query 'GroupId' --output text)"
aws ec2 authorize-security-group-ingress --group-id $SG_NODO --protocol tcp --port 22   --cidr $MI_IP > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_NODO --protocol tcp --port 9100 --source-group $SG_PROM > /dev/null

for sg in $SG_NODO $SG_PROM; do
    aws ec2 describe-security-groups --group-ids $sg \
        --query 'SecurityGroups[0].IpPermissions[].{Grupo:`'"$sg"'`,Puerto:FromPort,Origen:IpRanges[0].CidrIp||UserIdGroupPairs[0].GroupId}' \
        --output table
done

titulo "Instancia ec2_a (Amazon Linux 2023 + user_data_ec2.txt)"
guarda EC2_A "$(aws ec2 run-instances --image-id $AMI_ID --instance-type $TIPO --key-name $CLAVE \
    --subnet-id $SUBRED --security-group-ids $SG_NODO --associate-public-ip-address \
    --user-data file://$DIR/user_data_ec2.txt \
    --metadata-options HttpTokens=required \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2_a}]' \
    --query 'Instances[0].InstanceId' --output text)"
aws ec2 wait instance-running --instance-ids $EC2_A
aws ec2 describe-instances --instance-ids $EC2_A \
    --query 'Reservations[0].Instances[0].{Nombre:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,Estado:State.Name,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress}' \
    --output table
echo "IP privada de ec2_a (para Prometheus): $(ip_privada $EC2_A)"
