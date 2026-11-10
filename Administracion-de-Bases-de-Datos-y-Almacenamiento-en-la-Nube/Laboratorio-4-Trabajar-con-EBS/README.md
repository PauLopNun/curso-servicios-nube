<div align="center">

# Laboratorio 4 - Working with EBS

![EBS](https://img.shields.io/badge/AWS-EBS-FF9900?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![SSM](https://img.shields.io/badge/AWS-Systems%20Manager-232F3E?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizado-0366d6?style=for-the-badge)

**Laboratorio guiado de AWS Academy - sin entregable**

<img src="https://skillicons.dev/icons?i=aws,bash,linux" />

</div>

## Qué se pide

Crear un volumen EBS, conectarlo a la instancia **Lab**, darle un sistema de archivos ext3, hacer un snapshot y restaurarlo en un volumen nuevo para comprobar que los datos se recuperan. Resumen en [`enunciado.md`](enunciado.md).

## Qué se ha hecho

Todo desde la API de AWS y, dentro de la instancia, con SSM Run Command como `ec2-user` (los comandos están en [`comandos-instancia.sh`](scripts/comandos-instancia.sh)). Los nombres de los recursos son los que impone el laboratorio, porque el corrector los comprueba.

| Tarea | Resultado | Evidencia |
|:--|:--|:--|
| 1. Crear volumen | **My Volume** (`vol-0c8efcaed11b3246d`): gp2, 1 GiB, us-east-1a | [`01-02`](evidencias/01-02-volumen-crear-adjuntar.txt) |
| 2. Conectar | A la instancia Lab (`i-0f0618422d22d9f2c`) como `/dev/sdb` (en el sistema, `/dev/xvdb`) | [`01-02`](evidencias/01-02-volumen-crear-adjuntar.txt) |
| 4. Sistema de archivos | ext3 montado en `/mnt/data-store`, línea en `/etc/fstab` y `file.txt` escrito | [`04`](evidencias/04-sistema-de-archivos.txt) |
| 5. Snapshot | **My Snapshot** (`snap-0647a78e7c56b36f6`) completado; después se borra `file.txt` | [`05`](evidencias/05-snapshot.txt) |
| 6. Restaurar | **Restored Volume** (`vol-004988c1425e02c02`) como `/dev/sdc` en `/mnt/data-store2`: `file.txt` vuelve a estar | [`06`](evidencias/06-restaurar-snapshot.txt) |

Antes del snapshot se ejecuta `sync` para que lo escrito en el volumen esté realmente en disco y entre en la copia.

## Incidencia al arrancar el laboratorio

En la primera sesión la instancia Lab no llegó a arrancar: CloudFormation la creó dos veces y las dos se terminaron con `Client.InvalidKMSKey.InvalidState`. La cuenta tenía activado el cifrado EBS por defecto con una clave KMS que ya no existía, así que fallaba cualquier volumen nuevo, incluido el raíz. El rol del laboratorio no permite cambiar esa configuración (`ec2:ResetEbsDefaultKmsKeyId` denegado), y se solucionó reiniciando el laboratorio, que asignó una cuenta nueva.

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Comandos ejecutados dentro de la instancia |
| [`evidencias/`](evidencias) | Ids de los recursos y salida de cada tarea |

---

[Volver a la asignatura](../README.md)
