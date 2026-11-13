# Práctica 3: acceso al exterior. Creación de redes privadas

- Curso: Administración de redes en la nube
- Documento original: `aws2_12pubpriv.pdf`

## Escenario

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `172.16.0.0/16` |
| Subred pública | `172.16.0.0/20` |
| Subred privada | `172.16.64.0/20` |
| EC2 de la subred pública | `172.16.0.100/20` |
| EC2 de la subred privada | `172.64.0.100/20` en el enunciado (errata: fuera de la VPC; se usa `172.16.64.100`) |

El esquema muestra un Internet Gateway para la VPC y un NAT Gateway dentro de la subred pública que da salida a la privada.
Referencia: <https://docs.aws.amazon.com/es_es/vpc/latest/userguide/vpc-nat.html>

## Qué se pide

1. **Panel de control**: montar el escenario desde la consola y revisar las opciones y tablas de enrutamiento:
   crear la VPC y las subredes, lanzar el EC2 con su grupo de seguridad (SSH desde el exterior) indicando la VPC y la subred,
   comprobar que el IGW está asociado a la VPC, revisar las tablas de rutas y entrar por SSH.
2. **AWS CLI**: reutilizar los scripts anteriores (VPC, subred, EC2 y grupo de seguridad) y añadir:
   1. Crear el IGW
   2. Adjuntar el IGW a la VPC
   3. Crear una tabla de enrutamiento
   4. Agregar la ruta de salida a Internet
   5. Asociar la tabla de enrutamiento a la subred

Capturas de cada paso comprobando que funciona: no hay acceso al EC2 desde el exterior hasta que toda la infraestructura está creada (solución: `2_12igw.sh`).
Referencia: <https://docs.aws.amazon.com/es_es/vpc/latest/userguide/WorkWithRouteTables.html#SubnetRouteTables>
