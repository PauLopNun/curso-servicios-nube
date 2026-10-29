# Actividad 3.4: sitio web estático en Amazon S3 con Visual Studio Code

- Curso: Administración de bases de datos y almacenamiento en la nube
- Tipo: entregable "Tarea 1.7. Sitio web estático y extra 1.8 Access Points" (entrega: 3 de noviembre de 2026)
- Documento original: `Materiales/CE_ARSN-ASAN-UD03-Act3_4_Sitio_web_estatico_nueva_version_VSCode.docx` (local)

## Pasos

1. Crear el bucket `website-<iniciales>-1234` en us-east-1 sin bloqueo de acceso público
2. Preparar VS Code, Git y AWS CLI y configurar las credenciales del Learner Lab
3. Comprobar la conexión (`aws sts get-caller-identity`, `aws s3 ls`)
4. Clonar el sitio web y subirlo con `aws s3 cp --recursive`
5. Habilitar el alojamiento de sitios web estáticos (`index.html`)
6. Comprobar el error 403 y crear la política de bucket con `s3:GetObject` público
7. Modificar el sitio y desplegar con `aws s3 sync`
8. Reto: página `acerca.html` con el nombre del alumno
9. Limpieza: vaciar y eliminar el bucket y borrar las credenciales
