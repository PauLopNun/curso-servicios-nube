#!/usr/bin/env python3
# Práctica 1 - Crea una VPC, una subred y un EC2 dentro con Boto3
# Pau López Núñez

import sys

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-1"
ZONA = "us-east-1a"
AMI_ID = "ami-033ea4ff4a9c726dc"  # Ubuntu Server 22.04 (Canonical)

ec2 = boto3.client("ec2", region_name=REGION)


def nombre(tipo, valor):
    return [{"ResourceType": tipo, "Tags": [{"Key": "Name", "Value": valor}]}]


def crear_vpc():
    vpc_id = ec2.create_vpc(
        CidrBlock="172.16.0.0/16",
        TagSpecifications=nombre("vpc", "lopez_pau-vpc-boto3"),
    )["Vpc"]["VpcId"]
    ec2.get_waiter("vpc_available").wait(VpcIds=[vpc_id])
    print(f"VPC creada: {vpc_id}")
    return vpc_id


def crear_subred(vpc_id):
    subred_id = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock="172.16.0.0/20",
        AvailabilityZone=ZONA,
        TagSpecifications=nombre("subnet", "lopez_pau-subred-boto3"),
    )["Subnet"]["SubnetId"]
    print(f"Subred creada: {subred_id}")
    return subred_id


def crear_ec2(subred_id):
    inst_id = ec2.run_instances(
        ImageId=AMI_ID,
        InstanceType="t2.micro",
        KeyName="vockey",
        SubnetId=subred_id,
        MinCount=1,
        MaxCount=1,
        TagSpecifications=nombre("instance", "lopez_pau-ec2-boto3"),
    )["Instances"][0]["InstanceId"]
    print(f"Instancia creada: {inst_id}")

    ec2.get_waiter("instance_running").wait(InstanceIds=[inst_id])
    inst = ec2.describe_instances(InstanceIds=[inst_id])["Reservations"][0]["Instances"][0]
    print(f"Estado: {inst['State']['Name']}")
    print(f"IP privada: {inst['PrivateIpAddress']}")
    print(f"IP pública: {inst.get('PublicIpAddress', 'no tiene')}")


def main():
    try:
        vpc_id = crear_vpc()
        subred_id = crear_subred(vpc_id)
        crear_ec2(subred_id)
        return 0
    except ClientError as e:
        print(f"Error de AWS: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
