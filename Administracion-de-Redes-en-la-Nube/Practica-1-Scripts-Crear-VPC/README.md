<div align="center">

# Práctica 1 - Creación de redes con scripts

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Scripting-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Python-Boto3-3776AB?style=for-the-badge&logo=python&logoColor=white)

</div>

## Objetivo

Crear una VPC, una subred y un EC2 con un script de la CLI y otro de Boto3, y comprobarlo en el panel de control.

## Resultado

| Script | VPC | Subred | IP privada | IP pública |
|:--|:--|:--|:--|:--|
| [`crear_vpc.sh`](scripts/crear_vpc.sh) | 172.16.0.0/16 | 172.16.0.0/20 | 172.16.6.99 | No tiene |
| [`crear_vpc.py`](scripts/crear_vpc.py) | 172.16.0.0/16 | 172.16.0.0/20 | 172.16.12.247 | No tiene |

Sin Internet Gateway ni ruta `0.0.0.0/0` no hay conexión desde el exterior con el EC2.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Script de la CLI y script de Boto3 |
| [`capturas/`](capturas) | Ejecución en la terminal y recursos en el panel de control |
| [`entrega/LopezPau_Practica1_Scripts.pdf`](entrega/LopezPau_Practica1_Scripts.pdf) | Documento para entregar |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
