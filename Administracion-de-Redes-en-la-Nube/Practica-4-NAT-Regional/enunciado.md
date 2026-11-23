# Práctica 4: NAT Gateway regional. Salida a Internet multi-AZ

- Curso: Administración de redes en la nube
- Tarea en Aules: aws2 13 NAT regional
- Documento original: `Materiales/aws2_13natregional.pdf` (local)

## Escenario

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `172.16.0.0/16` |
| Subredes públicas | `172.16.0.0/20` (1a) y `172.16.16.0/20` (1b) |
| Subredes privadas | `172.16.64.0/20` (1a), `172.16.80.0/20` (1b) y `172.16.96.0/20` (1c) |
| Bastión | `172.16.0.100` |
| Instancias privadas | `172.16.64.100`, `172.16.80.100` y `172.16.96.100` |

## Partes

1. VPC con el asistente, sin NAT
2. Bastión y dos instancias privadas, con salto SSH (`ssh -J`)
3. Ejemplo 1: las privadas no salen a Internet
4. Ejemplo 2: crear el NAT regional y revisar su tabla de rutas
5. Ejemplo 3: enrutar las privadas hacia el mismo NAT
6. Ejemplo 4: añadir una tercera zona sin tocar el NAT
7. Ejemplo 5 (opcional): asistente con NAT regional
8. AWS CLI: NAT regional y una única tabla privada
9. Limpieza

El índice del PDF cita un apartado de preguntas en la página 18, pero el documento tiene 16 páginas y no lo incluye.
