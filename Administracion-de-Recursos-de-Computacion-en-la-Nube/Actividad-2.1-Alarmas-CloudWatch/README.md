<div align="center">

# Actividad 2.1 - Alarmas de CloudWatch: avisos y recuperación automática

![CloudWatch](https://img.shields.io/badge/AWS-CloudWatch-FF4F8B?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![SNS](https://img.shields.io/badge/AWS-SNS-FF4F8B?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-AWS%20CLI-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Realizada-0366d6?style=for-the-badge)

**UD02 - Monitorización y alta disponibilidad en máquinas virtuales**

<img src="https://skillicons.dev/icons?i=aws,bash,ubuntu,linux" />

</div>

## Qué se pide

Vigilar una instancia EC2 con CloudWatch y hacer que reaccione sola ante los fallos: métricas desde la consola y la CLI, alarmas que avisan por correo con SNS y alarmas que detienen, recuperan o reinician la instancia, una comprobación de estado de la aplicación y un panel. Resumen en [`enunciado.md`](enunciado.md) y PDF en [`material/`](material).

## Qué se ha hecho

Learner Lab, us-east-1. La infraestructura se ha creado desde la consola y la CLI se ha usado desde el equipo local.

| Parte | Recurso | Resultado |
|:--|:--|:--|
| 1. Preparación | `mon-pln` (`i-07df4a781ae3b354d`), `mon-pln-sg` | Ubuntu 26.04, t3.micro, Apache y stress-ng por datos de usuario |
| 2. Métricas | Monitorización detallada | De un dato de CPU cada 5 minutos a uno por minuto |
| 3. Fallo del sistema | `mon-pln-sistema` | Simulacro con `set-alarm-state`: la acción Detener para la instancia |
| 4. SNS | `avisos-pln` | Suscripción confirmada; `mon-pln-sistema` queda con Recuperar y aviso |
| 5. CPU | `mon-pln-cpu` (> 70 %, 3 de 5) | stress-ng: En alarma a los 5 minutos y correo de ALARM y de OK |
| 6. Fallo de la instancia | `mon-pln-instancia` (3 de 3, Reiniciar) | `ip link set ens5 down`: la instancia se queda sin red (no se esperó al reinicio) |
| 7. Aplicación | `apache-pln` (`asc-05b96a6c`) | Apache parado: Error con ConnectionRefused, el resto de comprobaciones OK |
| 8. Panel | `panel-pln` | CPU a 1 minuto, estado de las tres alarmas y `StatusCheckFailed`; JSON en [`evidencias/panel-pln.json`](evidencias/panel-pln.json) |
| Ampliación | `mon-pln-cpu-cli` | `put-metric-alarm`, idéntica a `mon-pln-cpu` salvo el nombre |
| 9. Limpieza | | Borradas `apache-pln` y `mon-pln-cpu-cli`; instancia detenida |

### Qué detecta cada comprobación

| Comprobación | Métrica | Acción | Comprobado en |
|:--|:--|:--|:--|
| Sistema | `StatusCheckFailed_System` | Recuperar | Parte 3 (simulacro) |
| Instancia | `StatusCheckFailed_Instance` | Reiniciar | Parte 6 (red caída, sin esperar al reinicio) |
| Aplicación | `StatusCheckFailed_Application` | Avisar y revisar | Parte 7 (Apache parado) |

## Scripts

Con las credenciales del laboratorio en `~/.aws/credentials`, desde [`scripts/`](scripts):

| Script | Parte |
|:--|:--|
| [`config.sh`](scripts/config.sh) | Variables comunes (`OWNER`, `ID`, `TOPIC`) y función que guarda comando y salida |
| [`datos-usuario.sh`](scripts/datos-usuario.sh) | Datos de usuario de la instancia |
| [`01-preparacion.sh`](scripts/01-preparacion.sh) | ID de la instancia y prueba de Apache |
| [`02-metricas.sh`](scripts/02-metricas.sh), [`02b`](scripts/02b-monitorizacion-detallada.sh), [`02c`](scripts/02c-cpu-detallada.sh) | Métricas y monitorización detallada |
| [`03-simulacro-sistema.sh`](scripts/03-simulacro-sistema.sh), [`03b`](scripts/03b-historial-sistema.sh) | Simulacro de fallo del host |
| [`04-sns-prueba.sh`](scripts/04-sns-prueba.sh), [`04b`](scripts/04b-alarma-sistema-produccion.sh) | SNS y acciones de la alarma del sistema |
| [`05-cpu-cli.sh`](scripts/05-cpu-cli.sh) | Estado, historial y créditos de CPU |
| [`08-panel.sh`](scripts/08-panel.sh) | Panel con `put-dashboard` |
| [`09-ampliacion-cli.sh`](scripts/09-ampliacion-cli.sh) | Alarma con `put-metric-alarm` |
| [`10-limpieza.sh`](scripts/10-limpieza.sh) | Limpieza de la parte 9 |

## Entrega

Documento [`entrega/cw_a21_lopez_nunez.docx`](entrega/cw_a21_lopez_nunez.docx) (también en [PDF](entrega/cw_a21_lopez_nunez.pdf)) con los pasos, las capturas y las respuestas a los apartados «Para pensar».

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Comandos de la AWS CLI por parte |
| [`evidencias/`](evidencias) | Salida real de cada comando |
| [`capturas/`](capturas) | Capturas de la consola y del terminal, con prefijo por parte |
| [`entrega/`](entrega) | Documento de entrega en DOCX y PDF |
| [`material/`](material) | Enunciado en PDF |

---

[Volver a la asignatura](../README.md)
