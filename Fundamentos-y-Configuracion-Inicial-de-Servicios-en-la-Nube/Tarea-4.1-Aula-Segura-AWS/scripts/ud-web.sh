#!/bin/bash
exec > /var/log/userdata-practica.log 2>&1
set -x
export AWS_DEFAULT_REGION=us-east-1
BUCKET=__BUCKET__

dnf install -y httpd

TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/$1; }
ID=$(md instance-id)
AZ=$(md placement/availability-zone)
IP=$(md local-ipv4)

aws s3 cp s3://$BUCKET/public/index.html /var/www/html/index.html
sed -i "s/__ID__/$ID/; s/__AZ__/$AZ/; s/__IP__/$IP/" /var/www/html/index.html
systemctl enable --now httpd
