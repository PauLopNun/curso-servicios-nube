<div align="center">

# Práctica 5 - ACLs personalizadas

![VPC](https://img.shields.io/badge/AWS-VPC-8C4FFF?style=for-the-badge&logoColor=white)
![NACL](https://img.shields.io/badge/Network-ACL-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)

</div>

## Objetivo

Demostrar con `ping` que los grupos de seguridad tienen estado (la respuesta vuelve sola) y las ACL de red no (hace falta una regla de salida explícita).

| Prueba | Resultado esperado |
|:--|:--|
| Grupo de seguridad con ICMP solo de entrada | El ping responde |
| NACL con ICMP solo de entrada | El ping no responde |
| NACL con ICMP de entrada y de salida | El ping responde |

## Estado

Pendiente de realizar. El guion resumido está en [enunciado.md](enunciado.md).

---

[Volver a la asignatura](../README.md)
