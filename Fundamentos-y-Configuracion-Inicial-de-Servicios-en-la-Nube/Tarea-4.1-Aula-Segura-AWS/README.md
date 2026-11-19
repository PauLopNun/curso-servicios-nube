<div align="center">

# Tarea 4.1 - Aula segura con AWS

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![S3](https://img.shields.io/badge/AWS-S3-569A31?style=for-the-badge&logoColor=white)
![CloudWatch](https://img.shields.io/badge/AWS-CloudWatch-FF4F8B?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**UP4 - Acceso y administración**

<img src="https://skillicons.dev/icons?i=aws,bash,linux" />

</div>

## Qué se pide

Montar una DMZ en AWS: una subred pública con un servidor web y una privada sin salida a Internet que solo llega a S3 por un VPC Endpoint, con el acceso al bucket controlado por una bucket policy y monitorización con CloudWatch. Resumen en [`enunciado.md`](enunciado.md).

## Qué se ha hecho

Hecho el 19/11/2026 en el Learner Lab (us-east-1). Las fases 1 a 3 por consola y las 4 a 7 con la CLI, guardando cada comando y su salida en [`evidencias/`](evidencias).

| Fase | Resultado |
|:--|:--|
| 1. Red | `vpc-practica` 10.20.0.0/16; `sn-publica` 10.20.1.0/24 con IP pública automática y `sn-privada` 10.20.2.0/24; `rt-publica` con 0.0.0.0/0 al IGW y `rt-privada` solo con la ruta local; `sgr-web` (80 abierto, 22 desde la IP del aula) y `sgr-privada` (22 e ICMP desde `sgr-web`) |
| 2. S3 y endpoint | Bucket `practica-lopez-26119` con `public/index.html` y `private/`; endpoint Gateway `vpce-s3` en `rt-privada` (ruta `pl-63a5400a`); [política](scripts/bucket-policy.json) con `SoloTLS` y `PrivateSoloDesdeEndpoint` |
| 3. ec2-web | Amazon Linux 2023, IMDSv2 obligatorio y `LabInstanceProfile`; el [User Data](scripts/ud-web.sh) instala Apache y rellena la página con el ID, la zona y la IP privada |
| 4. ec2-privada | Lanzada por CLI; su [User Data](scripts/ud-privada.sh) sube el informe a `private/` por el endpoint. Sin Internet (curl con código 28), lectura de `private/` desde dentro y AccessDenied desde fuera. Al quitar el endpoint, S3 deja de responder |
| 5. NACL | `nacl-privada` con 22 y efímeros de entrada, 443 y efímeros de salida. El ping deja de funcionar y, sin la regla 110 de entrada, S3 falla pero el SSH no |
| 6. CloudWatch | Monitorización detallada, [dashboard](scripts/dashboard-aula-segura.json) `aula-segura` y alarma `cpu-alta-ec2-web`, que pasa a ALARM con `yes` en los dos núcleos y vuelve a OK |
| 7. Reto | [`reto.sh`](scripts/reto.sh) crea `vpc-reto` y `ec2-reto` de principio a fin y `./reto.sh limpiar` lo borra todo |

El `labsuser.pem` guardado era de otra sesión del laboratorio, así que los saltos SSH se hicieron con una clave temporal enviada con EC2 Instance Connect.

## Entrega

[`entrega/fci_t4.1_lopez_nunez.zip`](entrega/fci_t4.1_lopez_nunez.zip) con el [informe](entrega/informe_fci_t4.1_lopez_nunez.pdf) (12 preguntas y tabla consola frente a CLI), las capturas y los scripts.

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | `index.html`, User Data de las dos instancias, política del bucket, dashboard y `reto.sh` |
| [`evidencias/`](evidencias) | Comandos y salidas de las fases 4 a 7 y datos de los recursos |
| [`capturas/`](capturas) | Capturas de la consola y del terminal |
| [`entrega/`](entrega) | Informe en DOCX y PDF y el zip entregado |

---

[Volver a la asignatura](../README.md)
