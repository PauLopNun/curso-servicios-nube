<div align="center">

# Scripting con Boto3

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Boto3](https://img.shields.io/badge/AWS-Boto3-FF9900?style=for-the-badge&logoColor=white)

</div>

## Objetivo

Scripts en Python con Boto3 (el SDK de AWS) para comprobar la conexión con el Learner Lab y controlar los recursos y el gasto.

## Scripts

| Script | Descripción |
|:--|:--|
| [`comprobar_conexion.py`](comprobar_conexion.py) | Muestra la identidad de las credenciales, las VPC y las instancias EC2 de la región |
| [`crear_vpc_ec2.py`](crear_vpc_ec2.py) | Crea una VPC con DNS, una subred pública y otra privada, Internet Gateway, tabla de rutas y grupo de seguridad, y lanza un EC2 con Apache en la subred pública |
| [`listar_recursos.py`](listar_recursos.py) | Lista las instancias (estado, tipo, IP, VPC, hora de lanzamiento), las VPC con sus subredes, IGW y grupos de seguridad, y los volúmenes e IP elásticas sin usar |
| [`terminar_instancias.py`](terminar_instancias.py) | Muestra las instancias EC2 de la región, pide confirmación, las termina y espera a que acaben |
| [`eliminar_vpc.py`](eliminar_vpc.py) | Deja elegir qué VPC eliminar (nunca la de por defecto) y borra todo su contenido en orden: instancias, grupos de seguridad, IGW, subredes, tablas de rutas y la VPC |
| [`cost_guard.py`](cost_guard.py) | Estima el gasto, termina instancias que superan el presupuesto o llevan más de 4 horas encendidas (salvo la etiqueta `KeepAlive=true`) y elimina volúmenes EBS e IP elásticas sin usar. Se puede ejecutar en local o como función Lambda |

## Uso

Las credenciales se leen de `~/.aws/credentials`, copiadas desde la consola del Learner Lab.

```bash
pip install boto3
python3 comprobar_conexion.py
```

Los scripts actúan sobre la cuenta de las credenciales que haya en ese momento en `~/.aws/credentials`. Si cambias de Learner Lab, cambia la cuenta. Por eso todos muestran primero el número de cuenta, y los que crean o borran piden confirmación.

`terminar_instancias.py`, `eliminar_vpc.py` y `cost_guard.py` eliminan recursos, así que conviene ejecutar antes `listar_recursos.py` para ver qué hay en la cuenta.

---

[Volver a la asignatura](../README.md)
