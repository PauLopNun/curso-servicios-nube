#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive

# 1. Paquetes (metapaquetes sin versión: valen para cualquier Ubuntu LTS)
apt-get update
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql
systemctl enable --now apache2 mariadb

# 2. Metadatos con IMDSv2: se pide un token y se usa en cada consulta
IMDS=http://169.254.169.254/latest
TOKEN=$(curl -fsS -X PUT "$IMDS/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/$1"; }
ID=$(md instance-id)
TIPO=$(md instance-type)
AZ=$(md placement/availability-zone)
IP=$(md public-ipv4 || echo "sin IP pública")
NOMBRE=$(md tags/instance/Name || echo "sin etiqueta Name")

# 3. Página de inicio con los datos de la instancia y prueba de PHP
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>$NOMBRE</title></head>
<body>
<h1>Servidor LAMP: $NOMBRE</h1>
<ul>
<li>Instancia: $ID ($TIPO)</li>
<li>Zona de disponibilidad: $AZ</li>
<li>IP pública en el primer arranque: $IP</li>
<li>Desplegado: $(date -Is)</li>
</ul>
</body></html>
EOF
echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php
chown -R www-data:www-data /var/www/html
