#!/bin/bash
# Práctica 3 - Subred privada con salida a Internet a través de un NAT Gateway
# Parte de lo creado por 2_12igw.sh (VPC, subred pública con IGW y EC2 público).
#
# Uso: ./2_12pubpriv.sh             -> todos los pasos seguidos
#      ./2_12pubpriv.sh 1|2|3|4     -> un paso concreto
# Pau López Núñez

source "$(dirname "$0")/config.sh"

# Ejecuta un comando en el EC2 privado saltando por el EC2 público (bastión)
en_privada() {
    local ip
    ip=$(aws ec2 describe-instances --instance-ids "$EC2_PUB" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    ssh -i $PEM -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ProxyCommand="ssh -i $PEM -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -W %h:%p ubuntu@$ip" \
        ubuntu@$IP_EC2_PRIV "$@"
}

prueba_salida() {
    echo "-> desde $IP_EC2_PRIV: curl https://checkip.amazonaws.com"
    if ip=$(en_privada 'curl -s -m 8 https://checkip.amazonaws.com'); [ -n "$ip" ]; then
        echo "   RESULTADO: el EC2 privado sale a Internet con la IP $ip"
    else
        echo "   RESULTADO: el EC2 privado NO tiene salida a Internet"
    fi
}

paso1() {
    titulo "Paso 1: subred privada y EC2 privado"
    guarda SUB_PRIV "$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $CIDR_PRIV \
        --availability-zone $AZ \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sub-pln-privada}]' \
        --query 'Subnet.SubnetId' --output text)"
    echo "Subred privada: $SUB_PRIV ($CIDR_PRIV, sin IP pública)"

    # Solo admite SSH desde las máquinas del grupo de la subred pública
    guarda SG_PRIV "$(aws ec2 create-security-group --group-name sec-pln-privada \
        --description "SSH solo desde la subred publica" --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sec-pln-privada}]' \
        --query 'GroupId' --output text)"
    aws ec2 authorize-security-group-ingress --group-id $SG_PRIV \
        --protocol tcp --port 22 --source-group $SG_PUB > /dev/null
    echo "Grupo de seguridad: $SG_PRIV (22/tcp desde $SG_PUB)"

    guarda EC2_PRIV "$(aws ec2 run-instances --image-id $AMI_ID --instance-type $TIPO \
        --key-name $CLAVE --subnet-id $SUB_PRIV --private-ip-address $IP_EC2_PRIV \
        --security-group-ids $SG_PRIV \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2-pln-privada}]' \
        --query 'Instances[0].InstanceId' --output text)"
    aws ec2 wait instance-running --instance-ids $EC2_PRIV
    aws ec2 describe-instances --instance-ids $EC2_PUB $EC2_PRIV \
        --query 'Reservations[].Instances[].{Nombre:Tags[?Key==`Name`]|[0].Value,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress,Subred:SubnetId}' \
        --output table
    echo "Esperando 60 s a que arranque SSH..."; sleep 60
    echo "-> SSH al EC2 privado a través del público"
    en_privada 'echo "Conectado a $(hostname) ($(hostname -I))"'
    prueba_salida
}

paso2() {
    titulo "Paso 2: IP elástica y NAT Gateway en la subred pública"
    guarda EIP_ID "$(aws ec2 allocate-address --domain vpc \
        --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=eip-pln-nat}]' \
        --query 'AllocationId' --output text)"
    guarda NAT_ID "$(aws ec2 create-nat-gateway --subnet-id $SUB_PUB --allocation-id $EIP_ID \
        --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=nat-pln}]' \
        --query 'NatGateway.NatGatewayId' --output text)"
    echo "Esperando a que el NAT Gateway $NAT_ID esté disponible..."
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID
    aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_ID \
        --query 'NatGateways[0].{NAT:NatGatewayId,Estado:State,Subred:SubnetId,IP_publica:NatGatewayAddresses[0].PublicIp,IP_privada:NatGatewayAddresses[0].PrivateIp}' \
        --output table
    prueba_salida
}

paso3() {
    titulo "Paso 3: tabla de rutas privada con 0.0.0.0/0 hacia el NAT Gateway"
    guarda RTB_PRIV "$(aws ec2 create-route-table --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-pln-privada}]' \
        --query 'RouteTable.RouteTableId' --output text)"
    aws ec2 create-route --route-table-id $RTB_PRIV --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id $NAT_ID > /dev/null
    aws ec2 describe-route-tables --route-table-ids $RTB_PRIV \
        --query 'RouteTables[0].Routes[*].{Destino:DestinationCidrBlock,Por:GatewayId||NatGatewayId,Estado:State}' --output table
    prueba_salida
}

paso4() {
    titulo "Paso 4: asociar la tabla de rutas a la subred privada"
    guarda ASOC_PRIV "$(aws ec2 associate-route-table --route-table-id $RTB_PRIV \
        --subnet-id $SUB_PRIV --query 'AssociationId' --output text)"
    aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID \
        --query 'RouteTables[].{Tabla:Tags[?Key==`Name`]|[0].Value,Subred:Associations[0].SubnetId,IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].GatewayId,NAT:Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].NatGatewayId}' \
        --output table
    echo "Esperando 15 s a que se aplique la ruta..."; sleep 15
    prueba_salida
    echo "IP elástica del NAT Gateway: $(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_ID \
        --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp' --output text)"
    echo "-> El EC2 privado sigue sin IP pública, así que no se puede entrar a él desde fuera:"
    aws ec2 describe-instances --instance-ids $EC2_PRIV \
        --query 'Reservations[0].Instances[0].{Nombre:Tags[?Key==`Name`]|[0].Value,IP_privada:PrivateIpAddress,IP_publica:PublicIpAddress}' --output table
}

case "$1" in
    1) paso1 ;; 2) paso2 ;; 3) paso3 ;; 4) paso4 ;;
    "") paso1; paso2; paso3; paso4 ;;
    *) echo "Uso: $0 [1|2|3|4]"; exit 1 ;;
esac
