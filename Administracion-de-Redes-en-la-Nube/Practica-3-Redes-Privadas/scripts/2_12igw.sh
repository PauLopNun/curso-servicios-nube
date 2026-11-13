#!/bin/bash
# Práctica 3 - Acceso al exterior con la AWS CLI
# Crea la VPC, la subred pública y el EC2 (como en la práctica 1) y añade después,
# paso a paso, el Internet Gateway y la tabla de rutas. Tras cada paso se intenta
# entrar por SSH para ver que no hay acceso hasta que la infraestructura está completa.
#
# Uso: ./2_12igw.sh            -> todos los pasos seguidos
#      ./2_12igw.sh base|1|2|3|4|5 -> un paso concreto
# Pau López Núñez

source "$(dirname "$0")/config.sh"

base() {
    titulo "Base: VPC, subred pública, grupo de seguridad y EC2"
    guarda VPC_ID "$(aws ec2 create-vpc --cidr-block $CIDR_VPC \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-pln}]' \
        --query 'Vpc.VpcId' --output text)"
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'
    echo "VPC: $VPC_ID ($CIDR_VPC)"

    guarda SUB_PUB "$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $CIDR_PUB \
        --availability-zone $AZ \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sub-pln-publica}]' \
        --query 'Subnet.SubnetId' --output text)"
    aws ec2 modify-subnet-attribute --subnet-id $SUB_PUB --map-public-ip-on-launch
    echo "Subred pública: $SUB_PUB ($CIDR_PUB, IP pública automática)"

    guarda SG_PUB "$(aws ec2 create-security-group --group-name sec-pln-publica \
        --description "SSH desde el exterior" --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sec-pln-publica}]' \
        --query 'GroupId' --output text)"
    aws ec2 authorize-security-group-ingress --group-id $SG_PUB \
        --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
    echo "Grupo de seguridad: $SG_PUB (22/tcp desde 0.0.0.0/0)"

    guarda EC2_PUB "$(aws ec2 run-instances --image-id $AMI_ID --instance-type $TIPO \
        --key-name $CLAVE --subnet-id $SUB_PUB --private-ip-address $IP_EC2_PUB \
        --security-group-ids $SG_PUB \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2-pln-publica}]' \
        --query 'Instances[0].InstanceId' --output text)"
    aws ec2 wait instance-running --instance-ids $EC2_PUB
    aws ec2 describe-instances --instance-ids $EC2_PUB \
        --query 'Reservations[0].Instances[0].{Id:InstanceId,Estado:State.Name,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress}' \
        --output table
    echo "Esperando 60 s a que arranque SSH..."; sleep 60
    prueba_ssh
}

paso1() {
    titulo "Paso 1: crear el Internet Gateway"
    guarda IGW_ID "$(aws ec2 create-internet-gateway \
        --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-pln}]' \
        --query 'InternetGateway.InternetGatewayId' --output text)"
    aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID \
        --query 'InternetGateways[0].{IGW:InternetGatewayId,Adjuntos:length(Attachments)}' --output table
    prueba_ssh
}

paso2() {
    titulo "Paso 2: adjuntar el Internet Gateway a la VPC"
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
    aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID \
        --query 'InternetGateways[0].Attachments[*].{VPC:VpcId,Estado:State}' --output table
    prueba_ssh
}

paso3() {
    titulo "Paso 3: crear una tabla de rutas"
    guarda RTB_PUB "$(aws ec2 create-route-table --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-pln-publica}]' \
        --query 'RouteTable.RouteTableId' --output text)"
    aws ec2 describe-route-tables --route-table-ids $RTB_PUB \
        --query 'RouteTables[0].Routes[*].{Destino:DestinationCidrBlock,Destino_por:GatewayId,Estado:State}' --output table
    prueba_ssh
}

paso4() {
    titulo "Paso 4: añadir la ruta 0.0.0.0/0 hacia el Internet Gateway"
    aws ec2 create-route --route-table-id $RTB_PUB --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $IGW_ID > /dev/null
    aws ec2 describe-route-tables --route-table-ids $RTB_PUB \
        --query 'RouteTables[0].Routes[*].{Destino:DestinationCidrBlock,Destino_por:GatewayId,Estado:State}' --output table
    prueba_ssh
}

paso5() {
    titulo "Paso 5: asociar la tabla de rutas a la subred pública"
    guarda ASOC_PUB "$(aws ec2 associate-route-table --route-table-id $RTB_PUB \
        --subnet-id $SUB_PUB --query 'AssociationId' --output text)"
    aws ec2 describe-route-tables --route-table-ids $RTB_PUB \
        --query 'RouteTables[0].Associations[*].{Subred:SubnetId,Asociacion:RouteTableAssociationId}' --output table
    prueba_ssh
}

case "$1" in
    base) base ;;
    1) paso1 ;; 2) paso2 ;; 3) paso3 ;; 4) paso4 ;; 5) paso5 ;;
    "") base; paso1; paso2; paso3; paso4; paso5 ;;
    *) echo "Uso: $0 [base|1|2|3|4|5]"; exit 1 ;;
esac
