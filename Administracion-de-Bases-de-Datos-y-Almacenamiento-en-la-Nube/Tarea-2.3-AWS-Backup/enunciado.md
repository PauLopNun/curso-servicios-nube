# Tarea 2.3. AWS Backup

Laboratorio de AWS SkillBuilder **Multi-Service Backup Management with AWS Backup** (SAL-TF-100-STBACK-1, 1 hora):
<https://skillbuilder.aws/learn/PKBZVDN86T/multiservice-backup-management-with-aws-backup/MNMD1P9ZNU>

Como entrega basta con enseñar la configuración y la ejecución de cada paso.

## Objetivos

- Crear y gestionar almacenes de copias (backup vaults) con cifrado.
- Hacer copias bajo demanda de una instancia EC2, un sistema de archivos EFS y una base de datos RDS.
- Crear planes de copia con programación automática y políticas de retención.
- Seleccionar los recursos de un plan mediante etiquetas.

## Tareas del laboratorio

1. **Ajustes y almacén.** Revisar en *Settings* que EC2, EFS y RDS están activados (*Service opt-in*) y crear el almacén `Lab-Backup-Vault` cifrado con la clave `aws/backup`.
2. **Copias bajo demanda.** Lanzar una copia de `Lab1-EC2`, de `Lab1-EFS` y de `lab1-rds` en `Lab-Backup-Vault`, con 3 días de retención y el rol `AWSBackupWorkshopRole`, y seguir los trabajos en *Jobs*.
3. **Plan de copias.** Crear `HourlyBackupPlan-Lab1` con la regla `HourlyBackupRule` (cada hora, ventana que empieza en 5 minutos, inicio en 1 h, fin en 2 h, retención de 3 días) y la asignación `HourlyPlanResourceAssignment`: todos los tipos de recurso filtrados por la etiqueta `backup = hourly`.
4. **Etiquetas.** Poner `backup = hourly` a `Lab1-EC2`, `Lab1-EFS` y `lab1-rds`, revisar la vista previa de las próximas ejecuciones del plan y comprobar los trabajos en *Jobs*.
