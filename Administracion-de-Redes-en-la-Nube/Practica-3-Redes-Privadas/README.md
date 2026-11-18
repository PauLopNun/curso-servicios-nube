<div align="center">

# Práctica 3 - Acceso al exterior: creación de redes privadas

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

## Objetivo

Montar una VPC con una subred pública (salida por Internet Gateway) y otra privada (salida por NAT Gateway), primero desde la consola y después con la AWS CLI, comprobando que no hay acceso al EC2 desde el exterior hasta que toda la infraestructura está creada.

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `172.16.0.0/16` |
| Subred pública | `172.16.0.0/20` |
| Subred privada | `172.16.64.0/20` |
| EC2 público | `172.16.0.100` |
| EC2 privado | `172.16.64.100` (el enunciado dice `172.64.0.100`, que queda fuera de la VPC) |

## Partes

### 1. Panel de control

- VPC creada con el asistente **VPC y más**: una AZ, subred pública y privada, IGW, NAT Gateway zonal y una tabla de rutas por subred
- Revisión del IGW adjunto y de las tablas: `0.0.0.0/0` hacia el IGW en la pública y hacia el NAT en la privada
- EC2 público con SSH desde el exterior (EC2 Instance Connect) y EC2 privado sin IP pública
- El EC2 privado sale a Internet con la IP elástica del NAT Gateway (comprobado con datos de usuario y el registro del sistema)

### 2. AWS CLI

```text
base -> 1. crear IGW -> 2. adjuntar a la VPC -> 3. crear tabla de rutas -> 4. ruta 0.0.0.0/0 -> 5. asociar a la subred
         sin acceso      sin acceso             sin acceso                 sin acceso           SSH funciona
```

Después, la subred privada: EC2 privado, NAT Gateway con IP elástica, tabla de rutas privada y asociación, comprobando la salida con `curl` desde el EC2 privado.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/config.sh`](scripts/config.sh) | Variables comunes y prueba de SSH |
| [`scripts/2_12igw.sh`](scripts/2_12igw.sh) | VPC, subred pública y EC2, y los cinco pasos del IGW |
| [`scripts/2_12pubpriv.sh`](scripts/2_12pubpriv.sh) | Subred privada con salida por NAT Gateway |
| [`scripts/limpieza.sh`](scripts/limpieza.sh) | Borra todo lo creado (el NAT se cobra por hora) |
| [`evidencias/`](evidencias) | Salida de cada paso de la CLI |
| [`capturas/`](capturas) | `con-*` consola, `cli-*` pasos del IGW, `nat-*` subred privada |
| [`entrega/LopezPau_Practica3.pdf`](entrega/LopezPau_Practica3.pdf) | Documento entregado |

---

[Volver a la asignatura](../README.md)
