#!/bin/bash
# Práctica 3 - Elimina todo lo creado por 2_12igw.sh y 2_12pubpriv.sh
# El NAT Gateway y su IP elástica se cobran por hora: no dejarlos encendidos.
# Pau López Núñez

source "$(dirname "$0")/config.sh"

titulo "Terminando instancias"
aws ec2 terminate-instances --instance-ids $EC2_PUB $EC2_PRIV --query 'TerminatingInstances[].InstanceId' --output text
aws ec2 wait instance-terminated --instance-ids $EC2_PUB $EC2_PRIV

if [ -n "$NAT_ID" ]; then
    titulo "Borrando NAT Gateway e IP elástica"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID > /dev/null
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID
    aws ec2 release-address --allocation-id $EIP_ID
fi

titulo "Borrando tablas de rutas, subredes, grupos de seguridad, IGW y VPC"
for a in $ASOC_PUB $ASOC_PRIV; do aws ec2 disassociate-route-table --association-id $a; done
for r in $RTB_PUB $RTB_PRIV; do aws ec2 delete-route-table --route-table-id $r; done
for s in $SUB_PUB $SUB_PRIV; do aws ec2 delete-subnet --subnet-id $s; done
for g in $SG_PRIV $SG_PUB; do aws ec2 delete-security-group --group-id $g; done
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
aws ec2 delete-vpc --vpc-id $VPC_ID

aws ec2 describe-vpcs --filters Name=tag:Name,Values=vpc-pln --query 'length(Vpcs)' --output text \
    | xargs -I{} echo "VPC vpc-pln restantes: {}"
rm -f "$ESTADO"
