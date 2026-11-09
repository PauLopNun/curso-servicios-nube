#!/bin/bash
# Servidor web con una página que muestra el color de la versión y el hostname.
# COLOR y NOMBRE se sustituyen al lanzar cada instancia.
dnf install -y httpd
systemctl enable --now httpd
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>NOMBRE</title></head>
<body style="background:COLOR;color:white;font-family:sans-serif;text-align:center;padding-top:15%">
  <h1>Versión NOMBRE</h1>
  <h2>Servidor: $(hostname -f)</h2>
</body>
</html>
HTML
