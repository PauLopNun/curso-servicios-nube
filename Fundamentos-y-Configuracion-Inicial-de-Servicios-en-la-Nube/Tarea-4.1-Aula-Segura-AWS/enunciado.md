# Tarea 4.1. "Aula segura" con AWS

- Plataforma: AWS Academy Learner Lab, región us-east-1
- Duración prevista: 5 h en dos sesiones (fases 0 a 3 y fases 4 a 7)
- Entrega en Aules: un único fichero `fci_t4.1_apellido1_apellido2.zip`

Implementar un sistema tipo DMZ: una VPC con una subred pública (servidor web) y otra privada sin salida a Internet, que solo llega a S3 por un VPC Endpoint. El acceso al bucket se controla con una bucket policy y la monitorización se hace con CloudWatch.

## Fases

0. Preparación del entorno (credenciales, `labsuser.pem`, `index.html`)
1. Red por consola: `vpc-practica` (10.20.0.0/16), `sn-publica` y `sn-privada`, `igw-practica`, `rt-publica` y `rt-privada`, `sgr-web` y `sgr-privada`
2. Bucket `practica-<apellido>-<nº>` con `public/` y `private/`, endpoint Gateway `vpce-s3` y bucket policy (`SoloTLS` y `PrivateSoloDesdeEndpoint`)
3. `ec2-web` con User Data que instala Apache y descarga `index.html` de S3
4. `ec2-privada` por CLI con User Data que sube un informe a `private/`, pruebas de acceso y experimento quitando el endpoint
5. `nacl-privada` y reglas sin estado
6. CloudWatch: monitorización detallada, dashboard `aula-segura` y alarma `cpu-alta-ec2-web` probada con carga real
7. Reto: segunda VPC solo con CLI en un script `reto.sh`, y limpieza

## Entregables

- Capturas: web de `ec2-web`, listado de `private/` con el informe, AccessDenied de la prueba 4, tablas de rutas de las dos subredes, dashboard y alarma en ALARM
- `ud-privada.sh` y `reto.sh`
- Informe de 2 páginas como máximo con las 12 preguntas de comprensión y una tabla comparativa entre consola y CLI
