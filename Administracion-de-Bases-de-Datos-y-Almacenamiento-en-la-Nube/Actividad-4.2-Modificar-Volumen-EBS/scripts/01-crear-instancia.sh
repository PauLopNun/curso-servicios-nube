#!/usr/bin/env bash
# Paso 1: instancia Amazon Linux t3.micro con vockey, 8 GB y LabInstanceProfile
set -euo pipefail
source "$(dirname "$0")/config.sh"
LOG="$EVID/01-crear-instancia.txt"; : > "$LOG"

# Última AMI de Amazon Linux 2023 publicada por AWS en Parameter Store
run aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

run aws ec2 run-instances --image-id "$AMI" --instance-type "$TIPO" --key-name "$CLAVE" \
  --iam-instance-profile Name="$PERFIL" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$TAM_INICIAL,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NOMBRE}]" \
  --query 'Instances[0].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone]' --output table

INSTANCIA=$(aws ec2 describe-instances --filters Name=tag:Name,Values="$NOMBRE" Name=instance-state-name,Values=pending,running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "INSTANCIA=$INSTANCIA" > "$ESTADO"

run aws ec2 wait instance-running --instance-ids "$INSTANCIA"
echo "Esperando a que la instancia aparezca en Systems Manager..."
until [ "$(aws ssm describe-instance-information --filters Key=InstanceIds,Values="$INSTANCIA" \
  --query 'InstanceInformationList[0].PingStatus' --output text)" = "Online" ]; do sleep 5; done
run aws ssm describe-instance-information --filters Key=InstanceIds,Values="$INSTANCIA" \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformName,PlatformVersion]' --output table
