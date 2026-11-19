#!/bin/bash
exec > /var/log/userdata-practica.log 2>&1
export AWS_DEFAULT_REGION=us-east-1
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
echo "Informe de $IID generado $(date -u)" > /tmp/informe.txt
aws s3 cp /tmp/informe.txt s3://__BUCKET__/private/informe-$IID.txt
