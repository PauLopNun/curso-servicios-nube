<div align="center">

# Scripting con Boto3

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Boto3](https://img.shields.io/badge/AWS-Boto3-FF9900?style=for-the-badge&logoColor=white)

</div>

## Objetivo

Scripts en Python con Boto3 (el SDK de AWS) para comprobar la conexión con el Learner Lab, crear y eliminar una red con un EC2 y controlar los recursos y el gasto.

## Scripts

| Script | Descripción |
|:--|:--|
| [`menu.py`](menu.py) | Menú para lanzar cualquiera de los scripts siguientes |
| [`comprobar_conexion.py`](comprobar_conexion.py) | Comprueba que las credenciales funcionan y muestra la cuenta, el ARN y la región |
| [`crear_vpc_ec2.py`](crear_vpc_ec2.py) | Crea una VPC con DNS, una subred pública y otra privada, Internet Gateway, tabla de rutas y grupo de seguridad, y lanza un EC2 con Apache en la subred pública. Todo lleva la etiqueta `CreadoPor=Boto3` |
| [`listar_recursos.py`](listar_recursos.py) | Lista las instancias (estado, tipo, IP, VPC, hora de lanzamiento), las VPC con sus subredes, IGW y grupos de seguridad, y los volúmenes e IP elásticas sin usar. Señala con `[Boto3]` lo creado por `crear_vpc_ec2.py` |
| [`terminar_instancias.py`](terminar_instancias.py) | Muestra las instancias EC2 de la región, pide confirmación, las termina y espera a que acaben |
| [`eliminar_vpc.py`](eliminar_vpc.py) | Deja elegir qué VPC eliminar (nunca la de por defecto), por número, todas o solo las marcadas con `[Boto3]`, y borra todo su contenido en orden: instancias, grupos de seguridad, IGW, subredes, tablas de rutas y la VPC |
| [`cost_guard.py`](cost_guard.py) | Estima el gasto, termina instancias que superan el presupuesto o llevan más de 4 horas encendidas (salvo la etiqueta `KeepAlive=true`) y elimina volúmenes EBS e IP elásticas sin usar. Se puede ejecutar en local o como función Lambda |

## Uso

Las credenciales se leen de `~/.aws/credentials`, copiadas desde la consola del Learner Lab.

```bash
pip install boto3
python3 menu.py
```

Cada script también se puede ejecutar por separado, por ejemplo `python3 listar_recursos.py`.

Los scripts actúan sobre la cuenta de las credenciales que haya en ese momento en `~/.aws/credentials`. Si cambias de Learner Lab, cambia la cuenta. Por eso los scripts muestran primero el número de cuenta, y los que crean o borran piden confirmación (salvo `cost_guard.py`, pensado para ejecutarse solo).

`terminar_instancias.py`, `eliminar_vpc.py` y `cost_guard.py` eliminan recursos, así que conviene ejecutar antes `listar_recursos.py` para ver qué hay en la cuenta.

---

[Volver a la asignatura](../README.md)
