# Tarea 1.2: WordPress en dos capas

- Curso: Administración de recursos de computación en la nube
- Tipo: tarea individual evaluable (entrega: 15 de noviembre de 2026)
- Documento original: `Materiales/CE_RSN-ARCN-UD01-Task1_2.pdf` (local)

## Partes

1. Arquitectura: capa web (`wp-web-xx`) y capa de datos (`wp-bd-xx`) en la subred predeterminada de us-east-1a
2. Preparación: clave `labsuser.pem` y elección de la IP privada de la base de datos
3. Grupos de seguridad `wp-web-xx-sg` y `wp-bd-xx-sg`, con reglas que hacen referencia a otro grupo
4. Instancias Ubuntu 26.04 t3.micro e IP elástica para la capa web
5. Acceso SSH con host de salto (`ProxyJump`)
6. Capa de datos con MariaDB: `bind-address` y usuario con mínimo privilegio
7. Capa web con Apache, PHP y WordPress en español
8. Primera entrada con imagen y comprobaciones de seguridad desde fuera
9. Ampliación opcional: base de datos en una subred privada
10. Limpieza

## Entrega

PDF `CE_RSN-ARCN-UD01-Task1_2-Apellidos_Nombre.pdf` con cinco capturas comentadas (instancias; grupos de seguridad e IP elástica; terminal con `~/.ssh/config`, salto a wp-bd y puerto 3306 cerrado; MariaDB con `ss`, `SELECT user, host` y `SHOW GRANTS`; blog en el navegador) y las respuestas a las preguntas *Para pensar*.
