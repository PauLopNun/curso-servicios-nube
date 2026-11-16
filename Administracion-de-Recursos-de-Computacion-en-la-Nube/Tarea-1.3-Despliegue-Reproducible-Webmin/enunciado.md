# Tarea 1.3: Despliegue automatizado reproducible

- Curso: Administración de recursos de computación en la nube
- Tipo: tarea individual evaluable
- Documento original: `Materiales/CE_RSN-ARCN-UD01-Task1_3.pdf` (local)

## Partes

1. Preparación: laboratorio en us-east-1, clave `labsuser.pem` y etiquetas `Proyecto`, `Propietario` y `Aplicacion=webmin`
2. Grupo de seguridad `webmin-xx-sg` (solo 22 y 10000 desde el instituto o casa) y plantilla `webmin-xx-template` v1
3. Prototipo manual por SSH: IMDSv2, etiquetas en los metadatos e instalación de Webmin a mano
4. Versión 2 de la plantilla con datos de usuario no interactivos e idempotentes
5. Despliegue de `webmin-xx-01`, verificación por SSH y copia de configuración desde Webmin
6. Prueba de reproducibilidad con `webmin-xx-02`
7. Ampliación opcional: script `lanza_webmin.sh` con la AWS CLI
8. Limpieza

## Entrega

PDF `ApellidoNombre_Tarea1-3.pdf` con las evidencias numeradas y comentadas (grupo de seguridad, plantilla, datos de usuario, verificación por SSH, Webmin, reproducibilidad, preguntas *Para pensar* y, si se hace, la ampliación) y los scripts copiados como texto.
