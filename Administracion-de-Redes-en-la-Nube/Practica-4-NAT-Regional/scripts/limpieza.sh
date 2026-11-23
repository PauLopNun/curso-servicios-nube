#!/bin/bash
# Práctica 4 - Borra lo creado por nat_regional.sh, en el orden del enunciado:
# instancias, NAT regional y, por último, la VPC con sus recursos.
# Pau López Núñez

set -e
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
ESTADO=$(dirname "$0")/estado.env
source "$ESTADO"

echo "Terminando instancias..."
aws ec2 terminate-instances --instance-ids $EC2_BAS $EC2_A $EC2_B > /dev/null
aws ec2 wait instance-terminated --instance-ids $EC2_BAS $EC2_A $EC2_B

echo "Borrando el NAT regional..."
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID > /dev/null
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID

echo "Borrando tablas, subredes, grupos, IGW y VPC..."
for a in $(aws ec2 describe-route-tables --route-table-ids $RT_PUB $RT_PRIV \
    --query 'RouteTables[].Associations[].RouteTableAssociationId' --output text); do
    aws ec2 disassociate-route-table --association-id $a
done
for r in $RT_PUB $RT_PRIV; do aws ec2 delete-route-table --route-table-id $r; done
for s in $SUB_PUB $SUB_PRIV_A $SUB_PRIV_B; do aws ec2 delete-subnet --subnet-id $s; done
aws ec2 revoke-security-group-ingress --group-id $SG_PRIV --protocol tcp --port 22 --source-group $SG_BAS > /dev/null
for g in $SG_PRIV $SG_BAS; do aws ec2 delete-security-group --group-id $g > /dev/null; done
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
aws ec2 delete-vpc --vpc-id $VPC_ID > /dev/null
rm -f "$ESTADO"
echo "Limpieza terminada"
