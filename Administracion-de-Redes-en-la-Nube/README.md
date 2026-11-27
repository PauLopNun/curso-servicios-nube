<div align="center">

# Administración de Redes en la Nube

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Scripting-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

Diseño de redes en AWS: VPC, subredes, direccionamiento, Internet Gateway, tablas de rutas y grupos de seguridad.

## Prácticas

| Práctica | Descripción |
|:--|:--|
| [Práctica 1 - Creación de redes públicas](Practica-1-Redes-Publicas) | EC2 en una red pública, VPC con subredes desde la consola y desde la CLI |
| [Práctica 1 - Creación de redes con scripts](Practica-1-Scripts-Crear-VPC) | VPC, subred y EC2 creados con un script `.sh` y otro de Boto3 |
| [Práctica 3 - Creación de redes privadas](Practica-3-Redes-Privadas) | VPC con subred pública (IGW) y privada (NAT Gateway) desde la consola y desde la CLI, paso a paso |
| [Práctica 4 - NAT Gateway regional](Practica-4-NAT-Regional) | Un único NAT regional para subredes privadas en varias zonas, expansión automática y AWS CLI |
| [Práctica 4 - Reglas encadenadas](Practica-4-Reglas-Encadenadas) | Bastión y servidor de aplicación con grupos de seguridad encadenados y reenvío de agente SSH (pendiente) |
| [Práctica 5 - ACLs personalizadas](Practica-5-ACLs-Personalizadas) | Grupos de seguridad con estado frente a NACL sin estado, comprobado con ping (pendiente) |
| [Scripting con Boto3](Scripting-Boto3) | Scripts en Python para comprobar la conexión, crear y eliminar una VPC con un EC2, listar y terminar instancias y controlar el gasto |

---

[Volver al inicio](../README.md)
