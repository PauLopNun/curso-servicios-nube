<div align="center">

# Tarea 1.3 - Despliegue automatizado reproducible

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Webmin](https://img.shields.io/badge/Webmin-7DA0D0?style=for-the-badge&logo=webmin&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-cloud--init-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**UD01 - Servicios computacionales basados en máquinas virtuales**

</div>

## Objetivo

Conseguir que cualquiera pueda levantar un servidor Webmin idéntico en pocos minutos y sin configurar nada a mano: una plantilla de lanzamiento versionada, un grupo de seguridad restrictivo, datos de usuario que lo instalan todo en el primer arranque e IMDSv2 para que cada instancia tome su nombre de host de su etiqueta `Name`.

## Recursos

| Recurso | Detalle |
|:--|:--|
| Grupo de seguridad `webmin-pln-sg` | Solo SSH (22) y Webmin (10000), con origen `213.0.86.0/23` (instituto) |
| Plantilla `webmin-pln-template` v1 | Ubuntu Server 26.04 LTS, `t3.micro`, `vockey`, us-east-1a con IP pública, gp3 de 8 GiB cifrado, `LabInstanceProfile`, IMDSv2 obligatorio y etiquetas en los metadatos |
| Plantilla `webmin-pln-template` v2 (predeterminada) | La v1 más los [datos de usuario](scripts/datos-usuario.sh) que instalan Webmin |
| `webmin-pln-proto` | Prototipo para instalar Webmin a mano por SSH |
| `webmin-pln-01` y `webmin-pln-02` | Instancias lanzadas desde la v2 cambiando solo el `Name` |

Todos los recursos llevan las etiquetas `Proyecto=UD01`, `Propietario=pln` y `Aplicacion=webmin`.

## Qué hace el script de datos de usuario

1. Lee la etiqueta `Name` de la instancia con IMDSv2 (token obligatorio).
2. Fija el nombre de host y evita que cloud-init lo cambie.
3. Instala Webmin desde su repositorio oficial sin ninguna pregunta.
4. Genera una contraseña aleatoria para `root` de Webmin y la guarda en `/root/webmin-pass.txt` con permisos 600, solo si no existe ya.

Es idempotente: ejecutado por segunda vez termina con `OK` y no cambia la contraseña.

## Resultado

| Comprobación | Resultado |
|:--|:--|
| Metadatos sin token | 401 |
| `cloud-init status --wait` en `webmin-pln-01` | `done`, sin errores |
| Nombre de host | El de la etiqueta `Name` |
| Segunda ejecución del script | `OK`, mismo `md5sum` de la contraseña |
| Copia de configuración desde Webmin | `/var/backups/webmin-config.tar.gz` |
| `webmin-pln-02`: tiempo hasta que Webmin responde | 109 segundos desde el lanzamiento |

`webmin-pln-02` queda igual que `webmin-pln-01` salvo el nombre, la IP y los identificadores, y no tiene la copia de configuración: la plantilla reproduce la instalación, no lo que se cambie después.

## Notas

- El equipo del aula bloquea el tráfico TCP hacia el puerto 10000, así que el panel se abrió por un túnel SSH (`ssh -L`) sin tocar las reglas del grupo de seguridad.
- El laboratorio no admite más de 9 instancias en la cuenta: la décima se termina sola nada más lanzarla.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/datos-usuario.sh`](scripts/datos-usuario.sh) | Datos de usuario de la versión 2 de la plantilla |
| [`scripts/lanza_webmin.sh`](scripts/lanza_webmin.sh) | Ampliación: lanza una instancia desde la plantilla con la AWS CLI y muestra la URL |
| [`evidencias/`](evidencias) | Salida real de los comandos por SSH y de la CLI |
| [`capturas/`](capturas) | Consola de EC2 y panel de Webmin |
| [`entrega/LopezPau_Tarea1-3.pdf`](entrega/LopezPau_Tarea1-3.pdf) | Documento de entrega (también en DOCX) |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
