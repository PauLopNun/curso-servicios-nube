#!/usr/bin/env python3
# Termina todas las instancias EC2 de la región (las que no estén ya terminadas)
# Pau López Núñez

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"

ec2 = boto3.client("ec2", region_name=REGION)

try:
    # 1. Cuenta en la que estamos
    identidad = boto3.client("sts", region_name=REGION).get_caller_identity()
    print(f"Cuenta : {identidad['Account']}")
    print(f"ARN    : {identidad['Arn']}")
    print(f"Región : {REGION}\n")

    # 2. Buscar instancias que no estén terminadas
    instancias = []
    paginador = ec2.get_paginator("describe_instances")
    filtro = [{"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]}]
    for pagina in paginador.paginate(Filters=filtro):
        for reserva in pagina["Reservations"]:
            instancias.extend(reserva["Instances"])

    if not instancias:
        print("No hay instancias que terminar")
    else:
        for inst in instancias:
            nombre = next((t["Value"] for t in inst.get("Tags", []) if t["Key"] == "Name"), "-")
            print(f"  {inst['InstanceId']}  {inst['State']['Name']:<10} {nombre}")

        if input(f"\n¿Terminar estas {len(instancias)} instancias? (s/N): ").strip().lower() != "s":
            print("Cancelado")
        else:
            # 3. Terminarlas
            ids = [inst["InstanceId"] for inst in instancias]
            for cambio in ec2.terminate_instances(InstanceIds=ids)["TerminatingInstances"]:
                print(f"  {cambio['InstanceId']}  {cambio['PreviousState']['Name']} -> {cambio['CurrentState']['Name']}")

            # 4. Esperar a que estén terminadas
            print("Esperando a que terminen...")
            ec2.get_waiter("instance_terminated").wait(InstanceIds=ids)
            print("Todas las instancias terminadas")

except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
