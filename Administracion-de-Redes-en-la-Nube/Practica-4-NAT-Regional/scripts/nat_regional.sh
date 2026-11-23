#!/bin/bash
# Práctica 4 - NAT Gateway regional con la AWS CLI
# VPC con bastión y dos subredes privadas en zonas distintas que salen a
# Internet por un único NAT regional y una única tabla de rutas privada.
# Pau López Núñez

set -e
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
ESTADO=$(dirname "$0")/estado.env; : > "$ESTADO"
CLAVE=/tmp/natcli; rm -f $CLAVE $CLAVE.pub; ssh-keygen -t ed25519 -N '' -q -f $CLAVE
OPC="-i $CLAVE -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10"

guarda() { echo "$1=$2" >> "$ESTADO"; export "$1=$2"; }
titulo() { echo; echo "=== $* ==="; }
etiqueta() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2}]"; }

subred() { # nombre cidr zona
    aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $2 --availability-zone $3 \
        --tag-specifications "$(etiqueta subnet $1)" --query Subnet.SubnetId --output text
}

ec2() { # nombre subred ip grupo [publica]
    aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name vockey \
        --network-interfaces "DeviceIndex=0,SubnetId=$2,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$3}],Groups=$4,AssociatePublicIpAddress=${5:-false}" \
        --tag-specifications "$(etiqueta instance $1)" --query 'Instances[0].InstanceId' --output text
}

prueba() { # nombre id ip
    for i in $EC2_BAS $2; do
        aws ec2-instance-connect send-ssh-public-key --instance-id $i --instance-os-user ec2-user \
            --ssh-public-key file://$CLAVE.pub --query Success --output text > /dev/null
    done
    local r
    r=$(ssh $OPC -o ProxyCommand="ssh $OPC -W %h:%p ec2-user@$IP_BAS" ec2-user@$3 \
        'curl -s -m 6 https://checkip.amazonaws.com || echo SIN-SALIDA') || r="ERROR-SSH"
    echo "$1 ($3) -> $r"
}

titulo "Base: VPC, subredes, IGW, tabla pública e instancias"
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text)
guarda VPC_ID "$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 \
    --tag-specifications "$(etiqueta vpc vpc-pln-natcli)" --query Vpc.VpcId --output text)"
aws ec2 wait vpc-available --vpc-ids $VPC_ID
guarda SUB_PUB "$(subred sub-pln-publica 172.16.0.0/20 us-east-1a)"
guarda SUB_PRIV_A "$(subred sub-pln-privada-a 172.16.64.0/20 us-east-1a)"
guarda SUB_PRIV_B "$(subred sub-pln-privada-b 172.16.80.0/20 us-east-1b)"
guarda IGW_ID "$(aws ec2 create-internet-gateway --tag-specifications "$(etiqueta internet-gateway igw-pln-natcli)" \
    --query InternetGateway.InternetGatewayId --output text)"
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
guarda RT_PUB "$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "$(etiqueta route-table rtb-pln-publica)" \
    --query RouteTable.RouteTableId --output text)"
aws ec2 create-route --route-table-id $RT_PUB --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
aws ec2 associate-route-table --route-table-id $RT_PUB --subnet-id $SUB_PUB > /dev/null
guarda SG_BAS "$(aws ec2 create-security-group --group-name sec-pln-bastion --description "SSH al bastion" \
    --vpc-id $VPC_ID --query GroupId --output text)"
guarda SG_PRIV "$(aws ec2 create-security-group --group-name sec-pln-privadas --description "SSH desde el bastion" \
    --vpc-id $VPC_ID --query GroupId --output text)"
aws ec2 authorize-security-group-ingress --group-id $SG_BAS --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_PRIV --protocol tcp --port 22 --source-group $SG_BAS > /dev/null
guarda EC2_BAS "$(ec2 ec2-pln-bastion $SUB_PUB 172.16.0.100 $SG_BAS true)"
guarda EC2_A "$(ec2 ec2-pln-privada-a $SUB_PRIV_A 172.16.64.100 $SG_PRIV)"
guarda EC2_B "$(ec2 ec2-pln-privada-b $SUB_PRIV_B 172.16.80.100 $SG_PRIV)"
aws ec2 wait instance-running --instance-ids $EC2_BAS $EC2_A $EC2_B
IP_BAS=$(aws ec2 describe-instances --instance-ids $EC2_BAS \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "VPC $VPC_ID, bastión $IP_BAS. Esperando 60 s a que arranque SSH..."; sleep 60
prueba privada-A $EC2_A 172.16.64.100
prueba privada-B $EC2_B 172.16.80.100

titulo "1. NAT regional: solo la VPC, sin subred ni IP elástica"
guarda NAT_ID "$(aws ec2 create-nat-gateway --vpc-id $VPC_ID --availability-mode regional \
    --tag-specifications "$(etiqueta natgateway nat-pln-regional)" \
    --query NatGateway.NatGatewayId --output text)"
echo "NAT: $NAT_ID"

titulo "2. Esperar a que esté disponible"
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_ID \
    --query 'NatGateways[0].{Modo:AvailabilityMode,Estado:State,AutoZonas:AutoProvisionZones,TablaNAT:RouteTableId}' \
    --output table
prueba privada-A $EC2_A 172.16.64.100

titulo "3 y 4. Una única tabla privada con 0.0.0.0/0 hacia el NAT"
guarda RT_PRIV "$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications "$(etiqueta route-table rtb-pln-privada)" \
    --query RouteTable.RouteTableId --output text)"
aws ec2 create-route --route-table-id $RT_PRIV --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID > /dev/null
echo "Tabla privada: $RT_PRIV"

titulo "5. La misma tabla para las subredes de las dos zonas"
aws ec2 associate-route-table --route-table-id $RT_PRIV --subnet-id $SUB_PRIV_A > /dev/null
aws ec2 associate-route-table --route-table-id $RT_PRIV --subnet-id $SUB_PRIV_B > /dev/null
echo "Esperando 60 s a que se aplique la ruta..."; sleep 60   # con 15 s todavía no había salida
aws ec2 describe-route-tables --route-table-ids $RT_PRIV \
    --query 'RouteTables[0].{Subredes:Associations[].SubnetId,NAT:Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].NatGatewayId}' \
    --output json

titulo "Comprobación final"
prueba privada-A $EC2_A 172.16.64.100
prueba privada-B $EC2_B 172.16.80.100
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_ID \
    --query 'NatGateways[0].NatGatewayAddresses[].[AvailabilityZone,PublicIp,Status]' --output table
