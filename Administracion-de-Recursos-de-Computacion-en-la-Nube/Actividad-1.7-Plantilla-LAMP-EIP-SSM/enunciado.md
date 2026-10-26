# Actividad 1.7: Plantilla de lanzamiento LAMP, IP elástica y Session Manager

- Curso: Administración de recursos de computación en la nube
- Tipo: actividad guiada, sin entregable (dos sesiones)
- Documento original: `Materiales/CE_RSN-ARCN-UD01-Act1_7.pdf` (local)

## Partes

1. Preparación (us-east-1, etiquetas `Name`, `Proyecto=UD01`, `Propietario`)
2. Grupo de seguridad `lamp-sg` (HTTP y SSH temporal) y datos de usuario LAMP
3. Plantilla de lanzamiento `lamp-template` (v1) con IMDSv2 obligatorio y lanzamiento de `lamp-server`
4. IP elástica `lamp-eip`: asignar, asociar y comprobar tras detener/iniciar
5. Conexión con Session Manager desde la consola
6. Cierre del puerto 22
7. Session Manager desde la CLI y redirección de puertos
8. Consultas a IMDSv2 con token
9. Versión 2 de la plantilla (sin clave SSH, sin `phpinfo.php`, IP privada)
10. Instancias adicionales desde la plantilla (consola y CLI)
11. Limpieza: terminar instancias y liberar la IP elástica
