#!/bin/bash
# Datos de usuario de webmin-pln-template (v2)
set -e   # al primer error se detiene y cloud-init lo marca como error

# 1. Nombre de la instancia (etiqueta Name) con IMDSv2
IMDS=http://169.254.169.254/latest
TOKEN=$(curl -s -X PUT $IMDS/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
NOMBRE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  $IMDS/meta-data/tags/instance/Name)

# 2. Nombre de host fijo, aunque cloud-init vuelva a ejecutarse
hostnamectl set-hostname "$NOMBRE"
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-hostname.cfg

# 3. Webmin desde su repositorio oficial, sin preguntas
export DEBIAN_FRONTEND=noninteractive
curl -fsSL -o /tmp/webmin-setup-repo.sh \
  https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
sh /tmp/webmin-setup-repo.sh --force
apt-get install -y --install-recommends webmin

# 4. Contraseña aleatoria de root de Webmin
#    - SOLO si no existe ya /root/webmin-pass.txt (permisos 600)
if [ ! -f /root/webmin-pass.txt ]; then
  umask 077
  PASS=$(openssl rand -base64 12)
  /usr/share/webmin/changepass.pl /etc/webmin root "$PASS"
  echo "$PASS" > /root/webmin-pass.txt
  chmod 600 /root/webmin-pass.txt
fi
