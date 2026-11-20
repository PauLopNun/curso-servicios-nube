#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 stress-ng

# Página de inicio personalizada
URL=http://169.254.169.254/latest
TOKEN=$(curl -s -X PUT $URL/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  $URL/meta-data/instance-id)
echo "<h1>Servidor web de Pau López Núñez</h1><p>Instancia $ID</p>" \
  > /var/www/html/index.html

# Agente de CloudWatch
CWA=https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest
curl -s -o /tmp/cwagent.deb $CWA/amazon-cloudwatch-agent.deb
dpkg -i /tmp/cwagent.deb
rm /tmp/cwagent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c ssm:/web-pln/agente
