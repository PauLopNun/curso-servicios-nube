<div align="center">

# Actividad 1.7 - Plantilla de lanzamiento LAMP, IP elástica y Session Manager

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![SSM](https://img.shields.io/badge/Systems%20Manager-Session%20Manager-232F3E?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-En%20curso-dbab09?style=for-the-badge)

**UD01 - Servicios computacionales basados en máquinas virtuales**

</div>

## Objetivo

Desplegar un servidor LAMP con una plantilla de lanzamiento versionada (datos de usuario con cloud-init e IMDSv2 obligatorio), darle una IP elástica y administrarlo con Session Manager sin claves SSH ni puerto 22 abierto.

## Progreso

| Parte | Descripción | Estado |
|:-:|:--|:-:|
| 1 | Preparación: instancias de actividades anteriores detenidas | Hecho |
| 2 | Grupo de seguridad `lamp-sg` (HTTP 80 y SSH 22 temporal) | Hecho |
| 3 | Plantilla `lamp-template` v1 creada (`lt-0473729728a39e1a9`) | Hecho |
| 3 | Lanzar `lamp-server` desde la plantilla y comprobar cloud-init | Pendiente |
| 4-11 | IP elástica, Session Manager, cierre de SSH, IMDSv2, v2, instancias extra, limpieza | Pendiente |

## Plantilla v1

| Opción | Valor |
|:--|:--|
| AMI | Ubuntu Server 26.04 LTS x86_64 (`ami-0d97d7f07b25dd693`) |
| Tipo | `t3.micro` |
| Par de claves | `vockey` (solo en v1) |
| Grupo de seguridad | `lamp-sg` |
| Almacenamiento | 8 GiB gp3 cifrado |
| Perfil de IAM | `LabInstanceProfile` |
| Metadatos | Habilitados, solo IMDSv2, etiquetas en metadatos habilitadas |
| Datos de usuario | [`scripts/user-data-v1.sh`](scripts/user-data-v1.sh) |

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/user-data-v1.sh`](scripts/user-data-v1.sh) | Datos de usuario de la versión 1 (instalación LAMP) |
| [`capturas/`](capturas) | Capturas de la consola y del terminal, numeradas por orden |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
