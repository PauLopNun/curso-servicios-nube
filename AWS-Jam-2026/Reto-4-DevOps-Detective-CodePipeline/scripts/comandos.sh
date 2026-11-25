#!/bin/bash
# Reto 4 - DevOps Detective: La difícil situación del oleoducto (CodePipeline -> EC2)
# Comandos de investigación y solución propuesta. Este reto lo resolvió otro miembro
# del equipo: los cambios son la solución esperada, no se ejecutaron aquí.

export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PIPELINE=devops-detective-pipeline
SOURCE_BUCKET="devops-detective-jam-source-bucket-${ACCOUNT_ID}"

# --------------------------------------------------------------------------
# 0. Reconocimiento del pipeline
# --------------------------------------------------------------------------
aws codepipeline get-pipeline-state --name "$PIPELINE" \
  --query 'stageStates[].[stageName,latestExecution.status]' --output table

# Configuración de cada acción: Source (S3Bucket/S3ObjectKey) y Deploy (EC2)
aws codepipeline get-pipeline --name "$PIPELINE" \
  --query 'pipeline.stages[].actions[].[name,actionTypeId.provider,configuration]' --output json

# Último error de la etapa Deploy
aws codepipeline get-pipeline-state --name "$PIPELINE" \
  --query 'stageStates[?stageName==`Deploy`].actionStates[].latestExecution.errorDetails'

# Instancias del target group y sus tags (para comparar con InstanceTagKey/Value)
TG_ARN=$(aws elbv2 describe-target-groups --names jam-codepipeline-target-group --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output text
# aws ec2 describe-instances --instance-ids <i-...> <i-...> --query 'Reservations[].Instances[].Tags'

# --------------------------------------------------------------------------
# TAREA 1 - Añadir el target group del ALB a la acción de despliegue
# --------------------------------------------------------------------------
# Lo habitual es hacerlo en la consola: Edit -> stage Deploy -> acción EC2 ->
# "Target group" = jam-codepipeline-target-group, y al guardar marcar
# "No resource updates needed for this source action change".
#
# Por CLI: exportar, añadir "TargetGroupNameList": "jam-codepipeline-target-group"
# a la configuración de la acción Deploy, quitar "metadata" y actualizar.
aws codepipeline get-pipeline --name "$PIPELINE" > pipeline.json
#   (editar pipeline.json)
# python3 -c 'import json;d=json.load(open("pipeline.json"));d.pop("metadata",None);json.dump(d,open("pipeline-nuevo.json","w"),indent=2)'
# aws codepipeline update-pipeline --cli-input-json file://pipeline-nuevo.json

# --------------------------------------------------------------------------
# TAREA 2 - Empaquetar la web con deployspec.yml y los dos scripts
# --------------------------------------------------------------------------
mkdir -p paquete && cd paquete
# Ficheros web: descargarlos tal cual (no copiar y pegar, no tocarlos)
for f in index.html styles.css script.js; do
  curl -sfO "https://aws-jam-challenge-resources.s3.amazonaws.com/code-pipeline-ec2/$f"
done
cp ../deployspec.yml ../before_deploy.sh ../after_deploy.sh . && chmod +x *.sh

# Todo en la raíz del zip
rm -f source.zip && zip -q source.zip index.html styles.css script.js deployspec.yml before_deploy.sh after_deploy.sh
unzip -l source.zip

# Subirlo con la clave (S3ObjectKey) que espera la acción Source; eso dispara el pipeline
OBJECT_KEY=$(aws codepipeline get-pipeline --name "$PIPELINE" \
  --query 'pipeline.stages[0].actions[0].configuration.S3ObjectKey' --output text)
aws s3 cp source.zip "s3://${SOURCE_BUCKET}/${OBJECT_KEY}"

# Seguir la ejecución
aws codepipeline list-pipeline-executions --pipeline-name "$PIPELINE" --max-items 1 \
  --query 'pipelineExecutionSummaries[0].[pipelineExecutionId,status]'

# Respuesta de la tarea: el DNS del ALB
aws elbv2 describe-load-balancers --names devops-detective-lb --query 'LoadBalancers[0].DNSName' --output text
