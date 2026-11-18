#!/bin/bash
# Práctica 4 - Prometheus. Variables y funciones comunes a todos los scripts
# Pau López Núñez

export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TIPO=t3.micro
CLAVE=vockey
PEM=~/.ssh/labsuser.pem
MI_IP=$(curl -s https://checkip.amazonaws.com)/32

# AMI de Amazon Linux 2023 (siempre la última)
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameter.Value' --output text)

# VPC y subred pública por defecto (las dos instancias van en la misma subred)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBRED=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=availability-zone,Values=us-east-1a \
    --query 'Subnets[0].SubnetId' --output text)

# Los ids de lo que se va creando se guardan aquí para los scripts siguientes
ESTADO=$DIR/estado.env
[ -f "$ESTADO" ] && source "$ESTADO"

guarda() {
    [ -z "$2" ] || [ "$2" = "None" ] && { echo "ERROR: no se ha podido obtener $1"; exit 1; }
    sed -i "/^$1=/d" "$ESTADO" 2>/dev/null
    echo "$1=\"$2\"" >> "$ESTADO"; export "$1=$2"
}

titulo() { echo; echo "=== $* ==="; }

ip_publica()  { aws ec2 describe-instances --instance-ids "$1" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text; }
ip_privada()  { aws ec2 describe-instances --instance-ids "$1" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text; }

# en <id-instancia> <comando...>: ejecuta un comando por SSH como ec2-user.
# labsuser.pem de este equipo no coincide con vockey en esta cuenta del lab, así que
# se usa EC2 Instance Connect: se publica la clave propia durante 60 s y se entra con ella.
CLAVE_SSH=~/.ssh/id_ed25519
en() {
    local id=$1; shift
    aws ec2-instance-connect send-ssh-public-key --instance-id "$id" --instance-os-user ec2-user \
        --ssh-public-key file://$CLAVE_SSH.pub > /dev/null
    ssh -i $CLAVE_SSH -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        ec2-user@"$(ip_publica "$id")" "$@"
}

# muestra_y_ejecuta <id> <comando>: imprime el comando como en una terminal y lo ejecuta
mx() {
    local id=$1; shift
    echo "[ec2-user@$(ip_privada "$id" | tr . -)]$ $*"
    en "$id" "$@"
}
