#!/bin/bash
# Actualizar repositorio e instalar dependencias
sudo yum update -y
sudo yum install -y wget

# Agregar repositorio de Grafana
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
EOF

# Instalar Grafana
sudo yum install grafana -y

# Iniciar y habilitar el servicio de Grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Abrir puerto 3000 para acceso a Grafana
sudo firewall-cmd --zone=public --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
