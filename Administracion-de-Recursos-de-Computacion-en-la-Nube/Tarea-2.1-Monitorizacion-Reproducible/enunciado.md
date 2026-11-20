# Tarea 2.1: Monitorización reproducible de un servidor web

- Curso: Administración de recursos de computación en la nube
- Tipo: tarea individual evaluable
- Documento original: `Materiales/CE_RSN-ARCN-UD02-Task2_1.pdf` (local)

## Partes

1. Arquitectura: plantilla `web-xx-lt` que lanza `web-xx` y `web-xx-2`, agente de CloudWatch configurado desde el parámetro `/web-xx/agente` y alarmas que avisan al tema `web-xx-avisos`
2. Preparación: tema de SNS con suscripción por correo y grupo de seguridad `web-xx-sg` (solo HTTP)
3. Configuración del agente en el Almacén de parámetros (memoria y disco `/`)
4. Plantilla de lanzamiento con Apache, stress-ng y el agente en los datos de usuario; dos servidores iguales en zonas distintas
5. Script `alarmas.sh` que crea las alarmas de CPU, memoria y disco de cualquier instancia
6. Pruebas con Run Command en `web-xx-2`: memoria llena y disco casi lleno
7. Datos ausentes: detener `web-xx-2` y observar sus alarmas
8. Ampliación opcional: alarma compuesta o panel como código
9. Limpieza

No se entra en ninguna instancia: ni por SSH ni para configurar nada a mano.

## Entrega

PDF `CE_RSN-ARCN-UD02-Task2_1-Apellidos_Nombre.pdf` de 8 páginas como máximo con tres apartados: evidencias numeradas y comentadas (1 a 9), anexos con los datos de usuario y `alarmas.sh` como texto, y respuestas a las preguntas *Para pensar*.
