#!/bin/bash
# Práctica 4 - Paso 2: servidor Prometheus apuntando a la IP privada de ec2_a
# Pau López Núñez

source "$(dirname "$0")/config.sh"

titulo "Sustituir TARGET_IP en user_data_prometheus.txt"
IP_A=$(ip_privada $EC2_A)
sed "s/<IP-DE-LA-OTRA-EC2>/$IP_A/" $DIR/user_data_prometheus.txt > /tmp/ud-prometheus.txt
grep -n '^TARGET_IP=' /tmp/ud-prometheus.txt

titulo "Instancia prometheus (misma VPC y subred que ec2_a)"
guarda EC2_PROM "$(aws ec2 run-instances --image-id $AMI_ID --instance-type $TIPO --key-name $CLAVE \
    --subnet-id $SUBRED --security-group-ids $SG_PROM --associate-public-ip-address \
    --user-data file:///tmp/ud-prometheus.txt \
    --metadata-options HttpTokens=required \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prometheus}]' \
    --query 'Instances[0].InstanceId' --output text)"
aws ec2 wait instance-running --instance-ids $EC2_PROM
aws ec2 describe-instances --instance-ids $EC2_A $EC2_PROM \
    --query 'Reservations[].Instances[].{Nombre:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,Subred:SubnetId,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress}' \
    --output table
echo "Interfaz web: http://$(ip_publica $EC2_PROM):9090"
