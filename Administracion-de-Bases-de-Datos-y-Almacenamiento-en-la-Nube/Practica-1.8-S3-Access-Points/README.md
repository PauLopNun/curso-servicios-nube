<div align="center">

# Práctica 1.8 - Gestión del acceso con Amazon S3 Access Points

![S3](https://img.shields.io/badge/AWS-S3-569A31?style=for-the-badge&logoColor=white)
![VPC](https://img.shields.io/badge/AWS-VPC%20Endpoint-8C4FFF?style=for-the-badge&logoColor=white)
![IAM](https://img.shields.io/badge/AWS-IAM-DD344C?style=for-the-badge&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Completado-brightgreen?style=for-the-badge)

**UD01 - Almacenamiento de objetos con Amazon S3**

</div>

## Objetivo

Controlar el acceso a un bucket compartido con puntos de acceso de S3: cada usuario entra por su propio punto de acceso, solo desde la VPC, y solo puede descargar los objetos con su etiqueta. Laboratorio de SkillBuilder *Managing Access at Scale with Amazon S3 Access Points*.

## Escenario

El bucket `medical-records` guarda historiales dentales (`recordtype=dental`) y radiografías (`recordtype=xray`). `DentalUser` y `XrayUser` no tienen políticas de identidad: todo el acceso se concede con políticas de recurso.

| Pieza | Política | Qué permite |
|:--|:--|:--|
| Punto de acceso `dental-ap` (origen VPC) | [`politica-dental-ap.json`](scripts/politica-dental-ap.json) | `DentalUser` lista y descarga solo objetos `recordtype=dental` |
| Punto de acceso `xray-ap` (origen VPC) | [`politica-xray-ap.json`](scripts/politica-xray-ap.json) | `XrayUser` lista y descarga solo objetos `recordtype=xray` |
| VPC endpoint (Gateway de S3) | [`politica-vpc-endpoint.json`](scripts/politica-vpc-endpoint.json) | `ListBucket` y `GetObject` sobre el bucket y los dos puntos de acceso |
| Bucket `medical-records` | [`politica-bucket.json`](scripts/politica-bucket.json) | Delega el control en los puntos de acceso de la cuenta (`s3:DataAccessPointAccount`) |

Una petición solo prospera si la permiten a la vez el endpoint, el punto de acceso y el bucket.

## Resultados desde la EC2 (Session Manager)

| Identidad | Destino | Listar | Descargar dental | Descargar xray |
|:--|:--|:-:|:-:|:-:|
| Rol de la instancia | Bucket | Sí | Sí | - |
| Rol de la instancia | `dental-ap` | No | - | - |
| `DentalUser` | Bucket | No | - | - |
| `DentalUser` | `dental-ap` | Sí | Sí | No |
| `DentalUser` | `xray-ap` | No | - | - |
| `XrayUser` | `xray-ap` | Sí | No | Sí |

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Políticas de los puntos de acceso, del VPC endpoint y del bucket |
| [`capturas/`](capturas) | Consola (01-08) y pruebas por Session Manager (10-22) |
| [`entrega/LopezPau_Tarea1-7_1-8.pdf`](entrega/LopezPau_Tarea1-7_1-8.pdf) | Documento entregado (junto con la Actividad 3.4 / Tarea 1.7) |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
