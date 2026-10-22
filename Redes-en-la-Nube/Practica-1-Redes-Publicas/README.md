<div align="center">

# Práctica 1 - Creación de redes públicas

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=for-the-badge&logo=apache&logoColor=white)

</div>

## Objetivo

Lanzar instancias EC2 dentro de una red pública: primero en la VPC por defecto, después en una VPC propia creada desde la consola y, por último, repetir el proceso con la AWS CLI.

## Partes

### 1. Instancia EC2

- AMI Ubuntu Server 22.04, `t2.micro`, par de claves `vockey`, disco de 10 GB `gp2`
- Grupo de seguridad con SSH, HTTP y HTTPS
- Perfil de instancia `LabInstanceProfile`
- [Datos de usuario](scripts/datos_usuario.sh) que instalan Apache y publican la IP privada y pública de la instancia

### 2. VPC desde la consola

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `172.16.0.0/16` |
| Subred SR1 | `172.16.0.0/20` |
| Subred SR2 | Creada después y asociada a la VPC |

- EC2 en SR1 con un grupo de seguridad nuevo
- EC2 en SR1 con un grupo de seguridad ya existente

### 3. AWS CLI

El script [`crea_vpc.sh`](scripts/crea_vpc.sh) crea toda la red y lanza una instancia dentro:

```text
VPC 10.20.0.0/16 -> subred 10.20.1.0/24 -> Internet Gateway -> tabla de rutas -> grupo de seguridad -> EC2
```

Se comprueba también que, sin Internet Gateway ni ruta `0.0.0.0/0`, la instancia no es accesible por SSH.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/crea_vpc.sh`](scripts/crea_vpc.sh) | Creación de la VPC y la instancia con la CLI |
| [`scripts/datos_usuario.sh`](scripts/datos_usuario.sh) | Datos de usuario de la instancia (Apache) |
| [`capturas/`](capturas) | Capturas numeradas de cada paso |
| [`entrega/LopezPau_Practica1.pdf`](entrega/LopezPau_Practica1.pdf) | Documento entregado |

---

[Volver a la asignatura](../README.md)
