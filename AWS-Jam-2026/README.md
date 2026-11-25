<div align="center">

![Header](https://capsule-render.vercel.app/api?type=waving&color=0:FF9900,100:232F3E&height=180&section=header&text=AWS%20Jam%202026&fontSize=44&fontColor=fff&animation=fadeIn&fontAlignY=36&desc=Primera%20JAM%20Juande%20%7C%2025%2F11%2F2026&descAlignY=56&descAlign=50)

![AWS](https://img.shields.io/badge/AWS-Jam-FF9900?style=for-the-badge&logoColor=white)
![Retos](https://img.shields.io/badge/Retos-6-232F3E?style=for-the-badge)
![CLI](https://img.shields.io/badge/AWS%20CLI-v2-232F3E?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

</div>

## Qué es esto

Guía de estudio de los **6 retos** del AWS Jam *Primera JAM Juande*, hecho en clase en equipo el 25/11/2026. No pertenece a ninguna asignatura concreta: toca redes, seguridad, despliegue, observabilidad e IA.

Para cada reto hay:

- **Enunciado** de cada tarea, traducido.
- **Cómo pensarlo**: qué hay que mirar y por qué falla, antes de tocar nada.
- **Paso a paso en la consola**, con menús, botones y campos.
- **Paso a paso con la AWS CLI**, con todos los comandos en `scripts/comandos.sh`.
- **Comprobación**: cómo saber que está bien.
- **Errores típicos** que aparecieron de verdad y cómo se resolvieron.
- **Preguntas de repaso** con la respuesta desplegable, para estudiar tipo examen.

## Los retos

<div align="center">

| # | Reto (nombre en el Jam) | Servicios | Tareas | Estado |
|:-:|:--|:--|:-:|:-:|
| 1 | [La seguridad impulsada por la IA descubre la deduplicación y la priorización](Reto-1-Deduplicacion-Hallazgos-IA) | Bedrock AgentCore, Lambda, DynamoDB, S3 | 4 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 2 | [¡Dijeron que la creación de redes globales es fácil!](Reto-2-Redes-Globales-Cloud-WAN) | Cloud WAN, Site-to-Site VPN, Transit Gateway | 3 | ![Propuesta](https://img.shields.io/badge/Propuesta-dbab09?style=flat-square) |
| 3 | [AWS, ¡ayúdeme a administrar mis firewalls!](Reto-3-Firewalls-Suricata-Network-Firewall) | Suricata, Gateway Load Balancer, Network Firewall | 4 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 4 | [DevOps Detective: La difícil situación del oleoducto](Reto-4-DevOps-Detective-CodePipeline) | CodePipeline, EC2, ALB | 2 | ![Propuesta](https://img.shields.io/badge/Propuesta-dbab09?style=flat-square) |
| 5 | [Implementaciones en desarrollo](Reto-5-Implementaciones-CodeDeploy) | CodeDeploy, Auto Scaling, S3 | 3 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 6 | [Pruebe el flujo](Reto-6-Pruebe-el-Flujo-VPC-Flow-Logs) | VPC Flow Logs, CloudWatch, SNS, Athena | 3 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |

</div>

- **Resuelto:** hecho y comprobado en el laboratorio. Los comandos y las salidas son reales.
- **Propuesta:** lo resolvió otro miembro del equipo. La guía explica el razonamiento y la solución esperada, pero no se ejecutó paso a paso aquí. Al practicarlo, hay que confirmar los nombres reales del laboratorio.

## Cómo funciona un AWS Jam

- Cada **reto** tiene su propia **cuenta de AWS** temporal, ya preparada con recursos (algunos rotos a propósito).
- Las tareas se desbloquean en orden. Se validan solas, con **Check my progress**, o escribiendo una respuesta en la caja de la tarea.
- Las **pistas** quitan puntos. Ningún reto de esta guía necesitó pistas.
- Pestañas importantes de cada reto:
  - **Propiedades de salida:** los nombres de los recursos (buckets, Lambdas, VPC...). **Es lo primero que hay que mirar.**
  - **Abra la consola de AWS:** entra en la consola con la cuenta del reto.
  - **>_AWS_CLI:** da credenciales temporales para usar la CLI desde tu equipo.
  - **Restablecer el entorno de laboratorio:** deja la cuenta como al principio. Úsalo solo si lo has roto todo.

### Usar la CLI con las credenciales del Jam

El botón **>_AWS_CLI** muestra tres líneas `export`. Se pueden pegar en la terminal, o guardar en `~/.aws/credentials` para no repetirlo en cada terminal:

```ini
[default]
aws_access_key_id=ASIA...
aws_secret_access_key=...
aws_session_token=...
```

```bash
aws sts get-caller-identity    # comprobar que funcionan y ver la cuenta del reto
export AWS_REGION=us-west-2    # la región del reto (la pone en la página: us-west-2, us-east-1...)
```

> Las credenciales **caducan cada poco tiempo** (`ExpiredToken`). Cuando pase, se vuelven a copiar del botón. Cada reto tiene sus propias credenciales: las de un reto no sirven para otro.

## Método para cualquier reto

1. **Leer el enunciado entero** y fijarse en lo que se valida: muchas veces el validador mira algo muy concreto (un nombre exacto, un fichero en S3, una respuesta).
2. **Propiedades de salida:** apuntar los nombres de los recursos.
3. **Reconocimiento antes de tocar:** dibujar la arquitectura con lo que hay de verdad (VPC, rutas, targets, políticas). En el Reto 3, seguir el camino de un paquete salto a salto llevó directamente al fallo.
4. **Copiar de lo que ya funciona:** si hay 4 targets bien y falta el quinto, se lee uno que exista y se copia su formato.
5. **Buscar la trampa:** casi todos los retos tienen una (una regla que lo bloquea todo, un rol con otro nombre, una partición con un tipo que no admite el formato...).
6. **Comprobar con datos**, no suponer: un log, un `curl`, un `describe-...`.

## Lecciones generales del Jam

| Lección | Dónde salió |
|:--|:--|
| Los nombres "exactos" importan: el validador compara texto | `group-writer`, `jam-app`, `NetworkRejects` |
| Actualizar el código no basta: hay que desplegar una **versión nueva** y esperar a que esté activa | AgentCore Runtime (Reto 1) |
| Un `update` puede **borrar** lo que no se vuelve a pasar | Variables de entorno del Runtime (Reto 1) |
| Firewall con estado = rutas de **ida y vuelta** | GWLB y Network Firewall (Reto 3) |
| "Funciona" no siempre significa "inspecciona": comprobar en los logs que el servicio está en marcha | Suricata con `--queue-bypass` (Reto 3) |
| En Network Firewall con *action order*, **PASS gana a DROP** | Reto 3, Tarea 4 |
| El nombre que da el enunciado puede no ser el real: listar y buscar | Rol `Jam-CodeDeploy-<cuenta>-us-east-1` (Reto 5) |
| Los permisos de la cuenta del Jam son limitados: si la CLI no deja, la consola o las propiedades de salida sí | SCP en el Reto 6 |
| Los cambios de red y de reglas tardan: esperar a *In sync*, *liveVersion* o 5 minutos de BGP | Retos 1, 2, 3 y 6 |
| Sin `ssm:SendCommand` se pueden ejecutar comandos con `start-session` | [`ssm-ejecutar.sh`](Reto-3-Firewalls-Suricata-Network-Firewall/scripts/ssm-ejecutar.sh) |

## Cómo practicar en casa

- **Con el Jam abierto:** si la plataforma deja volver a entrar, *Restablecer el entorno de laboratorio* deja cada reto como al principio, así que se puede repetir.
- **Sin el Jam:** la mayoría de piezas se pueden montar en el **Learner Lab** de AWS Academy (us-east-1, con `LabRole`), por ejemplo:
  - **Reto 6** entero: una VPC con una EC2, flow logs a CloudWatch y S3, el metric filter, la alarma y la tabla de Athena.
  - **Reto 5:** un ASG con el agente de CodeDeploy y el `source.zip` de [`scripts/`](Reto-5-Implementaciones-CodeDeploy/scripts).
  - **Reto 3:** las reglas de Suricata se pueden probar en una EC2 Ubuntu con Suricata en modo NFQUEUE.
  - Los servicios que no estén disponibles en el Learner Lab (AgentCore, Cloud WAN, Network Firewall) se estudian con la guía y las preguntas de repaso.
- **Para estudiar tipo examen:** leer el enunciado, intentar responder "¿qué falla y por qué?" sin mirar la solución, y después comparar con el apartado *Cómo pensarlo*.

## Estructura

```text
AWS-Jam-2026/
├── README.md                                   ← este índice
├── Reto-1-Deduplicacion-Hallazgos-IA/
├── Reto-2-Redes-Globales-Cloud-WAN/
├── Reto-3-Firewalls-Suricata-Network-Firewall/
├── Reto-4-DevOps-Detective-CodePipeline/
├── Reto-5-Implementaciones-CodeDeploy/
└── Reto-6-Pruebe-el-Flujo-VPC-Flow-Logs/
    ├── README.md        ← guía paso a paso (consola + CLI), errores y preguntas
    ├── enunciado.md     ← enunciado de todas las tareas
    └── scripts/         ← comandos.sh y los ficheros usados (código, JSON, SQL, reglas)
```

> En los ficheros de `scripts/`, los identificadores de cada laboratorio (cuenta, buckets, `vpc-...`, `rtb-...`) son marcadores (`ACCOUNT_ID`, `xxxx`). Cada vez que se abre un reto son distintos.

---

<div align="center">

[Volver al repositorio](../README.md)

![Footer](https://capsule-render.vercel.app/api?type=waving&color=0:FF9900,100:232F3E&height=100&section=footer)

</div>
