#!/bin/bash
# Práctica 1 - Crea una VPC con una subred pública y lanza un EC2 dentro
# Pau López Núñez

AMI_ID=ami-033ea4ff4a9c726dc    # Ubuntu Server 22.04 (Canonical)

# 1. Crear la VPC y guardar su id
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.20.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lopez_pau-vpc-sh}]' \
    --query 'Vpc.VpcId' \
    --output text)
echo "VPC creada: $VPC_ID"

# Habilitar los nombres DNS en la VPC
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'

# 2. Crear la subred y guardar su id
SUB_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.20.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=lopez_pau-subred-sh}]' \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Subred creada: $SUB_ID"

# Habilitar la asignación automática de IPv4 pública en la subred
aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch

# 3. Internet Gateway y tabla de rutas para que la subred sea pública
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=lopez_pau-igw-sh}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "Internet Gateway: $IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=lopez_pau-rtb-sh}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUB_ID > /dev/null
echo "Tabla de rutas: $RTB_ID"

# 4. Grupo de seguridad con SSH, HTTP y HTTPS
SG_ID=$(aws ec2 create-security-group \
    --group-name lopez_pau-sg-sh \
    --description "SSH HTTP HTTPS" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 > /dev/null
echo "Grupo de seguridad: $SG_ID"

# 5. Lanzar el EC2 en la subred
INST_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name vockey \
    --subnet-id $SUB_ID \
    --security-group-ids $SG_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lopez_pau-sh}]' \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Instancia: $INST_ID"

aws ec2 wait instance-running --instance-ids $INST_ID
aws ec2 describe-instances --instance-ids $INST_ID \
    --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,PublicDnsName]' \
    --output table
