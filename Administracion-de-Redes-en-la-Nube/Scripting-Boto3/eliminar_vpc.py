#!/usr/bin/env python3
# Elimina las VPC que elijas con todo lo que tienen dentro (instancias, grupos de seguridad, IGW, subredes y tablas de rutas)
# Pau López Núñez

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"

ec2 = boto3.client("ec2", region_name=REGION)


def nombre(recurso):
    return next((t["Value"] for t in recurso.get("Tags", []) if t["Key"] == "Name"), "-")


def marca(recurso):
    # Señala lo creado por crear_vpc_ec2.py
    return "  [Boto3]" if {"Key": "CreadoPor", "Value": "Boto3"} in recurso.get("Tags", []) else ""


def eliminar_vpc(vpc_id):
    filtro = [{"Name": "vpc-id", "Values": [vpc_id]}]

    # 1. Terminar las instancias de la VPC y esperar, si no las subredes y grupos siguen en uso
    ids = [
        inst["InstanceId"]
        for reserva in ec2.describe_instances(Filters=filtro)["Reservations"]
        for inst in reserva["Instances"]
        if inst["State"]["Name"] != "terminated"
    ]
    if ids:
        print(f"  Terminando instancias {', '.join(ids)}...")
        ec2.terminate_instances(InstanceIds=ids)
        ec2.get_waiter("instance_terminated").wait(InstanceIds=ids)

    # 2. Grupos de seguridad (el default se borra con la VPC)
    for sg in ec2.describe_security_groups(Filters=filtro)["SecurityGroups"]:
        if sg["GroupName"] != "default":
            ec2.delete_security_group(GroupId=sg["GroupId"])
            print(f"  Grupo de seguridad {sg['GroupId']} eliminado")

    # 3. Internet Gateways
    for igw in ec2.describe_internet_gateways(Filters=[{"Name": "attachment.vpc-id", "Values": [vpc_id]}])["InternetGateways"]:
        ec2.detach_internet_gateway(InternetGatewayId=igw["InternetGatewayId"], VpcId=vpc_id)
        ec2.delete_internet_gateway(InternetGatewayId=igw["InternetGatewayId"])
        print(f"  Internet Gateway {igw['InternetGatewayId']} eliminado")

    # 4. Subredes
    for sub in ec2.describe_subnets(Filters=filtro)["Subnets"]:
        ec2.delete_subnet(SubnetId=sub["SubnetId"])
        print(f"  Subred {sub['SubnetId']} eliminada")

    # 5. Tablas de rutas (la principal se borra con la VPC)
    for rtb in ec2.describe_route_tables(Filters=filtro)["RouteTables"]:
        if not any(a.get("Main") for a in rtb["Associations"]):
            ec2.delete_route_table(RouteTableId=rtb["RouteTableId"])
            print(f"  Tabla de rutas {rtb['RouteTableId']} eliminada")

    # 6. La VPC
    ec2.delete_vpc(VpcId=vpc_id)
    print(f"  VPC {vpc_id} eliminada")


try:
    identidad = boto3.client("sts", region_name=REGION).get_caller_identity()
    print(f"Cuenta : {identidad['Account']}")
    print(f"ARN    : {identidad['Arn']}")
    print(f"Región : {REGION}\n")

    # La VPC por defecto no se toca
    vpcs = [v for v in ec2.describe_vpcs()["Vpcs"] if not v["IsDefault"]]
    if not vpcs:
        print("No hay VPC que eliminar (solo la de por defecto)")
        raise SystemExit

    for i, vpc in enumerate(vpcs, 1):
        print(f"  {i}. {vpc['VpcId']}  {vpc['CidrBlock']:<16} {nombre(vpc)}{marca(vpc)}")

    respuesta = input("\nNúmeros de las VPC a eliminar separados por comas, 'boto3' (solo las marcadas), 'todas' o Enter para cancelar: ").strip().lower()
    if respuesta == "todas":
        elegidas = vpcs
    elif respuesta == "boto3":
        elegidas = [v for v in vpcs if marca(v)]
        if not elegidas:
            print("No hay VPC creadas con Boto3")
            raise SystemExit
    elif respuesta:
        elegidas = [vpcs[int(n) - 1] for n in respuesta.split(",")]
    else:
        print("Cancelado")
        raise SystemExit

    lista = ", ".join(v["VpcId"] for v in elegidas)
    if input(f"Se eliminarán {lista} y todo su contenido en la cuenta {identidad['Account']}. ¿Seguro? (s/N): ").strip().lower() != "s":
        print("Cancelado")
        raise SystemExit

    for vpc in elegidas:
        print(f"Eliminando {vpc['VpcId']} ({nombre(vpc)})")
        eliminar_vpc(vpc["VpcId"])
    print("Hecho")

except (ValueError, IndexError):
    print("Número de VPC no válido")
except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
