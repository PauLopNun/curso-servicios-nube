<div align="center">

# Tarea 1.1 - Cambiar el tipo de una instancia con AWS CLI

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![CLI](https://img.shields.io/badge/AWS%20CLI-v2-232F3E?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

**UD01 - Servicios computacionales basados en máquinas virtuales**

</div>

## Objetivo

Automatizar el cambio de tipo de una instancia EC2 (*rightsizing*) con un script de Bash que use la AWS CLI. El script debe ser seguro: comprobar los datos antes de tocar nada, actuar solo sobre instancias propias y respetar las restricciones del Learner Lab.

## Uso

```bash
./scripts/cambia_tipo_ec2.sh i-0a1b2c3d4e5f67890 t3.small
./scripts/cambia_tipo_ec2.sh -y i-0a1b2c3d4e5f67890 t3a.micro   # sin confirmar
```

## Funcionamiento

```text
detener  ->  esperar a que pare  ->  cambiar el tipo  ->  arrancar  ->  esperar a que arranque
```

Antes de hacer el cambio, el script comprueba:

| Comprobación | Código de salida |
|:--|:-:|
| Opciones y número de parámetros correctos | 1 |
| La instancia existe | 2 |
| Tiene la etiqueta `Propietario=PLN` | 3 |
| No está terminada ni terminándose | 4 |
| El tipo existe, su tamaño está permitido en el Learner Lab y admite la arquitectura de la instancia | 5 |
| El usuario confirma (salvo con `-y`) | 6 |
| Los pasos de detener, cambiar y arrancar terminan bien | 7 |

**Ampliación:** se comprueba que el tipo nuevo admite la arquitectura de la instancia (por ejemplo, un `t4g` es ARM y no arrancaría con una AMI `x86_64`).

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/cambia_tipo_ec2.sh`](scripts/cambia_tipo_ec2.sh) | Script de la tarea |
| [`capturas/`](capturas) | Pruebas en la terminal: casos correctos (`P`), errores (`E`), ampliación (`X`) y limpieza |
| [`entrega/LopezPau_Tarea1-1.pdf`](entrega/LopezPau_Tarea1-1.pdf) | Documento entregado |
| [`entrega/Guia_estudio_Tarea1-1.pdf`](entrega/Guia_estudio_Tarea1-1.pdf) | Guía de estudio de la tarea |
| [`enunciado.md`](enunciado.md) | Enunciado de Aules |

---

[Volver a la asignatura](../README.md)
