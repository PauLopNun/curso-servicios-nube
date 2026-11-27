<div align="center">

# Práctica 4 - Reglas encadenadas

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![SSH](https://img.shields.io/badge/SSH-Bastion-232F3E?style=for-the-badge&logoColor=white)

</div>

## Objetivo

Acceder a un servidor de aplicación solo a través de un bastión, encadenando grupos de seguridad: la aplicación admite SSH únicamente cuando el origen es el grupo del bastión, y la clave privada de la aplicación nunca se copia al bastión (reenvío de agente con `ssh -A`).

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `10.0.0.0/16` |
| Subred pública | `10.0.1.0/24` |
| Bastión | `10.0.1.20` |
| Aplicación | `10.0.1.30` |

## Estado

Pendiente de realizar. El guion resumido está en [enunciado.md](enunciado.md).

---

[Volver a la asignatura](../README.md)
