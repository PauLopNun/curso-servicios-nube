<div align="center">

# Práctica 4 - NAT Gateway regional

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![NAT](https://img.shields.io/badge/NAT-Regional-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

## Objetivo

Dar salida a Internet a subredes privadas de varias zonas con un único NAT Gateway regional, que no vive en ninguna subred, no necesita reservar una IP elástica y se expande solo a las zonas nuevas.

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `172.16.0.0/16` |
| Subredes públicas | `172.16.0.0/20` y `172.16.16.0/20` |
| Subredes privadas | `172.16.64.0/20` (1a), `172.16.80.0/20` (1b) y `172.16.96.0/20` (1c) |
| Bastión | `172.16.0.100` |
| Instancias privadas | `172.16.64.100`, `172.16.80.100` y `172.16.96.100` |

## Resultado

| Comprobación | Resultado |
|:--|:--|
| Privadas sin NAT | `curl` agota el tiempo de espera |
| NAT creado, sin rutas | Siguen sin salir |
| `privada-A` (1a) con ruta al NAT | Sale por `44.215.217.196`, la IP del NAT en 1a |
| `privada-B` (1b) con ruta al mismo NAT | Sale por `3.209.88.203`, la IP del NAT en 1b |
| `privada-C` (1c) durante la expansión | Sale por la IP de 1a |
| `privada-C` tras la expansión | Sale por `34.205.219.191`, la IP del NAT en 1c |
| AWS CLI | Una sola tabla privada para las dos zonas |

## Notas

- La expansión a la tercera zona tardó unos 25 minutos.
- Tras asociar la tabla, la ruta tardó más de 15 segundos en dar salida; el script espera 60.
- Los grupos se llaman `sgbastion` y `sgprivadas` porque AWS no admite nombres que empiecen por `sg-`.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/nat_regional.sh`](scripts/nat_regional.sh) | Monta el escenario con la CLI y comprueba la salida |
| [`scripts/limpieza.sh`](scripts/limpieza.sh) | Borra lo creado, en el orden del enunciado |
| [`evidencias/`](evidencias) | Identificadores y salidas de las pruebas |
| [`capturas/`](capturas) | Capturas de cada paso |
| [`entrega/LopezPau_Practica4.pdf`](entrega/LopezPau_Practica4.pdf) | Documento de entrega |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
