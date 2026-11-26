#!/bin/bash
# Quest 3 - Operational Readiness (Step Functions, SQS DLQ, Synthetics, Resilience Hub, CloudWatch Agent)
# Esta quest la resolvió el compañero con la AWS CLI (desde Ubuntu) y la consola.
# Los comandos son los que registró CloudTrail, con la configuración que quedó en la cuenta. Ejecutar por bloques.

export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# --------------------------------------------------------------------------
# RETO 1 - Antipatrón: Lambda orquestadora esperando a un legacy de 10-12 min
# --------------------------------------------------------------------------
# Reconocimiento: Lambdas del flujo y sus timeouts (una Lambda dura como máximo 15 min)
aws lambda list-functions --query 'Functions[?contains(FunctionName,`Item`)].[FunctionName,Timeout]' --output text
# La orquestación pasa a una Step Function: rama paralela de detalle, precio y disponibilidad.
# La disponibilidad ya no se espera: GenerateAvailabilityRequest deja la petición en SQS y devuelve un id.
aws stepfunctions list-state-machines --query 'stateMachines[].[name,stateMachineArn]' --output text
aws stepfunctions describe-state-machine --state-machine-arn "arn:aws:states:us-east-1:${ACCOUNT_ID}:stateMachine:StateMachine" \
  --query definition --output text > state-machine.asl.json

# --------------------------------------------------------------------------
# RETO 2 - Dead-letter queue para las peticiones al legacy que fallan
# --------------------------------------------------------------------------
# Flujo: GenerateAvailabilityRequest -> SQS AvailabilityRequestQueue -> (ESM) -> GetItemAvailabilityFromLegacy
aws lambda list-event-source-mappings --query 'EventSourceMappings[].[FunctionArn,EventSourceArn,State,BatchSize]' --output text

QUEUE_URL=$(aws sqs get-queue-url --queue-name AvailabilityRequestQueue --query QueueUrl --output text)

# Crear la DLQ con retención máxima (14 días) para poder reprocesar con calma
DLQ_URL=$(aws sqs create-queue --queue-name AvailabilityRequestDLQ \
  --attributes MessageRetentionPeriod=1209600 --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names QueueArn --query Attributes.QueueArn --output text)

# Redrive policy en la cola original: tras 3 recepciones sin borrar, el mensaje pasa a la DLQ
aws sqs set-queue-attributes --queue-url "$QUEUE_URL" --attributes \
  "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}"

aws sqs get-queue-attributes --queue-url "$QUEUE_URL" --attribute-names RedrivePolicy VisibilityTimeout MessageRetentionPeriod
# Mensajes acumulados en la DLQ (en el GameDay llegaron a 116)
aws sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names ApproximateNumberOfMessages

# Reprocesar cuando el legacy vuelva: devolver los mensajes de la DLQ a la cola original
# aws sqs start-message-move-task --source-arn "$DLQ_ARN"

# --------------------------------------------------------------------------
# RETO 3 - Canary de CloudWatch Synthetics con el blueprint "Heartbeat monitoring"
# --------------------------------------------------------------------------
# Lo más sencillo es la consola (el blueprint genera el código). Resultado en la cuenta:
#   nombre unicorn-heartbeat, handler pageLoadBlueprint.handler, runtime syn-nodejs-puppeteer-*,
#   rate(1 minute), artefactos en s3://cw-synthetics-unicorn-<cuenta>/, rol CloudWatchSyntheticsRole-unicorn
aws synthetics describe-canaries --query 'Canaries[].[Name,Schedule.Expression,Status.State,RuntimeVersion,Code.Handler]' --output text
aws synthetics get-canary-runs --name unicorn-heartbeat --max-results 5 --query 'CanaryRuns[].[Status.State,Timeline.Started]' --output text

# --------------------------------------------------------------------------
# RETO 4 - Resilience Hub: política, app desde el stack y evaluación diaria
# --------------------------------------------------------------------------
STACK_ARN="arn:aws:cloudformation:us-east-1:${ACCOUNT_ID}:stack/gdQuests-xxxx-TeamEnable/xxxx"   # el del enunciado

POLICY_ARN=$(aws resiliencehub create-resiliency-policy --policy-name unicorn-resiliency-policy --tier MissionCritical \
  --policy '{"AZ":{"rtoInSecs":3600,"rpoInSecs":3600},"Hardware":{"rtoInSecs":3600,"rpoInSecs":3600},"Software":{"rtoInSecs":3600,"rpoInSecs":3600}}' \
  --query policy.policyArn --output text)

APP_ARN=$(aws resiliencehub create-app --name unicorn-inventory-app --policy-arn "$POLICY_ARN" \
  --assessment-schedule Daily --query app.appArn --output text)

aws resiliencehub import-resources-to-draft-app-version --app-arn "$APP_ARN" --source-arns "$STACK_ARN"
until [ "$(aws resiliencehub describe-draft-app-version-resources-import-status --app-arn "$APP_ARN" --query status --output text)" = "Success" ]; do sleep 10; done
aws resiliencehub publish-app-version --app-arn "$APP_ARN"

aws resiliencehub start-app-assessment --app-arn "$APP_ARN" --app-version release --assessment-name initial-assessment
aws resiliencehub list-app-assessments --app-arn "$APP_ARN" \
  --query 'assessmentSummaries[].[assessmentName,assessmentStatus,complianceStatus,resiliencyScore]' --output text
# Resultado en el GameDay: Success, PolicyBreached, puntuación 0.22 (lo normal en una app sin multi-AZ)

# --------------------------------------------------------------------------
# RETO 5 - CloudWatch Agent con métricas de memoria en la EC2 de Tomcat
# --------------------------------------------------------------------------
TOMCAT_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Web Server - Availability Service" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# El rol de la instancia NO tenía permiso para publicar métricas: hay que añadirle CloudWatchAgentServerPolicy
ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName,`LegacyWebAppRole`)].RoleName | [0]' --output text)
aws iam attach-role-policy --role-name "$ROLE" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# El primer intento (heredoc dentro de Run Command) FALLÓ por cómo se escapan los saltos de línea.
# Lo que funcionó: pasar el JSON en base64 y decodificarlo en la instancia.
B64=$(base64 -w0 amazon-cloudwatch-agent.json)
aws ssm send-command --instance-ids "$TOMCAT_ID" --document-name AWS-RunShellScript --parameters "commands=[
  \"rpm -q amazon-cloudwatch-agent || dnf install -y amazon-cloudwatch-agent\",
  \"echo $B64 | base64 -d > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json\",
  \"/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json\",
  \"/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status\"]"

# Alternativa sin JSON a mano: documento AWS-ConfigureAWSPackage (name=AmazonCloudWatchAgent)
# y AmazonCloudWatch-ManageAgent con la config guardada en Parameter Store.

# Comprobación: a los 1-2 minutos aparecen las métricas en el namespace CWAgent
aws cloudwatch list-metrics --namespace CWAgent --query 'Metrics[].[MetricName,Dimensions[0].Value]' --output text
