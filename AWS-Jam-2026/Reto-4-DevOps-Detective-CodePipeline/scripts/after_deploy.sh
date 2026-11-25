#!/bin/bash
# Copia la web a la raíz de Apache (si se desplegó en otra carpeta) y arranca el servidor
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
if [ "$SRC" != "/var/www/html" ]; then
  cp -f "$SRC/index.html" "$SRC/styles.css" "$SRC/script.js" /var/www/html/
fi
systemctl enable httpd
systemctl restart httpd
