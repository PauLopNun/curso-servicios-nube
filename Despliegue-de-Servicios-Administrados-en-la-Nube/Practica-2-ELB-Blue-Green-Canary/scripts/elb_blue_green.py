#!/usr/bin/env python3
"""Práctica 2 - Estrategia Blue/Green y Canary con Elastic Load Balancing (boto3).

Hace lo mismo que los scripts de la CLI, pero en un solo programa:

    python3 elb_blue_green.py todo        # entorno + NLB blue/green + ALB canary, con comprobaciones
    python3 elb_blue_green.py entorno     # grupo de seguridad e instancias blue y green
    python3 elb_blue_green.py nlb         # NLB con solo blue registrada
    python3 elb_blue_green.py green       # NLB: entra green y sale blue
    python3 elb_blue_green.py blue        # NLB: vuelta atrás a blue
    python3 elb_blue_green.py canary      # ALB con dos grupos de destino, 100 % blue
    python3 elb_blue_green.py pesos 90 10 # ALB: reparto blue/green
    python3 elb_blue_green.py probar URL [N]
    python3 elb_blue_green.py limpiar     # borra todo

Los identificadores de lo creado se guardan en evidencias/estado_boto3.json.
"""
import json
import os
import re
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"
INI = os.environ.get("INI", "pln")  # iniciales: los nombres siguen <3 letras del servicio>-pln
KEY_NAME = "vockey"
TIPO = "t2.micro"
ZONAS = ["us-east-1a", "us-east-1b"]
ESTADO = Path(__file__).resolve().parent.parent / "evidencias" / f"estado_boto3_{INI}.json"

USER_DATA = """#!/bin/bash
dnf install -y httpd
systemctl enable --now httpd
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>{nombre}</title></head>
<body style="background:{color};color:white;font-family:sans-serif;text-align:center;padding-top:15%">
  <h1>Versión {nombre}</h1>
  <h2>Servidor: $(hostname -f)</h2>
</body>
</html>
HTML
"""

ec2 = boto3.client("ec2", region_name=REGION)
elb = boto3.client("elbv2", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)


# ---------------------------------------------------------------- utilidades
def leer_estado():
    return json.loads(ESTADO.read_text()) if ESTADO.exists() else {}


def guardar_estado(**datos):
    estado = leer_estado()
    estado.update(datos)
    ESTADO.parent.mkdir(exist_ok=True)
    ESTADO.write_text(json.dumps(estado, indent=2) + "\n")
    return estado


def red_por_defecto():
    vpc = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])["Vpcs"][0]["VpcId"]
    subredes = ec2.describe_subnets(Filters=[
        {"Name": "vpc-id", "Values": [vpc]},
        {"Name": "default-for-az", "Values": ["true"]},
        {"Name": "availability-zone", "Values": ZONAS},
    ])["Subnets"]
    subredes.sort(key=lambda s: s["AvailabilityZone"])
    return vpc, [s["SubnetId"] for s in subredes]


def grupo_seguridad(nombre, descripcion, vpc, puertos):
    sg = ec2.create_security_group(GroupName=nombre, Description=descripcion, VpcId=vpc)["GroupId"]
    ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=[
        {"IpProtocol": "tcp", "FromPort": p, "ToPort": p, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
        for p in puertos
    ])
    print(f"Grupo de seguridad {nombre}: {sg}")
    return sg


def esperar_sano(tg, instancia):
    print(f"Esperando a que {instancia} esté healthy...")
    elb.get_waiter("target_in_service").wait(TargetGroupArn=tg, Targets=[{"Id": instancia}])


def estado_destinos(tg):
    for d in elb.describe_target_health(TargetGroupArn=tg)["TargetHealthDescriptions"]:
        print(f"  {d['Target']['Id']}  {d['TargetHealth']['State']}")


def probar(url, n=20):
    """Hace n peticiones y cuenta qué versión responde."""
    cuenta = Counter()
    for _ in range(n):
        for intento in range(3):
            try:
                req = urllib.request.Request(url, headers={"Connection": "close"})
                html = urllib.request.urlopen(req, timeout=5).read().decode()
                cuenta[re.search(r"Versión (\w+)", html).group(1)] += 1
                break
            except Exception:
                if intento == 2:
                    cuenta["error"] += 1
    print("  " + ", ".join(f"{v}: {c}" for v, c in sorted(cuenta.items())))
    return cuenta


# ------------------------------------------------------------------- entorno
def entorno():
    vpc, subredes = red_por_defecto()
    ami = ssm.get_parameter(Name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64")["Parameter"]["Value"]
    sg = grupo_seguridad(f"sec-{INI}-web", "SSH y HTTP para los servidores blue y green", vpc, [22, 80])

    ids = {}
    for (nombre, color), subred in zip([("blue", "#1565c0"), ("green", "#2e7d32")], subredes):
        ids[nombre] = ec2.run_instances(
            ImageId=ami, InstanceType=TIPO, KeyName=KEY_NAME, MinCount=1, MaxCount=1,
            NetworkInterfaces=[{"DeviceIndex": 0, "SubnetId": subred, "Groups": [sg],
                                "AssociatePublicIpAddress": True}],
            UserData=USER_DATA.format(nombre=nombre, color=color),
            TagSpecifications=[{"ResourceType": "instance",
                                "Tags": [{"Key": "Name", "Value": nombre}]}],
        )["Instances"][0]["InstanceId"]
        print(f"{nombre}: {ids[nombre]}")

    ec2.get_waiter("instance_running").wait(InstanceIds=list(ids.values()))
    for r in ec2.describe_instances(InstanceIds=list(ids.values()))["Reservations"]:
        i = r["Instances"][0]
        nombre = next(t["Value"] for t in i["Tags"] if t["Key"] == "Name")
        print(f"  {nombre:6} {i['InstanceId']}  {i['Placement']['AvailabilityZone']}  http://{i['PublicDnsName']}")
    guardar_estado(vpc=vpc, subredes=subredes, sg_ec2=sg, id_blue=ids["blue"], id_green=ids["green"])


# ------------------------------------------------------- NLB: blue / green
def nlb():
    e = leer_estado()
    sg = grupo_seguridad(f"sec-{INI}-nlb", "HTTP de entrada al NLB", e["vpc"], [80])
    tg = elb.create_target_group(Name=f"tar-{INI}-nlb", Protocol="TCP", Port=80, VpcId=e["vpc"],
                                 TargetType="instance")["TargetGroups"][0]["TargetGroupArn"]
    elb.modify_target_group_attributes(TargetGroupArn=tg, Attributes=[
        {"Key": "deregistration_delay.timeout_seconds", "Value": "10"}])
    # Al principio solo la versión blue
    elb.register_targets(TargetGroupArn=tg, Targets=[{"Id": e["id_blue"], "Port": 80}])

    lb = elb.create_load_balancer(Name=f"nlb-{INI}", Type="network", Scheme="internet-facing",
                                  Subnets=e["subredes"], SecurityGroups=[sg])["LoadBalancers"][0]
    elb.modify_load_balancer_attributes(LoadBalancerArn=lb["LoadBalancerArn"], Attributes=[
        {"Key": "load_balancing.cross_zone.enabled", "Value": "true"}])
    elb.create_listener(LoadBalancerArn=lb["LoadBalancerArn"], Protocol="TCP", Port=80,
                        DefaultActions=[{"Type": "forward", "TargetGroupArn": tg}])

    print("Esperando a que el NLB esté activo...")
    elb.get_waiter("load_balancer_available").wait(LoadBalancerArns=[lb["LoadBalancerArn"]])
    guardar_estado(sg_nlb=sg, tg_nlb=tg, nlb=lb["LoadBalancerArn"], dns_nlb=lb["DNSName"])
    esperar_sano(tg, e["id_blue"])
    estado_destinos(tg)
    print(f"NLB: http://{lb['DNSName']}")


def cambiar_version(nueva, antigua):
    """Registra la versión nueva, espera a que esté sana y retira la antigua."""
    e = leer_estado()
    tg = e["tg_nlb"]
    elb.register_targets(TargetGroupArn=tg, Targets=[{"Id": e[f"id_{nueva}"], "Port": 80}])
    esperar_sano(tg, e[f"id_{nueva}"])
    elb.deregister_targets(TargetGroupArn=tg, Targets=[{"Id": e[f"id_{antigua}"], "Port": 80}])
    elb.get_waiter("target_deregistered").wait(TargetGroupArn=tg, Targets=[{"Id": e[f"id_{antigua}"], "Port": 80}])
    print(f"Versión activa en el NLB: {nueva}")
    estado_destinos(tg)


# ------------------------------------------------------------- ALB: canary
def canary():
    e = leer_estado()
    sg = grupo_seguridad(f"sec-{INI}-alb", "HTTP de entrada al ALB", e["vpc"], [80])
    tgs = {}
    for color in ("blue", "green"):
        tgs[color] = elb.create_target_group(Name=f"tar-{INI}-{color}", Protocol="HTTP", Port=80,
                                             VpcId=e["vpc"], TargetType="instance")["TargetGroups"][0]["TargetGroupArn"]
        elb.register_targets(TargetGroupArn=tgs[color], Targets=[{"Id": e[f"id_{color}"]}])

    lb = elb.create_load_balancer(Name=f"alb-{INI}", Type="application", Scheme="internet-facing",
                                  Subnets=e["subredes"], SecurityGroups=[sg])["LoadBalancers"][0]
    listener = elb.create_listener(LoadBalancerArn=lb["LoadBalancerArn"], Protocol="HTTP", Port=80,
                                   DefaultActions=[accion_pesos(tgs, 100, 0)])["Listeners"][0]["ListenerArn"]
    print("Esperando a que el ALB esté activo...")
    elb.get_waiter("load_balancer_available").wait(LoadBalancerArns=[lb["LoadBalancerArn"]])
    for color in tgs:
        esperar_sano(tgs[color], e[f"id_{color}"])
    guardar_estado(sg_alb=sg, tg_blue=tgs["blue"], tg_green=tgs["green"], alb=lb["LoadBalancerArn"],
                   listener_alb=listener, dns_alb=lb["DNSName"])
    print(f"Pesos: blue 100 / green 0\nALB: http://{lb['DNSName']}")


def accion_pesos(tgs, blue, green):
    return {"Type": "forward", "ForwardConfig": {"TargetGroups": [
        {"TargetGroupArn": tgs["blue"], "Weight": blue},
        {"TargetGroupArn": tgs["green"], "Weight": green}]}}


def pesos(blue, green):
    e = leer_estado()
    elb.modify_listener(ListenerArn=e["listener_alb"],
                        DefaultActions=[accion_pesos({"blue": e["tg_blue"], "green": e["tg_green"]}, blue, green)])
    print(f"Pesos: blue {blue} / green {green}")


# ------------------------------------------------------------------ limpiar
def reintentar(accion, codigo, veces=12):
    """Repite una acción mientras AWS devuelva `codigo` (los borrados tardan en propagarse)."""
    for intento in range(veces):
        try:
            return accion()
        except ClientError as err:
            if err.response["Error"]["Code"] != codigo or intento == veces - 1:
                raise
            time.sleep(10)


def limpiar():
    e = leer_estado()
    lbs = [e[k] for k in ("alb", "nlb") if k in e]
    for lb in lbs:
        elb.delete_load_balancer(LoadBalancerArn=lb)
    if lbs:
        elb.get_waiter("load_balancers_deleted").wait(LoadBalancerArns=lbs)
    for k in ("tg_blue", "tg_green", "tg_nlb"):
        if k in e:
            reintentar(lambda: elb.delete_target_group(TargetGroupArn=e[k]), "ResourceInUse")
    ids = [e[k] for k in ("id_blue", "id_green") if k in e]
    if ids:
        ec2.terminate_instances(InstanceIds=ids)
        ec2.get_waiter("instance_terminated").wait(InstanceIds=ids)
    # las interfaces de red de los balanceadores tardan en liberarse
    for k in ("sg_alb", "sg_nlb", "sg_ec2"):
        if k in e:
            reintentar(lambda: ec2.delete_security_group(GroupId=e[k]), "DependencyViolation")
    ESTADO.unlink(missing_ok=True)
    print("Recursos eliminados")


# --------------------------------------------------------------------- todo
def todo():
    print("== 1. Entorno ==")
    entorno()
    print("\n== 2. NLB con la versión blue ==")
    nlb()
    time.sleep(20)
    probar(f"http://{leer_estado()['dns_nlb']}")
    print("\n== 3. Blue/Green: paso a la versión green ==")
    cambiar_version("green", "blue")
    time.sleep(10)
    probar(f"http://{leer_estado()['dns_nlb']}")
    print("\n== 4. Canary con ALB ==")
    canary()
    url = f"http://{leer_estado()['dns_alb']}"
    time.sleep(20)
    probar(url)
    for b, g in ((90, 10), (50, 50), (0, 100)):
        pesos(b, g)
        time.sleep(25)
        probar(url, 40)


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else "todo"
    acciones = {
        "todo": todo, "entorno": entorno, "nlb": nlb, "canary": canary, "limpiar": limpiar,
        "green": lambda: cambiar_version("green", "blue"),
        "blue": lambda: cambiar_version("blue", "green"),
        "pesos": lambda: pesos(int(sys.argv[2]), int(sys.argv[3])),
        "probar": lambda: probar(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20),
    }
    if orden not in acciones:
        sys.exit(__doc__)
    acciones[orden]()
