<div align="center">

# Tarea 4.3 - Gestión de identidades y accesos con AWS IAM

![IAM](https://img.shields.io/badge/AWS-IAM-DD344C?style=for-the-badge&logoColor=white)
![Floci](https://img.shields.io/badge/Floci-Emulador-232F3E?style=for-the-badge&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![CLI](https://img.shields.io/badge/AWS%20CLI-232F3E?style=for-the-badge&logoColor=white)

</div>

## Objetivo

Practicar IAM en local con el emulador Floci: abandonar root por un administrador, repartir permisos de S3 y EC2 por grupos con mínimo privilegio, comprobar que un `Deny` explícito prevalece sobre cualquier `Allow` y exigir MFA para parar o terminar instancias.

| Usuario | Grupos | Permisos |
|:--|:--|:--|
| `admin-lab` | `Admins` | `AdministratorAccess` |
| `ana` | `S3-Lectura` | Listar y descargar de `lab-datos` |
| `luis` | `EC2-Operadores` | Consultar, lanzar, arrancar y parar instancias |
| `eva` | `S3-Lectura` y `EC2-Operadores` | Los de ambos grupos |

## Resultado

| Comprobación | Resultado |
|:--|:--|
| Matriz de pruebas (7 acciones x 3 usuarios) | Los 21 resultados coinciden con la predicción |
| Eva en `Sin-Descarga` | El `Deny` explícito anula el `Allow` de `S3-Lectura` |
| Parar sin MFA | Denegado |
| Parar con `eva-mfa` | Permitido |

Se hizo con `floci/floci:nightly-11262026`. La 2.5.0 no rellena `aws:MultiFactorAuthPresent` en las sesiones de `get-session-token` y deniega también con MFA; sus logs están en [evidencias/floci-2.5.0](evidencias/floci-2.5.0).
| `Bool` en lugar de `BoolIfExists` | Eva para la instancia sin MFA |

## Contenido

- [scripts/practica-iam.sh](scripts/practica-iam.sh): fases 0 a 4 de forma reproducible
- [scripts/politicas/](scripts/politicas): las cuatro políticas en JSON
- [scripts/totp.py](scripts/totp.py): códigos TOTP sin `oathtool`
- [capturas/](capturas) y [evidencias/](evidencias): capturas de terminal y salida de cada fase
- [entrega/](entrega): memoria y `fci_t4.3_lopez_nunez.zip` subido a Aules

---

[Volver a la asignatura](../README.md)
