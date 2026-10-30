<div align="center">

# Práctica 1.3 - Introducción a Amazon S3 (políticas y versionado)

![S3](https://img.shields.io/badge/AWS-S3-569A31?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![IAM](https://img.shields.io/badge/AWS-IAM-DD344C?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Completado-brightgreen?style=for-the-badge)

**UD01 - Almacenamiento de objetos con Amazon S3**

</div>

## Objetivo

Crear un bucket para los informes de una instancia EC2, probar sus permisos con ACL y políticas de bucket, y proteger los objetos con el control de versiones. Laboratorio de SkillBuilder *Introduction to Amazon Simple Storage Service (S3)*.

## Tareas del laboratorio

| Tarea | Qué se hace | Resultado |
|:-:|:--|:--|
| 1 | Crear `reportbucket-<cuenta>` con ACL habilitadas | Bucket creado en us-west-2 |
| 2 | Subir `new-report.png` | Objeto privado por defecto |
| 3 | Hacer público el objeto con una ACL | Falla hasta desactivar el bloqueo de acceso público |
| 4 | Probar el bucket desde la EC2 por Session Manager | El rol lista, pero `PutObject` da `AccessDenied` |
| 5 | Crear la política de bucket con el Policy Generator | El rol sube y descarga; `*` obtiene lectura |
| 6 | Habilitar versiones, borrar y recuperar | El marcador de eliminación permite recuperar el objeto |

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Política de bucket para el rol y política final con lectura pública |
| [`capturas/`](capturas) | Capturas de cada tarea, numeradas en orden |
| [`entrega/LopezPau_Practica1-3.pdf`](entrega/LopezPau_Practica1-3.pdf) | Documento para entregar en Aules |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
