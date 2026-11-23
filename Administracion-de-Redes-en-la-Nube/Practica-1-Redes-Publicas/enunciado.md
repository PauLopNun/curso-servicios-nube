# Práctica 1: Creación de redes públicas

- Curso: Administración de redes en la nube
- Documento original: `Materiales/Practica1_Creacion_redes_publicas.pdf` (local)

## Partes

1. Instancia EC2 en la VPC por defecto: Ubuntu Server 22.04, `t2.micro`, par `vockey`, disco de 10 GB `gp2`, perfil `LabInstanceProfile` y grupo de seguridad con SSH, HTTP y HTTPS
2. Datos de usuario como script de shell (se ejecutan como root y sin interacción) y conexión por SSH con el usuario `ubuntu`
3. VPC desde la consola: `172.16.0.0/16` con la subred SR1 `172.16.0.0/20`; la segunda subred se crea después
4. Dos instancias en SR1: una con un grupo de seguridad nuevo y otra con uno ya existente
5. AWS CLI: instalación, credenciales del laboratorio en `~/.aws/credentials` y comprobación con `aws sts get-caller-identity`
6. Con la CLI: crear una instancia con etiqueta `Name` y par de claves, y después una VPC, una subred y una instancia dentro

En cada paso hay que capturar la conexión y las direcciones IP en el panel y en el terminal, analizar los resultados y responder si hay conexión desde el exterior con la instancia creada por la CLI.

## Entrega

PDF `LopezPau_Practica1.pdf` con las capturas y el análisis de cada paso.
