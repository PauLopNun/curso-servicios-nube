#!/bin/bash
# Práctica 3 - Acceso al exterior. Variables comunes a todos los scripts
# Pau López Núñez

export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

AZ=us-east-1a
CIDR_VPC=172.16.0.0/16
CIDR_PUB=172.16.0.0/20
CIDR_PRIV=172.16.64.0/20
IP_EC2_PUB=172.16.0.100
IP_EC2_PRIV=172.16.64.100     # en el enunciado aparece 172.64.0.100, que queda fuera de la VPC
TIPO=t2.micro
CLAVE=vockey
PEM=~/.ssh/labsuser.pem

# AMI de Ubuntu Server 22.04 publicada por Canonical (siempre la última)
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
    --query 'Parameter.Value' --output text)

# Los ids de lo que se va creando se guardan aquí para los scripts siguientes
ESTADO=$(dirname "$0")/estado.env
[ -f "$ESTADO" ] && source "$ESTADO"

guarda() {
    [ -z "$2" ] && { echo "ERROR: no se ha podido obtener $1"; exit 1; }
    echo "$1=$2" >> "$ESTADO"; export "$1=$2"
}

titulo() { echo; echo "=== $* ==="; }

# Intenta abrir una sesión SSH contra la IP pública del EC2 público
prueba_ssh() {
    local ip
    ip=$(aws ec2 describe-instances --instance-ids "$EC2_PUB" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "-> ssh ubuntu@$ip"
    if ssh -i $PEM -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR ubuntu@"$ip" 'echo "Conectado a $(hostname) ($(hostname -I))"'; then
        echo "   RESULTADO: hay acceso por SSH desde el exterior"
    else
        echo "   RESULTADO: SIN acceso por SSH desde el exterior"
    fi
}
