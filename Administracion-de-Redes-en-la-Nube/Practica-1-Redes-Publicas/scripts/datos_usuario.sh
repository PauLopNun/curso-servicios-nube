#!/bin/bash
# Datos de usuario de la instancia lopez_pau (se ejecuta como root en el primer arranque)
apt-get update -y
apt-get install -y apache2
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IP_PRIV=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
IP_PUB=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
cat > /var/www/html/index.html <<EOF
<h1>lopez_pau - Practica 1 Redes publicas</h1>
<p>Host: $(hostname)</p>
<p>IP privada: $IP_PRIV</p>
<p>IP publica: $IP_PUB</p>
EOF
chmod 644 /var/www/html/index.html
systemctl enable --now apache2
