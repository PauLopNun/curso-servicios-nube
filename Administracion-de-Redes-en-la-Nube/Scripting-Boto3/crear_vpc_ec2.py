#!/usr/bin/env python3

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"
ZONA = "us-east-1a"
PREFIJO = "MiVPC-Boto3"

CIDR_VPC = "192.168.0.0/16"
CIDR_PUBLICA = "192.168.1.0/24"
CIDR_PRIVADA = "192.168.2.0/24"

# Última AMI de Ubuntu Server 22.04 publicada por Canonical
PARAM_AMI = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
AMI_RESERVA = "ami-033ea4ff4a9c726dc"
TIPO_INSTANCIA = "t2.micro"
CLAVE = "vockey"

DATOS_USUARIO = """#!/bin/bash
apt-get update -y
apt-get install -y apache2
echo "<h1>$(hostname) - VPC creada con Boto3</h1>" > /var/www/html/index.html
systemctl enable --now apache2
"""

ec2 = boto3.client("ec2", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)


def etiquetas(tipo, nombre):
    return [{"ResourceType": tipo, "Tags": [{"Key": "Name", "Value": f"{PREFIJO}-{nombre}"}]}]


def crear_vpc():
    vpc_id = ec2.create_vpc(CidrBlock=CIDR_VPC, TagSpecifications=etiquetas("vpc", "vpc"))["Vpc"]["VpcId"]
    ec2.get_waiter("vpc_available").wait(VpcIds=[vpc_id])

    # Hay que habilitarlos por separado, la API solo admite un atributo por llamada
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={"Value": True})
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={"Value": True})
    print(f"VPC creada: {vpc_id} ({CIDR_VPC}) con DNS habilitado")
    return vpc_id


def crear_subred(vpc_id, cidr, nombre, publica):
    subred_id = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock=cidr,
        AvailabilityZone=ZONA,
        TagSpecifications=etiquetas("subnet", nombre),
    )["Subnet"]["SubnetId"]

    if publica:
        ec2.modify_subnet_attribute(SubnetId=subred_id, MapPublicIpOnLaunch={"Value": True})
    print(f"Subred {nombre} creada: {subred_id} ({cidr})")
    return subred_id


def crear_salida_internet(vpc_id, subred_id):
    igw_id = ec2.create_internet_gateway(
        TagSpecifications=etiquetas("internet-gateway", "igw")
    )["InternetGateway"]["InternetGatewayId"]
    ec2.attach_internet_gateway(VpcId=vpc_id, InternetGatewayId=igw_id)
    print(f"Internet Gateway: {igw_id}")

    # Tabla de rutas propia para la subred pública; la privada se queda con la tabla principal (solo local)
    rtb_id = ec2.create_route_table(
        VpcId=vpc_id, TagSpecifications=etiquetas("route-table", "rtb-publica")
    )["RouteTable"]["RouteTableId"]
    ec2.create_route(RouteTableId=rtb_id, DestinationCidrBlock="0.0.0.0/0", GatewayId=igw_id)
    ec2.associate_route_table(RouteTableId=rtb_id, SubnetId=subred_id)
    print(f"Tabla de rutas pública: {rtb_id}")


def crear_grupo_seguridad(vpc_id):
    sg_id = ec2.create_security_group(
        GroupName=f"{PREFIJO}-sg",
        Description="SSH HTTP HTTPS",
        VpcId=vpc_id,
        TagSpecifications=etiquetas("security-group", "sg"),
    )["GroupId"]
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {"IpProtocol": "tcp", "FromPort": puerto, "ToPort": puerto, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
            for puerto in (22, 80, 443)
        ],
    )
    print(f"Grupo de seguridad: {sg_id}")
    return sg_id


def obtener_ami():
    try:
        return ssm.get_parameter(Name=PARAM_AMI)["Parameter"]["Value"]
    except ClientError:
        return AMI_RESERVA


def lanzar_instancia(subred_id, sg_id):
    inst_id = ec2.run_instances(
        ImageId=obtener_ami(),
        InstanceType=TIPO_INSTANCIA,
        KeyName=CLAVE,
        SubnetId=subred_id,
        SecurityGroupIds=[sg_id],
        UserData=DATOS_USUARIO,
        MinCount=1,
        MaxCount=1,
        TagSpecifications=etiquetas("instance", "ec2"),
    )["Instances"][0]["InstanceId"]
    print(f"Instancia lanzada: {inst_id}, esperando a que arranque...")

    ec2.get_waiter("instance_running").wait(InstanceIds=[inst_id])
    inst = ec2.describe_instances(InstanceIds=[inst_id])["Reservations"][0]["Instances"][0]
    print(f"  Estado:      {inst['State']['Name']}")
    print(f"  IP privada:  {inst['PrivateIpAddress']}")
    print(f"  IP pública:  {inst.get('PublicIpAddress', '-')}")
    print(f"  DNS público: {inst.get('PublicDnsName', '-')}")
    return inst


if __name__ == "__main__":
    try:
        identidad = boto3.client("sts", region_name=REGION).get_caller_identity()
        print(f"Cuenta : {identidad['Account']}")
        print(f"ARN    : {identidad['Arn']}")
        print(f"Región : {REGION}\n")
        if input("¿Crear la VPC y la instancia en esta cuenta? (s/N): ").strip().lower() != "s":
            raise SystemExit("Cancelado")

        vpc_id = crear_vpc()
        subred_publica = crear_subred(vpc_id, CIDR_PUBLICA, "subred-publica", publica=True)
        crear_subred(vpc_id, CIDR_PRIVADA, "subred-privada", publica=False)
        crear_salida_internet(vpc_id, subred_publica)
        sg_id = crear_grupo_seguridad(vpc_id)
        inst = lanzar_instancia(subred_publica, sg_id)

        print(f"Proceso completado. Apache estará disponible en http://{inst.get('PublicIpAddress')} en un par de minutos")

    except ClientError as e:
        print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
