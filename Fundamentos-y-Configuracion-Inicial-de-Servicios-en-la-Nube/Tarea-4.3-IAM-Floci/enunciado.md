# Tarea 4.3. Gestión de identidades y accesos con AWS IAM

- Entorno: Floci (emulador local de AWS, https://floci.io/) sobre Linux con Docker y AWS CLI v2
- Plazo en Aules: del 27/11/2026 al 04/12/2026 a las 23:55
- Entrega en Aules: un único fichero `fci_t4.3_apellido1_apellido2.zip`
- Documento original: `Materiales/practica-iam-floci-lab.pdf` (local)

Evaluar el usuario root, sustituirlo por un administrador `admin-lab`, crear tres usuarios con permisos según sus grupos y exigir MFA virtual para acciones sensibles.

## Fases

0. Identificar a root (`sts get-caller-identity`, `iam list-users`). Cuestión 1.
1. Grupo `Admins` con `AdministratorAccess`, usuario `admin-lab` y perfil `admin`. Desde aquí no se usa root. Cuestión 2.
2. Bucket `lab-datos` con `hola.txt`, instancia `ec2-test`, políticas `S3-LabDatos-Lectura` y `EC2-Operacion`, grupos `S3-Lectura` y `EC2-Operadores`, usuarios `ana`, `luis` y `eva` con sus perfiles.
3. Matriz de pruebas (predicción y resultado), denegación explícita con el grupo `Sin-Descarga` y simulación de políticas (opcional). Cuestión 3.
4. MFA virtual `eva-mfa`, política `EC2-Requiere-MFA` con `BoolIfExists` y sesión temporal en el perfil `eva-mfa`. Cuestiones 4 y 5.
5. Revisión con el profesor y limpieza (`docker compose down`).

Floci debe arrancar con `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`; si no, todo se permite.

## Entregables

- Respuestas a las cinco cuestiones.
- Matriz de pruebas de la sección 5 con predicciones y resultados.
- Ficheros JSON de las cuatro políticas: `s3-lectura`, `ec2-operadores`, `sin-descarga` y `requiere-mfa`.
- Captura de la denegación de `stop-instances` sin MFA y otra de la operación correcta con `eva-mfa`.

## Evaluación

| Criterio | Peso |
|:--|:-:|
| Entorno funcionando con IAM activo | 10 % |
| Administrador y abandono de root | 15 % |
| Grupos y políticas con mínimo privilegio | 25 % |
| Matriz de pruebas | 20 % |
| Denegación explícita y MFA | 20 % |
| Respuestas a las cuestiones | 10 % |
