
<div align="center">

![Header](https://capsule-render.vercel.app/api?type=waving&color=0:FF9900,100:232F3E&height=180&section=header&text=AWS%20GameDay%202026&fontSize=44&fontColor=fff&animation=fadeIn&fontAlignY=36&desc=Unicorn.Rentals%20%7C%2026%2F11%2F2026&descAlignY=56&descAlign=50)

![AWS](https://img.shields.io/badge/AWS-GameDay-FF9900?style=for-the-badge&logoColor=white)
![Quests](https://img.shields.io/badge/Quests-4-232F3E?style=for-the-badge)
![CLI](https://img.shields.io/badge/AWS%20CLI-v2-232F3E?style=for-the-badge&logoColor=white)

</div>

## Qué es esto

Guía de estudio de las **4 quests** del AWS GameDay de **Unicorn.Rentals**, hecho en clase el 26/11/2026, el día después del [AWS Jam](../AWS-Jam-2026). El evento era el **Campeonato Nacional FP - Clasificatoria Online, AWS GameDay - Quest Combo** (región us-east-1).

<div align="center">

| Portada del evento | Votación *Best Team Name* (cerrada) |
|:-:|:-:|
| ![Portada del GameDay](capturas/web_01_portada_evento.jpg) | ![Best Team Name](capturas/web_02_best_team_name.jpg) |

</div>

Para cada quest hay:

- **Enunciado** de cada tarea, traducido.
- **Cómo pensarlo**: qué hay que mirar y por qué, antes de tocar nada.
- **Paso a paso en la consola**, con menús, botones y campos.
- **Paso a paso con la AWS CLI**, con todos los comandos en `scripts/comandos.sh`.
- **Comprobación**: cómo saber que está bien.
- **Errores típicos** que aparecieron de verdad y cómo se resolvieron.
- **Preguntas de repaso** con la respuesta desplegable, para estudiar tipo examen.

## Las quests

<div align="center">

| # | Quest (nombre en el GameDay) | Servicios | Tareas | Estado |
|:-:|:--|:--|:-:|:-:|
| 1 | [Network Foundations](Quest-1-Network-Foundations) | VPC IPAM, CloudFormation, Transit Gateway, NAT | 3 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 2 | [Forge the Mythic Bond](Quest-2-Forge-the-Mythic-Bond) | PrivateLink, NLB, AWS WAF | 2 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 3 | [Operational Readiness](Quest-3-Operational-Readiness) | Step Functions, SQS DLQ, Synthetics, Resilience Hub, CloudWatch Agent | 5 | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |
| 4 | [Storage Security](Quest-4-Storage-Security) | CloudTrail, S3, IAM, AWS Backup | 5 + 4 preguntas | ![Resuelto](https://img.shields.io/badge/Resuelto-2ea44f?style=flat-square) |

</div>

Las 4 quests están resueltas. Para cada una se explica el proceso real de resolución, reconstruido con **CloudTrail** y con lo que quedó en la cuenta.

## Cómo se resolvió cada quest

| Quest | Herramientas |
|:--|:--|
| Network Foundations | AWS CLI desde PowerShell (Windows); cada paso se comprobó con `describe-...` antes de seguir |
| Forge the Mythic Bond | AWS CLI desde PowerShell, con pruebas reales por `curl` desde la EC2 mediante SSM Run Command |
| Operational Readiness | Consola de AWS y AWS CLI desde Ubuntu para casi todos los cambios |
| Storage Security | Consola de AWS y AWS CLI desde Ubuntu |

Cada README tiene un apartado **Cómo se resolvió** con el orden real de los pasos, los fallos que salieron y cómo se arreglaron. Las carpetas `capturas/` tienen los diagramas del enunciado y la página de cada quest del GameDay entera, de arriba abajo, para leer el enunciado original en inglés. La carpeta `capturas/` de este índice tiene la portada del evento y la herramienta *Best Team Name*.

### Cómo se reconstruyó lo que hizo cada uno: CloudTrail

Todo lo que se hace en la cuenta queda en **CloudTrail**: la hora, la llamada a la API, los parámetros, la IP y el *user agent*. El *user agent* distingue la consola (`Mozilla/...`), la CLI (`aws-cli/2.x`, con el sistema operativo) y los servicios de AWS. Así se sacó la cronología de las quests 3 y 4. Es un buen ejercicio repetirlo:

```bash
# Eventos de escritura (no lecturas) desde una hora, con quién y desde dónde
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ReadOnly,AttributeValue=false \
  --start-time 2026-11-26T08:30:00Z \
  --query 'Events[].[EventTime,EventName,CloudTrailEvent]' --output json > eventos.json
jq -r '.[] | [.[0], .[1], (.[2]|fromjson|.sourceIPAddress), (.[2]|fromjson|.userAgent|split(" ")[0])] | @tsv' eventos.json | sort

# Eventos de datos de S3 (GetObject, PutObject...): solo si un trail los registra, y están en SU bucket
aws s3 sync s3://<bucket-del-trail>/AWSLogs/<cuenta>/CloudTrail/us-east-1/2026/11/26/ ./trail
zcat trail/*.json.gz | jq -r '.Records[] | select(.eventSource=="s3.amazonaws.com") | [.eventTime,.eventName,.userIdentity.arn,.requestParameters.key] | @tsv'
```

> `lookup-events` solo muestra eventos de **gestión** de los últimos 90 días. Los eventos de **datos** (objetos de S3, invocaciones de Lambda) solo existen si un trail los tiene activados.

En CloudTrail también aparece, a las 10:40, una entrada con el rol `WSOpsRole`: es el **personal del evento** revisando la cuenta.

## GameDay frente a Jam

| | AWS Jam (25/11) | AWS GameDay (26/11) |
|:--|:--|
| Cuentas | Una cuenta **por reto** | **Una sola cuenta** para todo el equipo y todas las quests |
| Orden | Retos independientes | Quests con historia; las tareas se desbloquean en orden y algunas dependen de lo anterior (los pools de IPAM alimentan el stack de red) |
| Validación | *Check my progress* o respuesta | Automática cada 1-2 minutos, respuesta en una caja o botón **Evaluate** |
| Penalizaciones | Pistas | Pistas y, en alguna tarea, **puntos negativos por minuto** hasta que se cumple (Storage Security, tarea 2) |
| Credenciales | Botón >_AWS_CLI de cada reto | **AWS Console** → *Command line access* del portal (Workshop Studio, rol `WSParticipantRole/Participant`) |

### Usar la CLI con las credenciales del GameDay

El portal da las variables en formato PowerShell (`$Env:AWS_ACCESS_KEY_ID=...`) y CMD (`set ...`): son las mismas claves en dos formatos. Para no depender de la terminal, se guardan en un perfil:

```bash
aws configure set aws_access_key_id     ASIA...  --profile gameday
aws configure set aws_secret_access_key ...      --profile gameday
aws configure set aws_session_token     ...      --profile gameday
aws configure set region us-east-1               --profile gameday
aws sts get-caller-identity --profile gameday    # rol WSParticipantRole/Participant
```

> Caducan (`ExpiredToken`): se vuelven a copiar del portal. El key pair `ws-default-keypair` que aparece en la cuenta es para SSH a EC2, **no** son credenciales.

## Método para cualquier quest

1. **Leer la tarea entera** y ver qué valida: un ID en una caja, un camino de red, una URL...
2. **Reconocimiento antes de tocar:** `describe-...` de todo lo que hay (VPC, subredes, tablas de rutas, LB, SG). En Network Foundations, ver que el TGW tenía la asociación y la propagación por defecto desactivadas cambió todo el diseño.
3. **Pensar en la siguiente tarea:** el GameDay avisa de que las decisiones influyen en las quests siguientes (TGW con dos tablas y appliance mode pensando en el futuro Network Firewall).
4. **Esperar a que el recurso esté listo** antes de dar algo por roto: attachments `pending`, targets `initial`, stacks `CREATE_IN_PROGRESS`.
5. **Comprobar con datos desde dentro:** `curl` desde la EC2 por **SSM Run Command**, con `200`/`403` como prueba.
6. **El validador va con retraso:** mirar la hora de *Last updated* antes de pensar que algo falla.

## Lecciones generales del GameDay

| Lección | Dónde salió |
|:--|:--|
| Un **espacio** al pegar un ID basta para que lo dé por inválido | Pool regional de IPAM (Quest 1) |
| En IPAM, *min netmask length* = bloque **más grande** | Reglas de asignación (Quest 1) |
| El validador puede comprobar **antes** de que el recurso termine: mirar la hora | Stack de CloudFormation y rutas (Quest 1) |
| En egress centralizado, la **vuelta** del NAT necesita ruta al TGW en las subredes públicas | Quest 1, tarea 3 |
| Con CIDR solapados, **PrivateLink** (servicio) y no peering ni TGW (redes) | Quest 2 |
| PrivateLink solo va con **NLB**: delante de un ALB, NLB con target group tipo `alb` | Quest 2 |
| WAF se pone en el **ALB**, no en el NLB | Quest 2 |
| Un *timeout* justo después de crear algo suele ser un target aún en `initial` | Quest 2 |
| Orquestar en una Lambda que espera es un **antipatrón**: Step Functions + cola | Quest 3, reto 1 |
| Las peticiones que fallan se guardan con una **DLQ** (redrive policy) | Quest 3, reto 2 |
| La memoria de una EC2 solo se ve con el **CloudWatch Agent** | Quest 3, reto 5 |
| En Run Command, un JSON con varias líneas se pasa mejor en **base64** | Quest 3, reto 5 |
| **Deny explícito** en la política del bucket gana a cualquier Allow | Quest 4, tarea 2 |
| Con versionado, "borrar" es poner un **delete marker**: se recupera por `versionId` | Quest 4, tarea 3 |
| PowerShell rompe comillas y variables en argumentos de la CLI | `"Id=$arn,Port=80"`, `--parameters file://cmd.json` |

## Cómo practicar en casa

- En el **Learner Lab** de AWS Academy (us-east-1, con `LabRole`) se pueden montar casi todas las piezas:
  - **Quest 1:** dos o tres VPC con un Transit Gateway y un NAT, y las tablas `spoke-rt` / `shared-rt`. IPAM puede no estar permitido; en ese caso los CIDR se ponen a mano.
  - **Quest 2:** dos VPC con el mismo CIDR, un ALB con una EC2 en una, NLB + endpoint service y el interface endpoint en la otra; después, el web ACL con la regla SQLi.
  - **Quest 3:** una cola SQS con DLQ y una Lambda que falle a propósito; el CloudWatch Agent en una EC2.
  - **Quest 4:** un bucket versionado, borrar ficheros y recuperarlos por `versionId`; un bucket con Deny a un rol.
- **Para estudiar tipo examen:** leer el enunciado, intentar responder "¿qué servicio y por qué?" sin mirar, y comparar con *Cómo pensarlo*.

## Estructura

```text
AWS-GameDay-2026/
├── README.md                               ← este índice
├── capturas/                               ← portada del evento y Best Team Name
├── Quest-1-Network-Foundations/
├── Quest-2-Forge-the-Mythic-Bond/
├── Quest-3-Operational-Readiness/
└── Quest-4-Storage-Security/
    ├── README.md        ← guía paso a paso (consola + CLI), cómo se resolvió, errores y preguntas
    ├── enunciado.md     ← enunciado de todas las tareas
    ├── scripts/         ← comandos.sh y los ficheros usados (JSON, ASL, configuración)
    └── capturas/        ← diagramas del enunciado y la página de la quest en el GameDay, entera
```

> En los ficheros de `scripts/`, los identificadores del laboratorio (cuenta, `vpc-...`, `rtb-...`, `ipam-pool-...`) son marcadores (`ACCOUNT_ID`, `xxxx`). Cada vez que se abre el GameDay son distintos.

---

<div align="center">

[Volver al repositorio](../README.md)

![Footer](https://capsule-render.vercel.app/api?type=waving&color=0:FF9900,100:232F3E&height=100&section=footer)

</div>
