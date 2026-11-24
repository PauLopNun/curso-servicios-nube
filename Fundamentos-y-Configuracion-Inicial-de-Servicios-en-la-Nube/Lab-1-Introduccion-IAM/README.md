<div align="center">

# Lab 1 - Introducción a AWS IAM

![IAM](https://img.shields.io/badge/AWS-IAM-DD344C?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![S3](https://img.shields.io/badge/AWS-S3-569A31?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Entregada-2ea44f?style=for-the-badge)

**Laboratorio de AWS Academy Lab 1: Introduction to AWS IAM**

<img src="https://skillicons.dev/icons?i=aws,bash" />

</div>

## Qué se pide

Explorar los usuarios y grupos de IAM que trae el laboratorio, meter a cada usuario en el grupo de su puesto y comprobar en la consola, entrando con cada uno, que solo puede hacer lo que permite la política de su grupo.

## Realización

Hecho el 24/11/2026 (cuenta 134464868125, us-east-1). Las tareas 1 y 2 con la AWS CLI y la 3 en la consola con cada usuario.

| Tarea | Resultado |
|:--|:--|
| 1. Explorar | `user-1`, `user-2` y `user-3` sin grupos ni políticas. `EC2-Support` con `AmazonEC2ReadOnlyAccess`, `S3-Support` con `AmazonS3ReadOnlyAccess` y `EC2-Admin` con la política inline `EC2-Admin-Policy` (Describe, Start y Stop) |
| 2. Grupos | `user-1` en S3-Support, `user-2` en EC2-Support y `user-3` en EC2-Admin; simulador de políticas para comprobarlo |
| 3. Pruebas | user-1 ve S3 pero no EC2; user-2 ve EC2 pero no puede detener LabHost ni listar S3; user-3 detiene LabHost |

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`evidencias/`](evidencias) | Comandos de la CLI y su salida |
| [`capturas/`](capturas) | Capturas de la consola con cada usuario |
| [`entrega/`](entrega) | Documento de entrega (Markdown, DOCX y PDF) |

---

[Volver a la asignatura](../README.md)
