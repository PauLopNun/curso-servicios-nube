#!/bin/bash
# Reto 1 - Deduplicación y priorización de hallazgos de seguridad con IA
# Comandos usados para resolver las 4 tareas. Ejecutar por bloques, no de golpe.
# Rellenar las variables con los valores de "Propiedades de salida" del reto.

export AWS_REGION=us-west-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

GATEWAY_ID="security-dedup-gateway-xxxxxxxxxx"                     # GatewayId
GATEWAY_URL="https://${GATEWAY_ID}.gateway.bedrock-agentcore.${AWS_REGION}.amazonaws.com/mcp"
GROUP_WRITER="dedup-group-writer-${ACCOUNT_ID}"                    # GroupWriterLambdaName
ARTIFACT_BUCKET="labstack-...-agentartifactbucket-xxxx"             # AgentArtifactBucketName
OUTPUT_BUCKET="labstack-...-dedupoutputbucket-xxxx"                 # DedupOutputBucketName
RUNTIME_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/...AgentRuntimeRole-xxxx"  # AgentRuntimeRoleArn

# --------------------------------------------------------------------------
# 0. Ver todos los outputs de los stacks del laboratorio (si el rol lo permite)
# --------------------------------------------------------------------------
aws cloudformation describe-stacks --query 'Stacks[].Outputs[].[OutputKey,OutputValue]' --output table

# --------------------------------------------------------------------------
# TAREA 1 - Reparar la Lambda GroupWriter y añadirla al Gateway
# --------------------------------------------------------------------------

# 1.1 Descargar el código actual para leerlo
aws lambda get-function --function-name "$GROUP_WRITER" --query Code.Location --output text | xargs curl -s -o original.zip
unzip -o original.zip -d original && cat original/index.py

# 1.2 Probarla con la carga útil del enunciado: falla con AttributeError (insert_item)
aws lambda invoke --function-name "$GROUP_WRITER" --cli-binary-format raw-in-base64-out \
  --payload fileb://payload-prueba.json salida.json; cat salida.json

# 1.3 Subir el código corregido (group_writer_index.py -> index.py dentro del zip)
cp group_writer_index.py index.py && zip -q fixed.zip index.py
aws lambda update-function-code --function-name "$GROUP_WRITER" --zip-file fileb://fixed.zip
aws lambda wait function-updated --function-name "$GROUP_WRITER"

# 1.4 Volver a probar: ahora devuelve {"written": 1}
aws lambda invoke --function-name "$GROUP_WRITER" --cli-binary-format raw-in-base64-out \
  --payload fileb://payload-prueba.json salida.json; cat salida.json

# 1.5 Ver los targets que ya tiene el Gateway y copiar el formato de uno
aws bedrock-agentcore-control list-gateway-targets --gateway-identifier "$GATEWAY_ID" \
  --query 'items[].[name,status,targetId]' --output table
# aws bedrock-agentcore-control get-gateway-target --gateway-identifier "$GATEWAY_ID" --target-id <id>

# 1.6 Crear el quinto target, con el nombre exacto group-writer
sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" group-writer-target.json > target.json
aws bedrock-agentcore-control create-gateway-target --gateway-identifier "$GATEWAY_ID" \
  --name group-writer --description "Writes deduplicated groups to DynamoDB" \
  --target-configuration file://target.json \
  --credential-provider-configurations '[{"credentialProviderType":"GATEWAY_IAM_ROLE"}]'

# 1.7 Comprobar: 5 targets en estado READY
aws bedrock-agentcore-control list-gateway-targets --gateway-identifier "$GATEWAY_ID" \
  --query 'items[].[name,status]' --output text

# --------------------------------------------------------------------------
# TAREA 2 - Crear la memoria de AgentCore (semántica + resumen)
# --------------------------------------------------------------------------
MEMORY_ID=$(aws bedrock-agentcore-control create-memory --name DedupMemory \
  --description "Dedup agent session knowledge" --event-expiry-duration 30 \
  --memory-strategies '[
    {"semanticMemoryStrategy":{"name":"DedupFacts","namespaces":["/dedup/{actorId}/facts"]}},
    {"summaryMemoryStrategy":{"name":"DedupSummaries","namespaces":["/dedup/{actorId}/{sessionId}/summaries"]}}
  ]' --query memory.id --output text)
echo "MEMORY_ID=$MEMORY_ID"

# Esperar a ACTIVE (tarda 2-3 minutos)
aws bedrock-agentcore-control get-memory --memory-id "$MEMORY_ID" \
  --query 'memory.[status,strategies[].[name,type,status]]'

# --------------------------------------------------------------------------
# TAREA 3 - Empaquetar el agente y crear el Agent Runtime
# --------------------------------------------------------------------------

# 3.1 Dependencias para arm64 (Graviton) y Python 3.13, igual que el notebook
rm -rf pkg && pip install --platform manylinux2014_aarch64 --python-version 3.13 \
  --target pkg --only-binary=:all: --implementation cp bedrock-agentcore boto3

# 3.2 Zip con las dependencias en la raíz y agent.py al lado
#     (para la Tarea 3 se usa el agent.py ORIGINAL del notebook, con los bugs)
rm -f dedup-agent-code.zip
(cd pkg && zip -qr ../dedup-agent-code.zip . -x '*__pycache__*' '*.pyc')
zip -q dedup-agent-code.zip agent.py
aws s3 cp dedup-agent-code.zip "s3://${ARTIFACT_BUCKET}/agent-code/dedup-agent-code.zip"

# 3.3 Crear el Runtime con las 4 variables de entorno
ENV_VARS="GATEWAY_URL=${GATEWAY_URL},OUTPUT_BUCKET=${OUTPUT_BUCKET},MEMORY_ID=${MEMORY_ID},SIMILARITY_THRESHOLD=0.6"
ARTIFACT="{\"codeConfiguration\":{\"code\":{\"s3\":{\"bucket\":\"${ARTIFACT_BUCKET}\",\"prefix\":\"agent-code/dedup-agent-code.zip\"}},\"runtime\":\"PYTHON_3_13\",\"entryPoint\":[\"agent.py\"]}}"

RUNTIME_ID=$(aws bedrock-agentcore-control create-agent-runtime --agent-runtime-name dedup_agent \
  --agent-runtime-artifact "$ARTIFACT" --role-arn "$RUNTIME_ROLE_ARN" \
  --network-configuration networkMode=PUBLIC --environment-variables "$ENV_VARS" \
  --query agentRuntimeId --output text)
RUNTIME_ARN="arn:aws:bedrock-agentcore:${AWS_REGION}:${ACCOUNT_ID}:runtime/${RUNTIME_ID}"

# Esperar a READY (runtime y endpoint DEFAULT)
aws bedrock-agentcore-control get-agent-runtime --agent-runtime-id "$RUNTIME_ID" --query status
aws bedrock-agentcore-control list-agent-runtime-endpoints --agent-runtime-id "$RUNTIME_ID" \
  --query 'runtimeEndpoints[].[name,status,liveVersion]' --output text

# 3.4 Invocarlo: en la Tarea 3 DEBE fallar, devolviendo la lista de herramientas del Gateway
#     El session id tiene que tener 33 caracteres o más.
aws bedrock-agentcore invoke-agent-runtime --agent-runtime-arn "$RUNTIME_ARN" --qualifier DEFAULT \
  --runtime-session-id "dedup-session-$(date +%s)-000000000000000" \
  --content-type application/json --payload fileb://prompt.json --cli-read-timeout 300 respuesta.json
cat respuesta.json

# --------------------------------------------------------------------------
# TAREA 4 - Corregir agent.py, crear una versión nueva del Runtime y ejecutar
# --------------------------------------------------------------------------

# 4.1 Logs del Runtime (aquí se ven el payload enviado y el error del Gateway)
aws logs tail "/aws/bedrock-agentcore/runtimes/${RUNTIME_ID}-DEFAULT" --since 30m

# 4.2 Con el agent.py CORREGIDO (el de esta carpeta), sustituirlo dentro del zip y subirlo
zip -q dedup-agent-code.zip agent.py
aws s3 cp dedup-agent-code.zip "s3://${ARTIFACT_BUCKET}/agent-code/dedup-agent-code.zip"

# 4.3 Crear una versión nueva del Runtime. Hay que repetir TODOS los parámetros,
#     incluidas las variables de entorno: si no se pasan, se pierden.
aws bedrock-agentcore-control update-agent-runtime --agent-runtime-id "$RUNTIME_ID" \
  --agent-runtime-artifact "$ARTIFACT" --role-arn "$RUNTIME_ROLE_ARN" \
  --network-configuration networkMode=PUBLIC --environment-variables "$ENV_VARS"

# 4.4 Esperar a que el endpoint DEFAULT sirva la versión nueva (liveVersion), unos 7 minutos
aws bedrock-agentcore-control list-agent-runtime-endpoints --agent-runtime-id "$RUNTIME_ID" \
  --query 'runtimeEndpoints[].[name,status,liveVersion]' --output text

# 4.5 Invocar de nuevo y comprobar el resultado en S3
aws bedrock-agentcore invoke-agent-runtime --agent-runtime-arn "$RUNTIME_ARN" --qualifier DEFAULT \
  --runtime-session-id "dedup-session-$(date +%s)-000000000000000" \
  --content-type application/json --payload fileb://prompt.json --cli-read-timeout 600 respuesta.json
aws s3 cp "s3://${OUTPUT_BUCKET}/dedup-results/groups.json" - | head -40
