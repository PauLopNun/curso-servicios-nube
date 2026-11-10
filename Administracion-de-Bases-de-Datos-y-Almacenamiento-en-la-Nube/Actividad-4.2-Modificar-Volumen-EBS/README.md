<div align="center">

# Actividad 4.2 - Modificación de un volumen EBS

![EBS](https://img.shields.io/badge/AWS-EBS-FF9900?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-AWS%20CLI-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**UD04 - Servicios de almacenamiento de bloques**

<img src="https://skillicons.dev/icons?i=aws,bash,linux" />

</div>

## Qué se pide

El enunciado ([PDF](material/enunciado-modificar-volumen-ebs.pdf), resumen en [`enunciado.md`](enunciado.md)) pide ampliar el volumen raíz de una instancia EC2 Linux de 8 GB a 10 GB con la AWS CLI: localizar el volumen, hacer un snapshot de seguridad, modificar el volumen, ampliar la partición y el sistema de archivos y borrar el snapshot. Es una tarea guiada sin entregable, pero se ha preparado igualmente el documento.

## Qué se ha hecho

Hecho en el Learner Lab (us-east-1) con la AWS CLI desde el equipo local. Los comandos dentro de la instancia se ejecutan con SSM Run Command como `ec2-user` gracias a `LabInstanceProfile`, sin SSH.

| Paso | Script | Resultado |
|:--|:--|:--|
| 1. Instancia | [`01-crear-instancia.sh`](scripts/01-crear-instancia.sh) | `ec2-pln`: Amazon Linux 2023, `t3.micro`, `vockey`, 8 GB gp3, en us-east-1b |
| 2-3. Volumen y particiones | [`02-informacion.sh`](scripts/02-informacion.sh) | Volumen raíz `vol-0a12169682acc42f2`; disco `nvme0n1` de 8 GB con `/` en XFS |
| 4. Snapshot | [`03-snapshot.sh`](scripts/03-snapshot.sh) | `sna-pln` (`snap-03c8269fd5526102b`) de `pending` a `completed` |
| 5. Modificar a 10 GB | [`04-modificar-volumen.sh`](scripts/04-modificar-volumen.sh) | `modifying` → `optimizing` → `completed` en unos 5 minutos |
| 6. Partición y sistema de archivos | `04-modificar-volumen.sh` | Nitro, así que `growpart /dev/nvme0n1 1` y `xfs_growfs -d /`: `/` pasa de 8 GB a 10 GB |
| 7. Limpieza | [`05-limpiar.sh`](scripts/05-limpiar.sh) | Snapshot borrado e instancia terminada (el volumen se borra con ella) |

### Antes y después

| | Volumen EBS | Partición `nvme0n1p1` | Sistema de archivos `/` |
|:--|:-:|:-:|:-:|
| Antes | 8 GiB | 8 G | 8,0 G (6,4 G libres) |
| Después de `modify-volume` | 10 GiB | 8 G | 8,0 G |
| Después de `growpart` | 10 GiB | 10 G | 8,0 G |
| Después de `xfs_growfs` | 10 GiB | 10 G | 10 G (8,4 G libres) |

## Cómo reproducirlo

Con las credenciales del Learner Lab en `~/.aws/credentials`:

```bash
cd scripts
./01-crear-instancia.sh
./02-informacion.sh
./03-snapshot.sh
./04-modificar-volumen.sh
./05-limpiar.sh
```

Cada script muestra el comando, lo ejecuta y guarda comando y salida en [`evidencias/`](evidencias). Los ids se pasan de un script a otro en `evidencias/estado.env`, que no se sube al repositorio.

## Entrega

Documento: [`entrega/ebs_a42_lopez_nunez.docx`](entrega/ebs_a42_lopez_nunez.docx) (también en [PDF](entrega/ebs_a42_lopez_nunez.pdf)), con los comandos y las capturas de cada paso. Las capturas de [`capturas/`](capturas) son la salida real del terminal guardada en `evidencias/`.

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Scripts de la AWS CLI, uno por paso |
| [`evidencias/`](evidencias) | Salida de cada script en la ejecución real |
| [`capturas/`](capturas) | Capturas del terminal de cada paso |
| [`entrega/`](entrega) | Documento de entrega en DOCX y PDF |
| [`material/`](material) | Enunciado en PDF |

---

[Volver a la asignatura](../README.md)
