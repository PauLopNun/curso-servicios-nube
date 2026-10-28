#!/usr/bin/env python3
# Lista las instancias EC2, VPC y recursos de red de la cuenta para decidir qué borrar
# Pau López Núñez

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

REGION = "us-east-1"

ec2 = boto3.client("ec2", region_name=REGION)


def nombre(recurso):
    return next((t["Value"] for t in recurso.get("Tags", []) if t["Key"] == "Name"), "-")


def marca(recurso):
    # Señala lo creado por crear_vpc_ec2.py
    return "  [Boto3]" if {"Key": "CreadoPor", "Value": "Boto3"} in recurso.get("Tags", []) else ""


try:
    # 1. Cuenta en la que estamos
    identidad = boto3.client("sts", region_name=REGION).get_caller_identity()
    print(f"Cuenta : {identidad['Account']}")
    print(f"ARN    : {identidad['Arn']}")
    print(f"Región : {REGION}")

    # 2. Instancias
    print("\nINSTANCIAS EC2")
    instancias = []
    for pagina in ec2.get_paginator("describe_instances").paginate():
        for reserva in pagina["Reservations"]:
            instancias.extend(reserva["Instances"])
    if not instancias:
        print("  (ninguna)")
    for inst in instancias:
        lanzada = inst["LaunchTime"].strftime("%d/%m %H:%M")
        print(f"  {inst['InstanceId']}  {inst['State']['Name']:<10} {inst['InstanceType']:<10} "
              f"{inst.get('PublicIpAddress', '-'):<15} {inst.get('VpcId', '-'):<22} {lanzada}  {nombre(inst)}{marca(inst)}")

    # 3. VPC con sus subredes, Internet Gateways y grupos de seguridad
    print("\nVPC")
    subredes = ec2.describe_subnets()["Subnets"]
    igws = ec2.describe_internet_gateways()["InternetGateways"]
    grupos = ec2.describe_security_groups()["SecurityGroups"]
    for vpc in ec2.describe_vpcs()["Vpcs"]:
        vpc_id = vpc["VpcId"]
        defecto = "  (por defecto)" if vpc["IsDefault"] else ""
        print(f"  {vpc_id}  {vpc['CidrBlock']:<16} {nombre(vpc)}{defecto}{marca(vpc)}")

        for sub in (s for s in subredes if s["VpcId"] == vpc_id):
            tipo = "pública" if sub["MapPublicIpOnLaunch"] else "privada"
            print(f"      subred  {sub['SubnetId']}  {sub['CidrBlock']:<16} {sub['AvailabilityZone']}  {tipo:<8} {nombre(sub)}")
        for igw in (i for i in igws if any(a["VpcId"] == vpc_id for a in i["Attachments"])):
            print(f"      igw     {igw['InternetGatewayId']}  {nombre(igw)}")
        for sg in (g for g in grupos if g["VpcId"] == vpc_id and g["GroupName"] != "default"):
            print(f"      sg      {sg['GroupId']}  {sg['GroupName']}")

    # 4. Recursos sueltos que siguen gastando crédito
    print("\nSIN USAR (gastan crédito)")
    sueltos = 0
    for vol in ec2.describe_volumes(Filters=[{"Name": "status", "Values": ["available"]}])["Volumes"]:
        sueltos += 1
        print(f"  volumen  {vol['VolumeId']}  {vol['Size']} GiB")
    for ip in ec2.describe_addresses()["Addresses"]:
        if "AssociationId" not in ip:
            sueltos += 1
            print(f"  IP elástica  {ip['PublicIp']}  {ip['AllocationId']}")
    if not sueltos:
        print("  (nada)")

except NoCredentialsError:
    print("No se encuentran credenciales: revisa ~/.aws/credentials")
except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
    print("Si el token ha caducado, reinicia el lab y pega credenciales nuevas en ~/.aws/credentials")
