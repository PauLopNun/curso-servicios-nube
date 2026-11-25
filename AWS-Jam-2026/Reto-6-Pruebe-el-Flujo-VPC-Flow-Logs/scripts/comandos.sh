#!/bin/bash
# Reto 6 - Pruebe el flujo (VPC Flow Logs, CloudWatch, S3 y Athena)
# Comandos usados para resolver las 3 tareas. Ejecutar por bloques, no de golpe.
# Rellenar las variables con los valores de "Propiedades de salida" del reto.

export AWS_REGION=us-west-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

VPC_ID=vpc-xxxxxxxx                                   # MyVpcId
FLOWLOGS_BUCKET=labstack-...-vpcflowlogsbucket-xxxx   # VPCFlowLogsBucketName
LOG_GROUP=LabStack-...-VPCFlowLogsLogGroup-xxxx       # VPCFlowLogsLogGroupName
ROLE_NAME=LabStack-...-DeliverVPCFlowLogsRole-xxxx    # DeliverVPCFlowLogsRoleName
ATHENA_BUCKET=labstack-...-athenaqueryresultsbucket-xxxx  # AthenaFlowLogsQueryBucketName

# --------------------------------------------------------------------------
# TAREA 1 - Dos flow logs: uno a CloudWatch Logs y otro a S3
# --------------------------------------------------------------------------
# A CloudWatch: necesita el rol que da permiso al servicio para escribir en el log group
aws ec2 create-flow-logs --resource-type VPC --resource-ids "$VPC_ID" --traffic-type ALL \
  --log-destination-type cloud-watch-logs --log-group-name "$LOG_GROUP" \
  --deliver-logs-permission-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# A S3: sin rol (usa la política del bucket)
aws ec2 create-flow-logs --resource-type VPC --resource-ids "$VPC_ID" --traffic-type ALL \
  --log-destination-type s3 --log-destination "arn:aws:s3:::${FLOWLOGS_BUCKET}"

aws ec2 describe-flow-logs --query 'FlowLogs[].[FlowLogId,LogDestinationType,FlowLogStatus,DeliverLogsStatus]' --output table

# A los ~10 minutos aparecen los primeros datos
aws logs tail "$LOG_GROUP" --since 15m | head
aws s3 ls "s3://${FLOWLOGS_BUCKET}/AWSLogs/" --recursive | head

# --------------------------------------------------------------------------
# TAREA 2 - Metric filter de REJECT y alarma a SNS
# --------------------------------------------------------------------------
aws logs put-metric-filter --log-group-name "$LOG_GROUP" --filter-name NetworkRejects \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]' \
  --metric-transformations metricName=NetworkRejects,metricNamespace=vpcflowlogs,metricValue=1,defaultValue=0

TOPIC_ARN=$(aws sns list-topics --query 'Topics[?ends_with(TopicArn,`:VpcAlarmTopic`)].TopicArn | [0]' --output text)

aws cloudwatch put-metric-alarm --alarm-name NetworkRejects \
  --alarm-description "Rejected traffic in MyVPC flow logs" \
  --namespace vpcflowlogs --metric-name NetworkRejects --statistic Sum \
  --period 300 --evaluation-periods 1 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN"

aws cloudwatch describe-alarms --alarm-names NetworkRejects \
  --query 'MetricAlarms[].[AlarmName,StateValue,AlarmActions[0]]' --output text

# Probar el patrón contra un registro de ejemplo antes de crearlo
aws logs test-metric-filter \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]' \
  --log-event-messages "2 123456789012 eni-0abc 10.0.1.146 162.159.200.1 41000 123 17 1 76 1700000000 1700000060 REJECT OK"

# --------------------------------------------------------------------------
# TAREA 3 - Tabla de Athena sobre los flow logs de S3
# --------------------------------------------------------------------------
# Función auxiliar: lanza una consulta, espera y muestra el resultado
athena() {
  local Q S
  Q=$(aws athena start-query-execution --work-group primary \
      --query-execution-context Database=default \
      --result-configuration "OutputLocation=s3://${ATHENA_BUCKET}/" \
      --query-string "$1" --query QueryExecutionId --output text) || return 1
  while S=$(aws athena get-query-execution --query-execution-id "$Q" --query QueryExecution.Status.State --output text); \
        [ "$S" = QUEUED ] || [ "$S" = RUNNING ]; do sleep 2; done
  echo "[$S]"
  if [ "$S" = SUCCEEDED ]; then
    aws athena get-query-results --query-execution-id "$Q" --output text --query 'ResultSet.Rows[].Data[].VarCharValue'
  else
    aws athena get-query-execution --query-execution-id "$Q" --query QueryExecution.Status.StateChangeReason --output text
  fi
}

# Crear la tabla (sustituyendo los marcadores del SQL)
athena "$(sed -e "s/FLOWLOGS_BUCKET/${FLOWLOGS_BUCKET}/g" -e "s/ACCOUNT_ID/${ACCOUNT_ID}/g" crear_tabla.sql)"

# Consultas de consultas.sql (cambiar la fecha por la del día)
athena "SELECT srcaddr, dstaddr, dstport, protocol, action FROM default.vpc_flow_logs WHERE date = '$(date +%Y/%m/%d)' LIMIT 10"
athena "SELECT action, count(*) AS total FROM default.vpc_flow_logs GROUP BY action"

# Opcional: dejar fijado el destino de resultados en el workgroup (lo pide una pista)
# aws athena update-work-group --work-group primary \
#   --configuration-updates "ResultConfigurationUpdates={OutputLocation=s3://${ATHENA_BUCKET}/}"

# Respuesta de la tarea: el nombre de la tabla -> vpc_flow_logs
