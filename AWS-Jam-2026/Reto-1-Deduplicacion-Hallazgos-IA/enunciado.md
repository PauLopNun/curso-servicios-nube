# Enunciado - Reto 1: Deduplicación y priorización de hallazgos de seguridad con IA

Nombre en el Jam: *La seguridad impulsada por la IA descubre la deduplicación y la priorización*. Región: us-west-2.

## Tarea 1 - Reparar y conectar el Group Writer (30 puntos)

El equipo SOC ha construido un sistema de deduplicación con IA. El Gateway funciona con cuatro herramientas, los hallazgos llegan y el motor de similitud los procesa. Pero, cuando el agente agrupa los hallazgos por causa raíz, esos grupos desaparecen: nadie implementó la capa de persistencia.

Un ingeniero junior escribió una función Lambda para guardar los grupos en DynamoDB, pero no la probó. Al ejecutarla falla enseguida: el cliente de DynamoDB de boto3 no tiene el método `insert_item` (no es una API real), y el código no indica en qué tabla escribir. Dos errores, una Lambda.

**Tarea:** corregir los errores de la Lambda GroupWriter para que escriba en DynamoDB y añadirla como **quinto target** del Gateway. El nombre del target tiene que ser exactamente **`group-writer`**.

Pasos: localizar la Lambda (*GroupWriterLambdaName*), probarla con el payload de ejemplo (falla con `AttributeError`), corregir el código, volver a probar y añadirla al Gateway.

Payload de prueba:

```json
{"body": "{\"groups\": [{\"root_cause\": \"CVE-2024-21626\", \"title\": \"Container escape via runc\", \"severity\": \"CRITICAL\", \"member_count\": 4, \"priority_score\": 95, \"priority_rank\": 1, \"resource_type\": \"AWS::Lambda::Function\", \"data_classification\": \"internal\", \"environment\": \"production\"}]}"}
```

**Validación:** el Gateway tiene 5 targets activos y la Lambda funciona con el payload de prueba.

## Tarea 2 - Crear AgentCore Memory (40 puntos)

El agente se ejecuta cada noche, agrupa 157 hallazgos en 18 grupos y detecta que CVE-2024-21626 sigue afectando a las mismas 4 Lambdas cada semana. Pero a la mañana siguiente no recuerda nada: siempre empieza de cero. AgentCore Memory guarda los resultados de cada sesión como eventos y extrae de ellos hechos (estrategia semántica) y resúmenes (estrategia de resumen) que el agente puede recuperar después.

**Tarea:** crear desde la consola de AgentCore una memoria con dos estrategias de extracción (semántica y de resumen), esperar a que esté en ACTIVE y anotar su ID para la Tarea 3.

**Validación:** existe una memoria en ACTIVE con las dos estrategias configuradas.

## Tarea 3 - Desplegar el agente en AgentCore Runtime

Ya están las herramientas (el Gateway con 5 targets) y la memoria. Falta el cerebro. El código del agente está en un notebook de SageMaker: es una aplicación Python con Starlette que recoge hallazgos a través del Gateway, los enriquece, pide a Bedrock Nova Pro que los agrupe, guarda los grupos en DynamoDB, escribe un informe en S3 y guarda el contexto en la memoria.

El código se despliega bien y el Runtime llega a READY, pero al invocarlo falla: el payload MCP está mal formado y el nombre de la herramienta está vacío. Eso se corrige en la Tarea 4. Ahora solo hay que desplegarlo y confirmar que llega al Gateway.

**Tarea:** abrir el notebook, ejecutar todas sus celdas para empaquetar y subir el agente, y crear un Agent Runtime desde la consola de AgentCore con:

- `GATEWAY_URL` = *GatewayUrl*
- `OUTPUT_BUCKET` = *DedupOutputBucketName*
- `MEMORY_ID` = ID de la Tarea 2
- `SIMILARITY_THRESHOLD` = 0.6
- Entry point `agent.py`, Python 3.13

Invocarlo con *Test agent* en el endpoint DEFAULT con el prompt: *"Deduplicate all security findings, enrich with threat intelligence, and write results to the output bucket"*. Fallará, y es lo esperado.

**Validación:** hay un Agent Runtime en READY con las variables `GATEWAY_URL`, `OUTPUT_BUCKET` y `MEMORY_ID`.

## Tarea 4 - Arreglar el agente

La respuesta de la Tarea 3 da pistas, pero la información buena está en CloudWatch Logs: el Runtime registra cada llamada al Gateway, con el payload enviado y el error recibido (log group `/aws/bedrock-agentcore/runtimes/<runtime>-DEFAULT`).

**Tarea:** investigar los logs, corregir los bugs del código del notebook (marcados con `TODO`), volver a empaquetar y subir, **actualizar el Agent Runtime** (versión nueva) e invocarlo de nuevo hasta que escriba los grupos en S3. Subir el zip a S3 no actualiza el Runtime por sí solo.

**Validación:** existe `dedup-results/groups.json` en el bucket de salida y contiene al menos un grupo.
