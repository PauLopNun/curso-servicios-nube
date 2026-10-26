#!/usr/bin/env python3
# Termina todas las instancias EC2 de la región (las que no estén ya terminadas)
# Pau López Núñez

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"

ec2 = boto3.client("ec2", region_name=REGION)

try:
    # 1. Buscar instancias que no estén terminadas
    ids = []
    paginador = ec2.get_paginator("describe_instances")
    filtro = [{"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]}]
    for pagina in paginador.paginate(Filters=filtro):
        for reserva in pagina["Reservations"]:
            for inst in reserva["Instances"]:
                ids.append(inst["InstanceId"])

    if not ids:
        print("No hay instancias que terminar")
    else:
        # 2. Terminarlas
        print(f"Terminando {len(ids)} instancias...")
        for cambio in ec2.terminate_instances(InstanceIds=ids)["TerminatingInstances"]:
            print(f"  {cambio['InstanceId']}  {cambio['PreviousState']['Name']} -> {cambio['CurrentState']['Name']}")

        # 3. Esperar a que estén terminadas
        print("Esperando a que terminen...")
        ec2.get_waiter("instance_terminated").wait(InstanceIds=ids)
        print("Todas las instancias terminadas")

except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
