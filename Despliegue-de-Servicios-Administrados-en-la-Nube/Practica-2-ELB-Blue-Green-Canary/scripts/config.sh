#!/usr/bin/env bash
# Variables comunes de la práctica
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""
INI=pln
KEY_NAME=vockey
TIPO=t2.micro
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  Name=availability-zone,Values=us-east-1a,us-east-1b --query 'Subnets[].SubnetId' --output text)
SUBNET_A=$(echo $SUBNETS | cut -d' ' -f1)
SUBNET_B=$(echo $SUBNETS | cut -d' ' -f2)
ESTADO=$(dirname "$0")/../evidencias/estado.env
