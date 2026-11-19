#!/bin/bash
# Fase 7 - Reto: segunda red solo con CLI (vpc-reto) y servidor web ec2-reto
# Uso: ./reto.sh           -> crea todo y espera a que la web responda
#      ./reto.sh limpiar   -> borra todo lo que crea el script
set -e
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""
ESTADO=$(dirname "$0")/reto.env

if [ "$1" = "limpiar" ]; then
    source "$ESTADO"
    aws ec2 terminate-instances --instance-ids $ID_RETO > /dev/null
    aws ec2 wait instance-terminated --instance-ids $ID_RETO
    aws ec2 delete-security-group --group-id $SG > /dev/null
    aws ec2 disassociate-route-table --association-id $ASOC
    aws ec2 delete-subnet --subnet-id $SN
    aws ec2 delete-route-table --route-table-id $RT
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW
    aws ec2 delete-vpc --vpc-id $VPC
    rm -f "$ESTADO"
    echo "vpc-reto y sus recursos eliminados"
    exit 0
fi

MI_IP=$(curl -s https://checkip.amazonaws.com)/32
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text)

# Red: VPC con DNS, subred pública, IGW y tabla de rutas con salida a Internet
VPC=$(aws ec2 create-vpc --cidr-block 10.30.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-reto}]' \
    --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC --enable-dns-hostnames
SN=$(aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.30.1.0/24 --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sn-reto}]' \
    --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id $SN --map-public-ip-on-launch
IGW=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-reto}]' \
    --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC
RT=$(aws ec2 create-route-table --vpc-id $VPC \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rt-reto}]' \
    --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id $RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW > /dev/null
ASOC=$(aws ec2 associate-route-table --route-table-id $RT --subnet-id $SN --query AssociationId --output text)

# Security Group: 80 desde cualquier origen y 22 solo desde mi IP
SG=$(aws ec2 create-security-group --group-name sgr-reto --description "Web del reto" --vpc-id $VPC \
    --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr $MI_IP > /dev/null

# Instancia con User Data: Apache con el nombre de host
cat > /tmp/ud-reto.sh <<'UD'
#!/bin/bash
dnf install -y httpd
echo "<h1>ec2-reto</h1><p>Servidor: $(hostname -f)</p>" > /var/www/html/index.html
systemctl enable --now httpd
UD
ID_RETO=$(aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name vockey \
    --subnet-id $SN --security-group-ids $SG --iam-instance-profile Name=LabInstanceProfile \
    --metadata-options HttpTokens=required --user-data file:///tmp/ud-reto.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2-reto}]' \
    --query 'Instances[0].InstanceId' --output text)

cat > "$ESTADO" <<ENV
VPC=$VPC
SN=$SN
IGW=$IGW
RT=$RT
ASOC=$ASOC
SG=$SG
ID_RETO=$ID_RETO
ENV

aws ec2 wait instance-running --instance-ids $ID_RETO
IP=$(aws ec2 describe-instances --instance-ids $ID_RETO \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "VPC $VPC | subred $SN | IGW $IGW | tabla $RT | SG $SG | instancia $ID_RETO"
echo "Esperando a que Apache responda en http://$IP ..."
until curl -s -m 5 http://$IP > /dev/null; do sleep 10; done
curl -s http://$IP
