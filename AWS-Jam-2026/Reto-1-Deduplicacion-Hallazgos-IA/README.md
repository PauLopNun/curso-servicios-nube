<div align="center">

# Reto 1 - Deduplicación y priorización de hallazgos de seguridad con IA

![Bedrock](https://img.shields.io/badge/Amazon-Bedrock%20AgentCore-01A88D?style=for-the-badge&logoColor=white)
![Lambda](https://img.shields.io/badge/AWS-Lambda-FF9900?style=for-the-badge&logoColor=white)
![DynamoDB](https://img.shields.io/badge/Amazon-DynamoDB-4053D6?style=for-the-badge&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

**Nombre en el Jam:** *La seguridad impulsada por la IA descubre la deduplicación y la priorización* · 4 tareas · us-west-2

![Resuelto](https://img.shields.io/badge/Resuelto%20y%20verificado-2ea44f?style=flat-square)

</div>

## De qué va

Un equipo de seguridad (SOC) recibe cientos de hallazgos de **Amazon Inspector** y **AWS Config**, y muchos son el mismo problema repetido en varios recursos. Han construido un **agente de IA** que:

1. Recoge los hallazgos.
2. Los enriquece con inteligencia de amenazas (EPSS, exploits conocidos, ransomware).
3. Pide al modelo **Amazon Nova Pro** que los agrupe por causa raíz y los priorice por **impacto en el negocio**.
4. Guarda los grupos en **DynamoDB** y un informe en **S3**.
5. Recuerda lo que ha visto en sesiones anteriores gracias a **AgentCore Memory**.

El agente usa sus herramientas a través de un **AgentCore Gateway**: un servidor **MCP** (*Model Context Protocol*) que publica funciones Lambda como herramientas. El reto consiste en ir arreglando y montando las piezas que faltan.

## Arquitectura

```text
                       ┌──────────────────────── AgentCore Gateway (MCP) ───────────────────────┐
 Agent Runtime  ──MCP──►  findings-collector   threat-intel-enrichment   similarity-analyzer    │
 (agent.py)             │  asset-context-lookup   group-writer (Tarea 1)                         │
     │                  └──────────────────────────────────┬──────────────────────────────────────┘
     │ Bedrock (Nova Pro): agrupar y priorizar              │ Lambda
     │                                                       ▼
     ├──► S3: dedup-results/groups.json (Tarea 4)    DynamoDB: dedup-groups
     └──► AgentCore Memory (Tarea 2): eventos → hechos (semántica) + resúmenes
```

## Conceptos que hay que tener claros

| Concepto | Explicación corta |
|:--|:--|
| **MCP** | Protocolo estándar con el que un agente descubre y llama herramientas. Usa **JSON-RPC 2.0** con los métodos `tools/list` y `tools/call`. |
| **AgentCore Gateway** | Servicio gestionado que expone APIs o Lambdas como herramientas MCP. Cada destino es un *target*, y sus herramientas se llaman `target___herramienta`. |
| **AgentCore Runtime** | Ejecuta el código de un agente en contenedores **arm64** (Graviton). El código tiene que escuchar en el puerto 8080 con `GET /ping` y `POST /invocations`. |
| **AgentCore Memory** | Memoria del agente. Los **eventos** son la memoria a corto plazo; las **estrategias** (semántica, resumen, preferencias) extraen de ellos memoria a largo plazo. |
| **Propiedades de salida** | Pestaña del reto con los nombres de los recursos del laboratorio (Lambda, buckets, Gateway...). Es lo primero que hay que mirar. |

---

## Tarea 1 - Reparar y conectar el Group Writer (30 puntos)

### Qué pide

La Lambda `GroupWriter` debería guardar los grupos en DynamoDB, pero falla con `AttributeError`. Hay que corregirla y añadirla al Gateway como quinto target, con el nombre exacto **`group-writer`**.

### Cómo pensarlo

El enunciado ya da las dos pistas. Al leer el código aparecen:

```python
# ANTES (roto)
dynamodb.insert_item(          # insert_item no existe en boto3 -> AttributeError
    Item={...}                 # falta TableName: DynamoDB no sabe en qué tabla escribir
)

# DESPUÉS (corregido)
dynamodb.put_item(
    TableName=table_name,      # viene de la variable de entorno TABLE_NAME
    Item={...}
)
```

**Mejora extra que evita problemas en la Tarea 4:** cuando el **Gateway** invoca una Lambda, los argumentos llegan directamente en el evento (`{"groups": [...]}`). Cuando se prueba desde la consola con el payload del enunciado, llegan dentro de `body`. La Lambda corregida acepta los dos formatos. Ver [`scripts/group_writer_index.py`](scripts/group_writer_index.py).

### Paso a paso en la consola

1. **Lambda** → Functions → abrir `dedup-group-writer-<cuenta>` (sale en *GroupWriterLambdaName*).
2. Pestaña **Test** → *Create new event* → pegar el JSON de [`scripts/payload-prueba.json`](scripts/payload-prueba.json) → **Test**. Falla con `AttributeError: 'DynamoDB' object has no attribute 'insert_item'`.
3. Pestaña **Code** → en `index.py`, cambiar `insert_item(` por `put_item(` y añadir `TableName=table_name,` como primer parámetro (o pegar el fichero corregido entero).
4. Pulsar **Deploy** y repetir el **Test**: ahora devuelve `statusCode: 200` y `"written": 1`.
5. **Amazon Bedrock AgentCore** → **Gateways** → abrir `security-dedup-gateway-...` → sección **Targets** → **Add target**.
6. Rellenar:
   - **Target name:** `group-writer` (exactamente así).
   - **Target type:** *Lambda ARN* → pegar el ARN de *GroupWriterToolArn*.
   - **Tool schema:** *Define an inline schema* → pegar el array `inlinePayload` de [`scripts/group-writer-target.json`](scripts/group-writer-target.json).
   - **Outbound auth:** *IAM role* del Gateway (igual que los otros 4 targets).
7. **Add target** y esperar a que el estado pase a **Ready**. Tiene que haber 5 targets.

### Con la CLI

Bloque *TAREA 1* de [`scripts/comandos.sh`](scripts/comandos.sh): descargar el código, probar, `update-function-code`, `list-gateway-targets` y `create-gateway-target`.

> Truco: para no inventar el formato del target, se lee uno que ya exista con `get-gateway-target` y se copia su estructura.

### Comprobación

- La Lambda devuelve `{"written": 1, ...}` con el payload de prueba.
- `list-gateway-targets` muestra 5 targets en `READY`.

---

## Tarea 2 - Crear AgentCore Memory (40 puntos)

### Qué pide

Crear una memoria con **dos estrategias de extracción**: una **semántica** (extrae hechos) y otra de **resumen** (crea resúmenes de cada sesión). Tiene que quedar en `ACTIVE`, y su ID hace falta para la Tarea 3.

### Paso a paso en la consola

1. **Amazon Bedrock AgentCore** → **Memory** → **Create memory**.
2. **Name:** `DedupMemory`. Solo admite letras, números y `_`, empezando por letra.
3. **Short-term memory (raw event) expiration:** 30 días.
4. En **Long-term memory extraction strategies**, activar:
   - **Semantic**, con nombre `DedupFacts` y namespace `/dedup/{actorId}/facts`.
   - **Summarization**, con nombre `DedupSummaries` y namespace `/dedup/{actorId}/{sessionId}/summaries`.
5. **Create memory** y esperar 2-3 minutos a que pase de *Creating* a **Active**.
6. Copiar el **Memory ID** (por ejemplo, `DedupMemory-5l2gK19ktK`).

### Con la CLI

Bloque *TAREA 2* de [`scripts/comandos.sh`](scripts/comandos.sh): `create-memory` con las dos estrategias y `get-memory` para ver el estado.

### Comprobación

`get-memory` → `status: ACTIVE` y dos estrategias, `SEMANTIC` y `SUMMARIZATION`, también `ACTIVE`.

---

## Tarea 3 - Desplegar el agente en AgentCore Runtime

### Qué pide

Ejecutar el notebook `deploy_agent.ipynb` de SageMaker para empaquetar el agente y subirlo a S3. Después, crear un **Agent Runtime** con Python 3.13, entry point `agent.py` y 4 variables de entorno. Al invocarlo **tiene que fallar**, pero llegando al Gateway (los bugs se arreglan en la Tarea 4).

| Variable | Valor |
|:--|:--|
| `GATEWAY_URL` | *GatewayUrl* |
| `OUTPUT_BUCKET` | *DedupOutputBucketName* (el de salida, **no** el de artefactos) |
| `MEMORY_ID` | El ID de la Tarea 2 |
| `SIMILARITY_THRESHOLD` | `0.6` |

### Paso a paso en la consola

1. **SageMaker** → *Notebooks* → **Notebook instances** → `dedup-agent-notebook-...` → **Open JupyterLab**.
2. Abrir `deploy_agent.ipynb` → **Run** → **Run All Cells**. La primera celda pide 4 datos con `input()`: el bucket de artefactos, el de salida, la URL del Gateway y el Memory ID.
3. El notebook escribe `agent.py`, instala las dependencias **para arm64** (`--platform manylinux2014_aarch64 --python-version 3.13`), genera el zip y lo sube a `s3://<AgentArtifactBucket>/agent-code/dedup-agent-code.zip`. La última celda imprime todo lo que hay que poner en el Runtime.
4. **Amazon Bedrock AgentCore** → **Agents** → si no hay ninguno, **Deploy your code**; si ya hay, **More** → **Host agent**.
5. Rellenar:
   - **Name:** `dedup_agent`.
   - **Source:** *S3* → la ruta del zip.
   - **Entry point:** `agent.py`.
   - **Python runtime:** *Python 3.13*.
   - **IAM role:** *Use an existing role* → el de *AgentRuntimeRoleArn*.
   - **Environment variables:** las 4 de la tabla.
6. **Host agent** y esperar a que el agente y el endpoint **DEFAULT** estén en **Ready**.
7. Abrir el agente → endpoint **DEFAULT** → **Test agent** → enviar este payload:

   ```json
   {"prompt": "Deduplicate all security findings, enrich with threat intelligence, and write results to the output bucket"}
   ```

8. La respuesta es un error, y eso es lo que se espera: *"Failed to gather findings from Gateway... Available tools on this Gateway: ['asset-context-lookup___asset-context-lookup', 'findings-collector___findings-collector', ...]"*. Que salga la lista de herramientas demuestra que el agente sí llega al Gateway.

### Con la CLI

Bloque *TAREA 3* de [`scripts/comandos.sh`](scripts/comandos.sh). Se puede hacer lo mismo que el notebook en local, con `pip install --platform ...`, `zip` y `aws s3 cp`. Después, `create-agent-runtime` e `invoke-agent-runtime`.

> El `runtime-session-id` de `invoke-agent-runtime` tiene que tener **33 caracteres o más**; si no, da error de validación.

---

## Tarea 4 - Arreglar la llamada MCP y ejecutar el pipeline completo

### Qué pide

Encontrar los bugs con los logs de CloudWatch y el código, corregirlos, desplegar una **versión nueva** del Runtime e invocarlo hasta que escriba `dedup-results/groups.json` en S3 con al menos un grupo.

### Cómo pensarlo

En `agent.py` hay dos comentarios `TODO`:

**Bug 1 - El mensaje MCP no es JSON-RPC.** El Gateway habla MCP, y una llamada a una herramienta tiene este formato:

```python
# ANTES
mcp_payload = json.dumps({'name': target_name, 'arguments': payload or {}})

# DESPUÉS
mcp_payload = json.dumps({
    'jsonrpc': '2.0',
    'id': f'call-{target_name}',
    'method': 'tools/call',
    'params': {'name': target_name, 'arguments': payload or {}}
})
```

La función `list_available_tools()` del mismo fichero ya usaba bien el formato (`'method': 'tools/list'`). Comparar las dos funciones es la forma más rápida de ver el fallo.

**Bug 2 - Nombre de herramienta vacío.** La respuesta de la Tarea 3 ya da el nombre correcto:

```python
findings_resp = invoke_gateway_tool('findings-collector___findings-collector')
```

El código corregido está en [`scripts/agent.py`](scripts/agent.py).

### Paso a paso en la consola

1. **CloudWatch** → **Log groups** → `/aws/bedrock-agentcore/runtimes/<runtime-id>-DEFAULT`. Se ven `=== AVAILABLE GATEWAY TOOLS ===` y el error de la llamada a la herramienta.
2. En el **notebook**, corregir los dos `TODO` de la celda `%%writefile agent.py` y volver a ejecutar todas las celdas. Así se sube el zip nuevo.
3. **AgentCore** → **Agents** → `dedup_agent` → **Update hosting** (se crea la *version 2*). Comprobar que las 4 variables de entorno siguen puestas.
4. Esperar a que el endpoint **DEFAULT** apunte a la versión nueva. Tarda unos **7 minutos**, y mientras tanto sigue sirviendo la versión anterior.
5. **Test agent** con el mismo prompt. Ahora devuelve un JSON con `total_raw_findings`, `groups` y `_stored_at`.
6. **S3** → bucket de salida → `dedup-results/groups.json`.

### Con la CLI

Bloque *TAREA 4* de [`scripts/comandos.sh`](scripts/comandos.sh): `logs tail`, volver a subir el zip, `update-agent-runtime` y `invoke-agent-runtime`.

> **Importante:** `update-agent-runtime` sustituye la configuración entera. Si no se vuelven a pasar `--environment-variables`, el Runtime se queda **sin variables**.

### Resultado obtenido

39 hallazgos agrupados en **10 grupos**. El primero en prioridad fue *"S3 bucket public access not blocked"* (65 puntos), por delante de CVE críticos como el escape de contenedor de runc. El agente prioriza por **impacto en el negocio** (exposición pública, datos personales, producción) y no por la etiqueta de severidad.

---

## Errores típicos

| Síntoma | Causa | Solución |
|:--|:--|:--|
| `AttributeError: insert_item` | El método no existe en boto3 | `put_item` con `TableName` |
| La Lambda devuelve 400 *"No groups provided"* cuando la llama el agente | El Gateway no envía `body` | Leer `groups` del evento directamente |
| `invoke-agent-runtime`: error de validación | `runtime-session-id` demasiado corto | 33 caracteres o más |
| Tras corregir el código, sigue fallando igual | Solo se subió el zip a S3 | Actualizar el Runtime (versión nueva) y esperar a `liveVersion` |
| El agente no encuentra la memoria ni el bucket | Variables de entorno perdidas al actualizar | Volver a pasar las 4 en `update-agent-runtime` |
| `ExpiredToken` | Las credenciales del Jam duran poco | Volver a copiarlas desde **>_AWS_CLI** |

## Preguntas de repaso

<details>
<summary>¿Qué método de boto3 escribe un elemento en DynamoDB y qué parámetros son obligatorios?</summary>

`put_item`, con `TableName` e `Item`. Con el cliente de bajo nivel, cada atributo lleva su tipo: `{'S': 'texto'}`, `{'N': '95'}` (los números van como string).
</details>

<details>
<summary>¿Qué diferencia hay entre <code>boto3.client('dynamodb')</code> y <code>boto3.resource('dynamodb').Table(...)</code>?</summary>

El *client* es la API de bajo nivel: hay que indicar los tipos y pasar `TableName` en cada llamada. El *resource* es de alto nivel: el objeto `Table` ya sabe en qué tabla trabaja y convierte los tipos de Python automáticamente (`table.put_item(Item={'id': 'x', 'n': 95})`).
</details>

<details>
<summary>¿Qué métodos MCP usa un cliente y qué campos tiene una petición JSON-RPC 2.0?</summary>

`initialize`, `tools/list` y `tools/call`. Una petición lleva `jsonrpc: "2.0"`, `id`, `method` y `params`. En `tools/call`, `params` contiene `name` y `arguments`.
</details>

<details>
<summary>¿Por qué las herramientas del Gateway se llaman <code>findings-collector___findings-collector</code>?</summary>

El Gateway junta las herramientas de todos sus targets y, para que no se repitan nombres, les pone delante el nombre del target con tres guiones bajos: `<target>___<herramienta>`.
</details>

<details>
<summary>¿Qué contrato tiene que cumplir un agente en AgentCore Runtime y por qué las dependencias son para aarch64?</summary>

Tiene que escuchar en el puerto **8080**, con `GET /ping` para el health check y `POST /invocations` para las peticiones. Las dependencias son para aarch64 porque el Runtime ejecuta los agentes en instancias **Graviton (arm64)**, y una librería compilada para x86 no funcionaría.
</details>

<details>
<summary>¿Qué diferencia hay entre la estrategia semántica y la de resumen?</summary>

La **semántica** extrae hechos sueltos y reutilizables ("CVE-2024-21626 afecta a 4 Lambdas cada semana") y permite buscarlos por significado. La de **resumen** condensa una sesión entera en un texto corto. Las dos se generan de forma asíncrona a partir de los eventos que guarda el agente con `create_event`.
</details>

<details>
<summary>¿Por qué no basta con subir el zip nuevo a S3?</summary>

El Runtime empaqueta el código cuando se crea o se actualiza. Para que use el zip nuevo hay que crear una **versión nueva** (`update-agent-runtime` o *Update hosting*) y esperar a que el endpoint DEFAULT la sirva (`liveVersion`).
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 4 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Todos los comandos de CLI, por tareas |
| [`scripts/group_writer_index.py`](scripts/group_writer_index.py) | Lambda GroupWriter corregida |
| [`scripts/group-writer-target.json`](scripts/group-writer-target.json) | Configuración del target `group-writer` |
| [`scripts/payload-prueba.json`](scripts/payload-prueba.json) | Payload de prueba de la Lambda |
| [`scripts/agent.py`](scripts/agent.py) | Agente con los dos bugs corregidos |
| [`scripts/prompt.json`](scripts/prompt.json) | Prompt para invocar el agente |

---

[Volver al índice del Jam](../README.md)
