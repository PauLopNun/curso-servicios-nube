<div align="center">

# Tarea 2.3 - AWS Backup

![Backup](https://img.shields.io/badge/AWS-Backup-3F8624?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![EFS](https://img.shields.io/badge/AWS-EFS-FF9900?style=for-the-badge&logoColor=white)
![RDS](https://img.shields.io/badge/AWS-RDS-527FFF?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**Laboratorio de SkillBuilder Multi-Service Backup Management with AWS Backup (SAL-TF-100-STBACK-1)**

<img src="https://skillicons.dev/icons?i=aws" />

</div>

## Qué se pide

Proteger una instancia EC2, un sistema de archivos EFS y una base de datos RDS con AWS Backup: almacén cifrado, copias bajo demanda, un plan de copias cada hora y selección de recursos por etiqueta. Basta con enseñar la configuración y la ejecución de cada paso. Resumen en [`enunciado.md`](enunciado.md).

## Realización

Hecho desde la consola (en castellano) el 24/11/2026, región us-east-1. Los nombres son los que pide el laboratorio.

| Tarea | Resultado |
|:--|:--|
| 1. Ajustes y almacén | EC2, EFS y RDS habilitados en *Activación del servicio*; almacén **Lab-Backup-Vault** cifrado con `aws/backup` |
| 2. Copias bajo demanda | `Lab1-EC2`, `Lab1-EFS` y `lab1-rds` con 3 días de retención y el rol `AWSBackupWorkshopRole`: tres trabajos completados y tres puntos de recuperación (AMI, copia de EFS e instantánea de RDS) |
| 3. Plan de copias | **HourlyBackupPlan-Lab1** con la regla `HourlyBackupRule`: cada hora desde las 17:57 (Europe/Madrid), inicio en 1 h, fin en 2 h, retención de 3 días; asignación `HourlyPlanResourceAssignment` para todos los tipos de recurso con `backup = hourly` |
| 4. Etiquetas | `backup = hourly` en los tres recursos, vista previa de las próximas 10 ejecuciones y trabajos del plan en *Trabajos* |

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`capturas/`](capturas) | Capturas de la configuración y la ejecución de cada paso |
| [`entrega/`](entrega) | Documento de la Tarea 2.3 (fuente en Markdown, `.docx` y `.pdf`) |

---

[Volver a la asignatura](../README.md)
