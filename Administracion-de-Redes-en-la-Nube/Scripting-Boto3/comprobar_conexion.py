#!/usr/bin/env python3
# Comprueba que boto3 se conecta a AWS con las credenciales del Learner Lab

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

REGION = "us-east-1"

sesion = boto3.Session(region_name=REGION)

try:
    # 1. Identidad de las credenciales
    sts = sesion.client("sts")
    identidad = sts.get_caller_identity()
    print("Conectado a AWS")
    print(f"  Cuenta : {identidad['Account']}")
    print(f"  ARN    : {identidad['Arn']}")
    print(f"  Región : {sesion.region_name}")

    # 2. VPCs de la región
    ec2 = sesion.client("ec2")
    print("\nVPCs:")
    for vpc in ec2.describe_vpcs()["Vpcs"]:
        nombre = next((t["Value"] for t in vpc.get("Tags", []) if t["Key"] == "Name"), "-")
        print(f"  {vpc['VpcId']}  {vpc['CidrBlock']:<16} {nombre}  {'(por defecto)' if vpc['IsDefault'] else ''}")

    # 3. Instancias EC2
    print("\nInstancias EC2:")
    paginador = ec2.get_paginator("describe_instances")
    hay = False
    for pagina in paginador.paginate():
        for reserva in pagina["Reservations"]:
            for inst in reserva["Instances"]:
                hay = True
                print(f"  {inst['InstanceId']}  {inst['State']['Name']:<10} {inst.get('PublicIpAddress', '-')}")
    if not hay:
        print("  (ninguna)")

except NoCredentialsError:
    print("No se encuentran credenciales: revisa ~/.aws/credentials")
except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
    print("Si el token ha caducado, reinicia el lab y pega credenciales nuevas en ~/.aws/credentials")
