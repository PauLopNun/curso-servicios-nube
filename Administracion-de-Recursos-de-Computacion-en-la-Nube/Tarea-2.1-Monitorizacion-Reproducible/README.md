<div align="center">

# Tarea 2.1 - Monitorización reproducible de un servidor web

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![CloudWatch](https://img.shields.io/badge/AWS-CloudWatch-FF4F8B?style=for-the-badge&logoColor=white)
![Systems Manager](https://img.shields.io/badge/AWS-Systems_Manager-759C3E?style=for-the-badge&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-AWS_CLI-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**UD02 - Monitorización y alta disponibilidad en máquinas virtuales**

</div>

## Objetivo

Lanzar servidores web que arrancan ya monitorizados y cuya vigilancia se repite sin trabajo manual: la configuración del agente de CloudWatch vive en el Almacén de parámetros, la plantilla instala Apache y el agente, las alarmas salen de un script y las pruebas se lanzan con Run Command. No se entra en ninguna instancia.

## Recursos

| Recurso | Detalle |
|:--|:--|
| Tema `web-pln-avisos` | SNS estándar con suscripción por correo |
| Grupo de seguridad `web-pln-sg` | Solo HTTP (80) desde `0.0.0.0/0`; sin SSH ni par de claves |
| Parámetro `/web-pln/agente` | [Configuración del agente](scripts/agente.json): `mem_used_percent` y `disk used_percent` de `/`, con `InstanceId`, sin `host` ni `device` |
| Plantilla `web-pln-lt` | Ubuntu Server 26.04, `t3.micro`, `LabInstanceProfile`, monitorización detallada, IMDSv2 obligatorio y los [datos de usuario](scripts/datos-usuario.sh) |
| `web-pln` y `web-pln-2` | Lanzadas desde la plantilla en us-east-1a y us-east-1b, cambiando solo el `Name` |
| 6 alarmas | Creadas con [`alarmas.sh`](scripts/alarmas.sh): CPU, memoria y disco de cada instancia |
| Panel `web-pln-panel` | Ampliación: [panel como código](scripts/panel.json) con la memoria de las dos instancias y el estado de las seis alarmas |

Todos los recursos llevan las etiquetas `Proyecto=UD02` y `Propietario=pln`.

## Alarmas

| Alarma | Métrica | Condición | Datos ausentes |
|:--|:--|:--|:--|
| `<nombre>-cpu` | `AWS/EC2 CPUUtilization` | Media de 1 min > 70 % en 2 de 3 | `notBreaching` |
| `<nombre>-mem` | `CWAgent mem_used_percent` | Media de 1 min > 70 % en 2 de 3 | `breaching` |
| `<nombre>-disco` | `CWAgent disk_used_percent` (`/`, `ext4`) | Máximo de 5 min > 85 % | `missing` |

## Resultado

| Prueba en `web-pln-2` (Run Command) | Resultado |
|:--|:--|
| Memoria: `stress-ng --vm-populate --vm-hang 0` durante 6 min | `available` baja a 127 MB, carga 0,06; `web-pln-2-mem` en ALARM al 74 % y `web-pln-2-cpu` en OK |
| Disco: `fallocate` hasta el 92 % | `df` marca 93 %; `web-pln-2-disco` en ALARM con un máximo de 92,2 % |
| Aviso por correo | Llega `ALARM: "web-pln-2-mem"` desde SNS |
| Instancia detenida 10 min | CPU en OK (`notBreaching`), memoria en ALARM a los 6 minutos (`breaching`) y disco en OK (`missing`) |

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/agente.json`](scripts/agente.json) | Valor del parámetro `/web-pln/agente` |
| [`scripts/datos-usuario.sh`](scripts/datos-usuario.sh) | Datos de usuario de la plantilla |
| [`scripts/alarmas.sh`](scripts/alarmas.sh) | Crea las tres alarmas de una instancia |
| [`scripts/panel.json`](scripts/panel.json) | Cuerpo del panel `web-pln-panel` para `put-dashboard` |
| [`evidencias/`](evidencias) | Salida de los comandos de Run Command y de la parte 7 |
| [`capturas/`](capturas) | Capturas de las evidencias 1 a 9 |
| [`entrega/CE_RSN-ARCN-UD02-Task2_1-Lopez_Nunez_Pau.pdf`](entrega/CE_RSN-ARCN-UD02-Task2_1-Lopez_Nunez_Pau.pdf) | Documento de entrega |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
