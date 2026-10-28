<div align="center">

# Actividad 1.7 - Plantilla de lanzamiento LAMP, IP elástica y Session Manager

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![SSM](https://img.shields.io/badge/Systems%20Manager-Session%20Manager-232F3E?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Completado-brightgreen?style=for-the-badge)

**UD01 - Servicios computacionales basados en máquinas virtuales**

</div>

## Objetivo

Desplegar un servidor LAMP con una plantilla de lanzamiento versionada (datos de usuario con cloud-init e IMDSv2 obligatorio), asociarle configuración y administrarlo con AWS Systems Manager Session Manager sin claves SSH ni dependencias del puerto 22.

## Progreso

| Parte | Descripción | Estado |
|:-:|:--|:-:|
| 1 | Preparación: instancias de actividades anteriores detenidas | Hecho |
| 2 | Grupo de seguridad `lamp-sg` (HTTP 80 y SSH 22 inicial) | Hecho |
| 3 | Plantilla `lamp-template` v1 creada (`lt-0473729728a39e1a9`) | Hecho |
| 3 | Lanzar `lamp-server` desde plantilla y comprobar cloud-init | Hecho |
| 4-5 | Session Manager (consola y CLI) con rol `LabInstanceProfile` | Hecho |
| 8 | IMDSv2 con token, protección SSRF (401 en v1) y extracción de IP privada (`local-ipv4`) | Hecho |
| 9 | Plantilla `lamp-template` v2 creada y predeterminada (sin clave SSH, sin `phpinfo.php`, IP privada en web) | Hecho |
| 10-11 | Pruebas de ejecución y retención de instancia para revisión | Hecho |

## Plantillas de Lanzamiento

### Versión 1 (`v1 - LAMP con SSH temporal`)
- **Par de claves**: `vockey`
- **Script**: [`scripts/user-data-v1.sh`](scripts/user-data-v1.sh) (instala LAMP y genera `index.html` básico + `phpinfo.php`)

### Versión 2 (`v2 - acceso solo por Session Manager`) — *Predeterminada*
- **Par de claves**: Ninguna (acceso 100% mediante SSM Session Manager)
- **Script**: [`scripts/user-data-v2.sh`](scripts/user-data-v2.sh) (elimina `phpinfo.php`, extrae e inyecta la IP privada `local-ipv4` e identifica la versión 2)

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/user-data-v1.sh`](scripts/user-data-v1.sh) | Datos de usuario v1 (LAMP inicial con phpinfo) |
| [`scripts/user-data-v2.sh`](scripts/user-data-v2.sh) | Datos de usuario v2 (sin SSH, sin phpinfo, con IP privada) |
| [`capturas/`](capturas) | Capturas de la consola y del terminal |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
