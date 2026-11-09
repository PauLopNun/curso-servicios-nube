#!/usr/bin/env bash
# Entorno: grupo de seguridad (SSH y HTTP) y dos instancias, blue (servidor1) y green (servidor2)
set -euo pipefail
source "$(dirname "$0")/config.sh"

SG_EC2=$(aws ec2 create-security-group --group-name sec-$INI-web \
  --description "SSH y HTTP para los servidores blue y green" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_EC2 --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_EC2 --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
echo "Grupo de seguridad de las instancias: $SG_EC2"

lanzar() { # nombre color subred
  sed -e "s/COLOR/$2/g" -e "s/NOMBRE/$1/g" "$(dirname "$0")/userdata.sh" > /tmp/ud-$1.sh
  aws ec2 run-instances --image-id $AMI --instance-type $TIPO --key-name $KEY_NAME \
    --subnet-id $3 --security-group-ids $SG_EC2 --associate-public-ip-address \
    --user-data file:///tmp/ud-$1.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$1}]" \
    --query 'Instances[0].InstanceId' --output text
}
ID_BLUE=$(lanzar blue '#1565c0' $SUBNET_A)
ID_GREEN=$(lanzar green '#2e7d32' $SUBNET_B)
echo "blue (servidor1): $ID_BLUE"
echo "green (servidor2): $ID_GREEN"

aws ec2 wait instance-running --instance-ids $ID_BLUE $ID_GREEN
aws ec2 describe-instances --instance-ids $ID_BLUE $ID_GREEN \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,State.Name,Placement.AvailabilityZone,PublicDnsName]' --output table

cat > "$ESTADO" <<EST
SG_EC2=$SG_EC2
ID_BLUE=$ID_BLUE
ID_GREEN=$ID_GREEN
EST
