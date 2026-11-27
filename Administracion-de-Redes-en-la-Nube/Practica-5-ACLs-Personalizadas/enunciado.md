# Práctica 5: ACLs personalizadas

- Curso: Administración de redes en la nube
- Tarea en Aules: aws2 14 NACL
- Documento original: `Materiales/aws2_14nacl.pdf` (local)

Comprobar que los grupos de seguridad guardan el estado y las ACL de red no. Se monta una VPC con dos subredes públicas, cada una con su EC2: en una se permite el ping con el grupo de seguridad y en la otra con una NACL.

## Actividades

1. Crear un grupo de seguridad que permita el ping solo de entrada. Como guarda el estado, la respuesta vuelve sin regla de salida.
2. Añadir una NACL con permiso solo de entrada para el ping. Al no permitir la salida de forma explícita, el ping no debe volver.
3. Añadir en la NACL la regla de salida y comprobar que el ping funciona.

El PDF incluye un esquema del escenario sin direccionamiento concreto.
