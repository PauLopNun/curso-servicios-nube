<div align="center">

# Reto 6 - Pruebe el flujo (VPC Flow Logs, CloudWatch, S3 y Athena)

![VPC](https://img.shields.io/badge/VPC-Flow%20Logs-8C4FFF?style=for-the-badge&logoColor=white)
![CloudWatch](https://img.shields.io/badge/Amazon-CloudWatch-FF4F8B?style=for-the-badge&logoColor=white)
![S3](https://img.shields.io/badge/Amazon-S3-569A31?style=for-the-badge&logoColor=white)
![Athena](https://img.shields.io/badge/Amazon-Athena-8C4FFF?style=for-the-badge&logoColor=white)

**Nombre en el Jam:** *Pruebe el flujo* (*Probe The Flow*) · 3 tareas · us-west-2

![Resuelto](https://img.shields.io/badge/Resuelto%20y%20verificado-2ea44f?style=flat-square)

</div>

## De qué va

SecureNow Pvt Ltd. no tiene forma de ver el tráfico de la VPC donde están sus aplicaciones, así que no puede detectar ni responder a un ataque. Hay que:

1. Activar **VPC Flow Logs** y enviarlos a **CloudWatch Logs** y a **S3**.
2. Crear en CloudWatch un **filtro de métrica** y una **alarma** que avise cuando haya tráfico rechazado.
3. Consultar los logs de S3 con **Athena** usando SQL.

## Arquitectura

```text
                              ┌──► CloudWatch Logs ──► metric filter (REJECT) ──► alarma ──► SNS VpcAlarmTopic
 MyVPC ──► VPC Flow Logs ─────┤        (Tarea 1)            (Tarea 2)
                              └──► S3 (AWSLogs/<cuenta>/vpcflowlogs/us-west-2/AAAA/MM/DD/*.log.gz)
                                        │
                                        └──► Athena: tabla default.vpc_flow_logs ──► SQL (Tarea 3)
```

## Qué es un registro de flow log

Cada línea resume una "conversación" de red durante un intervalo (de 1 o 10 minutos). En el formato por defecto, versión 2, tiene 14 campos separados por espacios:

```text
2 123456789012 eni-0abc123 10.0.1.146 162.159.200.1 41000 123 17 1 76 1764087000 1764087060 REJECT OK
│ └─ cuenta    └─ ENI      └─ origen  └─ destino     └ puertos └proto └bytes└ inicio    └ fin    └acción └estado
versión                                                       (17=UDP) paquetes
```

- **action:** `ACCEPT` o `REJECT`, según lo que decidieron los security groups y las NACL.
- **log-status:** `OK`, `NODATA` (no hubo tráfico) o `SKIPDATA` (se perdieron registros).
- **Protocolos:** 6 = TCP, 17 = UDP, 1 = ICMP.

---

## Tarea 1 - Activar los flow logs (45 puntos)

### Qué pide

Activar los flow logs de la VPC **MyVPC** con dos destinos: el bucket S3 y el log group de CloudWatch que da el laboratorio.

### Cómo pensarlo

Un flow log tiene **un solo destino**, así que hacen falta **dos flow logs** sobre la misma VPC:

| Destino | Permisos |
|:--|:--|
| CloudWatch Logs | Hace falta un **rol IAM** que el servicio asume para escribir en el log group (*DeliverVPCFlowLogsRoleName*) |
| S3 | **Sin rol**: AWS añade o usa la política del bucket para que el servicio de entrega de logs pueda escribir |

### Paso a paso en la consola

1. **VPC** → **Your VPCs** → seleccionar `MyVPC` (*MyVpcId*) → pestaña **Flow logs** → **Create flow log**.
2. Primer flow log, a CloudWatch:
   - **Name:** `MyVPC-flowlogs-cw` → **Filter:** *All* → **Maximum aggregation interval:** 10 minutos (o 1 minuto, para ver datos antes).
   - **Destination:** *Send to CloudWatch Logs* → **Destination log group:** el de *VPCFlowLogsLogGroupName*.
   - **IAM role:** el de *DeliverVPCFlowLogsRoleName*.
   - **Log record format:** *AWS default format* → **Create flow log**.
3. Segundo flow log, a S3:
   - **Create flow log** otra vez → **Name:** `MyVPC-flowlogs-s3` → **Filter:** *All*.
   - **Destination:** *Send to an Amazon S3 bucket* → **S3 bucket ARN:** `arn:aws:s3:::<VPCFlowLogsBucketName>`.
   - **Log record format:** *AWS default format* → **Create flow log**.
4. En la pestaña **Flow logs** de la VPC tienen que aparecer los dos en estado **Active**.

### Con la CLI

Bloque *TAREA 1* de [`scripts/comandos.sh`](scripts/comandos.sh).

> En este laboratorio la CLI no dejaba listar buckets ni leer los outputs de CloudFormation (lo bloqueaba la SCP de la cuenta). Los nombres había que copiarlos de **Propiedades de salida**.

### Comprobación

`describe-flow-logs` → los dos en `ACTIVE` con `DeliverLogsStatus: SUCCESS`. A los 5-10 minutos aparecen streams `eni-...` en el log group y ficheros `.log.gz` en el bucket.

---

## Tarea 2 - Metric filter y alarma de tráfico rechazado (53 puntos)

### Qué pide

En el log group de los flow logs, crear un filtro que cuente **todo el tráfico rechazado** y una alarma que avise al topic SNS `VpcAlarmTopic`:

| Elemento | Nombre |
|:--|:--|
| Metric name | `NetworkRejects` |
| Metric namespace | `vpcflowlogs` |
| Alarm name | `NetworkRejects` |

### Cómo pensarlo

Como cada línea son campos separados por espacios, se usa un **filter pattern de campos**: se pone un nombre a cada una de las 14 posiciones y se fija el valor de la que interesa.

```text
[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]
```

Cada línea que coincide suma **1** a la métrica. La alarma se dispara si la **suma** en 5 minutos es **≥ 1**.

### Paso a paso en la consola

1. **CloudWatch** → **Log groups** → abrir el log group de los flow logs → pestaña **Metric filters** → **Create metric filter**.
2. **Filter pattern:** pegar el patrón de arriba → **Test pattern**, con un log stream para ver qué líneas coinciden → **Next**.
3. **Filter name:** `NetworkRejects` → **Metric namespace:** `vpcflowlogs` → **Metric name:** `NetworkRejects` → **Metric value:** `1` → **Default value:** `0` → **Next** → **Create metric filter**.
4. En el filtro creado, marcar la casilla → **Create alarm**. Se abre el asistente de alarmas con la métrica ya elegida.
5. **Statistic:** *Sum* → **Period:** 5 minutos → **Threshold type:** *Static* → *Greater/Equal* → `1` → **Next**.
6. **Notification:** *In alarm* → **Select an existing SNS topic** → `VpcAlarmTopic` → **Next**. El aviso de permisos de los endpoints de email se puede ignorar, porque no hace falta para el reto.
7. **Alarm name:** `NetworkRejects` → **Next** → **Create alarm**.

### Con la CLI

Bloque *TAREA 2* de [`scripts/comandos.sh`](scripts/comandos.sh): `put-metric-filter` y `put-metric-alarm`. Incluye `test-metric-filter` para probar el patrón con una línea de ejemplo antes de crearlo.

### Comprobación

La alarma empieza en `INSUFFICIENT_DATA`, porque todavía no hay datos, y pasa a `ALARM` con el primer REJECT.

---

## Tarea 3 - Consultar los logs con Athena (52 puntos)

### Qué pide

Crear en la base de datos **`default`** de Athena una tabla que lea los flow logs de S3 y lanzar consultas. Para validar, se escribe **el nombre de la tabla** en la caja de respuesta. Aquí fue **`vpc_flow_logs`**.

### Cómo pensarlo

- Athena no guarda datos: la tabla es solo una **descripción** (columnas, formato y ubicación en S3) de ficheros que ya existen.
- Los flow logs se guardan en carpetas por fecha: `.../vpcflowlogs/us-west-2/2026/11/25/`. Con **partition projection**, Athena calcula esas carpetas a partir de la fecha y no hay que registrar particiones a mano (`MSCK REPAIR TABLE` o `ALTER TABLE ADD PARTITION`).
- La primera línea de cada fichero es la cabecera: `skip.header.line.count = 1`.
- Athena necesita un sitio donde **guardar los resultados** de las consultas: el bucket *AthenaFlowLogsQueryBucketName*.

### Paso a paso en la consola

1. **Athena** → **Query editor**. Si es la primera vez, sale *"Before you run your first query, you need to set up a query result location"*: **Edit settings** → `s3://<AthenaFlowLogsQueryBucketName>/` → **Save**.
2. **Database:** `default`.
3. Pegar el `CREATE EXTERNAL TABLE` de [`scripts/crear_tabla.sql`](scripts/crear_tabla.sql), sustituyendo `FLOWLOGS_BUCKET` por el nombre del bucket y `ACCOUNT_ID` por la cuenta (se ve en la ruta del bucket: `AWSLogs/<cuenta>/`) → **Run**.
4. Nueva pestaña → lanzar las consultas de [`scripts/consultas.sql`](scripts/consultas.sql), cambiando la fecha por la del día:

   ```sql
   SELECT srcaddr, dstaddr, dstport, protocol, action
   FROM vpc_flow_logs WHERE date = '2026/11/25' LIMIT 10;

   SELECT action, count(*) AS total FROM vpc_flow_logs GROUP BY action;
   ```

5. En la tarea del Jam, escribir `vpc_flow_logs` en la caja de respuesta → **Submit Answer**.

### Con la CLI

Bloque *TAREA 3* de [`scripts/comandos.sh`](scripts/comandos.sh). Incluye una función `athena` que lanza la consulta, espera y muestra el resultado.

### El fallo que hubo que corregir

Con la columna de partición definida como `date date` y el formato `yyyy/MM/dd`, la consulta falla con:

```text
HIVE_INVALID_PARTITION_VALUE: Invalid partition value '2026/11/01' for DATE partition key
```

Un tipo DATE no admite barras. La columna de partición tiene que ser **`string`**. La **proyección** sí es de tipo `date` (`projection.date.type = date`), y así se pueden usar rangos de fechas.

### Resultado obtenido

24 registros **REJECT** (sobre todo tráfico NTP saliente al puerto UDP 123, y algo al 443) y 40 registros con acción `-`, que corresponden a intervalos `NODATA`.

---

## Errores típicos

| Síntoma | Causa | Solución |
|:--|:--|:--|
| El log group o el bucket siguen vacíos | Los flow logs tardan 5-10 minutos | Esperar; con intervalo de 1 minuto se ven antes |
| Flow log a CloudWatch con error de permisos | Falta el rol o no es el correcto | Usar *DeliverVPCFlowLogsRoleName* |
| El filtro no cuenta nada | Patrón mal escrito o con menos de 14 campos | **Test pattern** con datos reales |
| El filtro no cuenta los logs antiguos | Los metric filters solo procesan eventos nuevos | Normal: cuenta a partir de su creación |
| Athena: *"No output location provided"* | No hay ubicación para los resultados | Configurarla en *Settings* o en el workgroup |
| `HIVE_INVALID_PARTITION_VALUE` | Partición tipo DATE con barras | Partición `string` + proyección `date` |
| La consulta devuelve 0 filas | La fecha del `WHERE` no es la de los logs (UTC) | Usar el formato `AAAA/MM/DD` de la fecha UTC |

## Preguntas de repaso

<details>
<summary>¿A qué destinos pueden enviarse los flow logs y por qué CloudWatch necesita un rol y S3 no?</summary>

A **CloudWatch Logs**, **S3** y **Kinesis Data Firehose**. Para CloudWatch, el servicio de flow logs asume un **rol IAM** con permiso para crear streams y escribir eventos en el log group. Para S3, el servicio de entrega de logs escribe gracias a la **política del bucket**, que AWS crea o completa al configurar el flow log.
</details>

<details>
<summary>¿A qué niveles se pueden activar los flow logs y qué valores tiene traffic-type?</summary>

A nivel de **VPC**, de **subred** o de **interfaz de red (ENI)**, además de en algunos servicios como Transit Gateway. `traffic-type` puede ser `ACCEPT`, `REJECT` o `ALL`.
</details>

<details>
<summary>¿Qué tráfico no registran los flow logs?</summary>

Entre otros: el tráfico al DNS de Amazon (Route 53 Resolver), al servicio de metadatos `169.254.169.254`, al servidor de tiempo de Amazon `169.254.169.123`, el DHCP, la activación de licencias de Windows y el tráfico a la IP reservada del router de la VPC.
</details>

<details>
<summary>¿Qué tipos de filter pattern hay en CloudWatch Logs?</summary>

De **texto o términos** (`ERROR`, `"exact phrase"`), de **campos separados por espacios** (`[campo1, campo2=valor, ...]`, el que se usa aquí) y **JSON** (`{ $.campo = "valor" }`) para logs en ese formato.
</details>

<details>
<summary>¿Qué estados tiene una alarma y qué hace treat-missing-data?</summary>

`OK`, `ALARM` e `INSUFFICIENT_DATA`. `treat-missing-data` dice qué hacer cuando no hay datos en un periodo: `missing` (por defecto), `notBreaching` (cuenta como "todo bien"), `breaching` (cuenta como "fallo") o `ignore` (mantiene el estado anterior).
</details>

<details>
<summary>¿Qué es partition projection y por qué conviene filtrar siempre por la partición?</summary>

Es una configuración de la tabla con la que Athena **calcula** las particiones (las carpetas de cada fecha) a partir de una plantilla, sin tener que registrarlas en el catálogo. Conviene filtrar por la partición porque Athena **cobra por los datos que lee**: con `WHERE date = '...'` solo lee la carpeta de ese día.
</details>

<details>
<summary>¿Por qué un REJECT puede indicar un ataque?</summary>

Muchos REJECT desde una misma IP o hacia muchos puertos distintos suelen ser un **escaneo de puertos** o intentos de conexión a servicios cerrados. Los REJECT salientes, como los de NTP de este laboratorio, indican que algo dentro de la VPC intenta salir y lo bloquea un security group o una NACL. Si es un programa desconocido, puede ser malware intentando contactar con el exterior.
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 3 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Solución por CLI de las 3 tareas |
| [`scripts/crear_tabla.sql`](scripts/crear_tabla.sql) | Tabla de Athena con partition projection |
| [`scripts/consultas.sql`](scripts/consultas.sql) | Consultas de ejemplo para analizar el tráfico |

---

[Volver al índice del Jam](../README.md)
