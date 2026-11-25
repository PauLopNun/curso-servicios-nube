#!/bin/bash
# Instala el servidor web Apache y sus dependencias
set -e
if command -v dnf >/dev/null 2>&1; then
  dnf update -y
  dnf install -y httpd
else
  yum update -y
  yum install -y httpd
fi
mkdir -p /var/www/html
