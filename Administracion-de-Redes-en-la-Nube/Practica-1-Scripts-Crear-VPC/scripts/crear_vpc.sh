#!/bin/bash
# Práctica 1 - Crea una VPC, una subred y un EC2 dentro con la CLI
# Pau López Núñez

set -e

AMI_ID=ami-033ea4ff4a9c726dc    # Ubuntu Server 22.04 (Canonical)

# 1. Crear la VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 172.16.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lopez_pau-vpc-sh}]' \
    --query 'Vpc.VpcId' \
    --output text)
echo "VPC creada: $VPC_ID"

# 2. Crear la subred dentro de la VPC
SUB_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 172.16.0.0/20 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=lopez_pau-subred-sh}]' \
    --query 'Subnet.SubnetId' \
    --output text)
echo "Subred creada: $SUB_ID"

# 3. Lanzar el EC2 en la subred
INST_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --key-name vockey \
    --subnet-id "$SUB_ID" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lopez_pau-ec2-sh}]' \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Instancia creada: $INST_ID"

aws ec2 wait instance-running --instance-ids "$INST_ID"
aws ec2 describe-instances --instance-ids "$INST_ID" \
    --query 'Reservations[0].Instances[0].{Estado:State.Name,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress}' \
    --output table
