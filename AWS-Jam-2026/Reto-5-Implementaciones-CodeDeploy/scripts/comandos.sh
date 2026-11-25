#!/bin/bash
# Reto 5 - Implementaciones en desarrollo (CodeDeploy con Auto Scaling)
# Comandos usados para resolver las 3 tareas. Ejecutar por bloques, no de golpe.

export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="jam-codedeploy-${ACCOUNT_ID}-us-east-1"   # S3Bucket en Propiedades de salida
ASG=ASG-CD-Jam                                   # AutoScalingGroupName

# --------------------------------------------------------------------------
# TAREA 1 - Preparar source.zip con un appspec.yml válido
# --------------------------------------------------------------------------
# source.zip se descarga desde el enlace de la tarea. Se trabaja en una carpeta vacía.
mkdir -p trabajo && cd trabajo && unzip -o ../source.zip

# appspec.yml correcto (el de esta carpeta) y se quita el FIXME: solo vale el nombre por defecto
cp ../appspec.yml . && rm -f appspec_FIXME.yml

# Opcional: poner el día en la web SIN tocar el texto SecurityJamCodeDeployCompleted
sed -i 's/UPDATE-ME/Today is Wednesday/' deploy/index.html
chmod +x deploy/*.sh

# appspec.yml en la RAÍZ del zip, junto a la carpeta deploy/
rm -f ../source-nuevo.zip && zip -qr ../source-nuevo.zip appspec.yml deploy && cd ..
unzip -l source-nuevo.zip
aws s3 cp source-nuevo.zip "s3://${BUCKET}/source.zip"

# --------------------------------------------------------------------------
# TAREA 2 - Aplicación y grupo de despliegue
# --------------------------------------------------------------------------
# El rol NO se llama "Jam-CodeDeploy" a secas: buscar el nombre real
ROLE_ARN=$(aws iam list-roles --query 'Roles[?starts_with(RoleName,`Jam-CodeDeploy`)].Arn | [0]' --output text)
echo "$ROLE_ARN"

aws deploy create-application --application-name jam-app --compute-platform Server

aws deploy create-deployment-group --application-name jam-app --deployment-group-name jam \
  --service-role-arn "$ROLE_ARN" --auto-scaling-groups "$ASG" \
  --deployment-config-name CodeDeployDefault.OneAtATime \
  --deployment-style deploymentType=IN_PLACE,deploymentOption=WITHOUT_TRAFFIC_CONTROL \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE

aws deploy get-deployment-group --application-name jam-app --deployment-group-name jam \
  --query 'deploymentGroupInfo.[deploymentConfigName,deploymentStyle,autoRollbackConfiguration,autoScalingGroups[].name]'

# Ver el lifecycle hook que CodeDeploy añade al ASG
aws autoscaling describe-lifecycle-hooks --auto-scaling-group-name "$ASG"

# --------------------------------------------------------------------------
# TAREA 3 - Lanzar el despliegue sobrescribiendo los ficheros
# --------------------------------------------------------------------------
D=$(aws deploy create-deployment --application-name jam-app --deployment-group-name jam \
  --s3-location bucket="$BUCKET",key=source.zip,bundleType=zip \
  --file-exists-behavior OVERWRITE --description "Deploy source.zip" \
  --query deploymentId --output text)
echo "$D"

aws deploy wait deployment-successful --deployment-id "$D"
aws deploy get-deployment --deployment-id "$D" --query 'deploymentInfo.[status,deploymentOverview,errorInformation]'

# Si falla: en qué instancia y en qué hook
# aws deploy list-deployment-instances --deployment-id "$D"
# aws deploy get-deployment-instance --deployment-id "$D" --instance-id <i-...> \
#   --query 'instanceSummary.lifecycleEvents[].[lifecycleEventName,status,diagnostics.message]'

# URL de la web (Parameter Store) y comprobación del texto
URL=$(aws ssm get-parameter --name /sj/codedeploy/dns --query Parameter.Value --output text)
curl -s "$URL" | grep -E 'SecurityJamCodeDeployCompleted|Today'
