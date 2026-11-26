#!/bin/bash
# Quest 4 - Storage Security (CloudTrail, S3, versionado y AWS Backup)
# Las 5 tareas las resolvió el compañero (consola + AWS CLI). Aquí está el equivalente por CLI.

export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CREW=unicorn-crew-${ACCOUNT_ID}                 # bucket comprometido
SECURE=secure-unicorn-crew-${ACCOUNT_ID}        # bucket nuevo
STORIES=unicorn-stories-${ACCOUNT_ID}           # bucket borrado, está en AWS Backup

# --------------------------------------------------------------------------
# TAREA 1 - Investigación con CloudTrail
# --------------------------------------------------------------------------
aws cloudtrail describe-trails --query 'trailList[].[Name,S3BucketName,IsMultiRegionTrail]' --output text
#   unicorn-crew-trail -> unicorn-cloudtrail-<cuenta>   (el trail del reto; los otros dos son del evento)

# Eventos de datos de S3 sobre el bucket de la tripulación: quién borró y subió ficheros
aws s3 ls "s3://unicorn-cloudtrail-${ACCOUNT_ID}/AWSLogs/${ACCOUNT_ID}/CloudTrail/us-east-1/" --recursive | tail
aws s3 cp "s3://unicorn-cloudtrail-${ACCOUNT_ID}/AWSLogs/${ACCOUNT_ID}/CloudTrail/us-east-1/" ./trail --recursive
zcat trail/*/*/*/*.json.gz 2>/dev/null | jq -r '.Records[]
  | select(.eventSource=="s3.amazonaws.com" and (.eventName|test("PutObject|DeleteObject")))
  | [.eventTime,.eventName,.userIdentity.arn,.requestParameters.key] | @tsv' | sort | head -50
# -> los PutObject de chaos_file_* y los DeleteObject los hace una sesión de UnicornS3FullAccessRole

# El rol: quién lo puede asumir y qué permisos tiene
aws iam get-role --role-name UnicornS3FullAccessRole --query Role.AssumeRolePolicyDocument
aws iam list-role-policies --role-name UnicornS3FullAccessRole     # UnicornS3FullAccessPolicy (inline)

# Pregunta extra 2: ficheros "buenos" antes del ataque (versiones que no son chaos_file_*)
aws s3api list-object-versions --bucket "$CREW" \
  --query 'Versions[?!starts_with(Key,`chaos_`)].[Key,LastModified,IsLatest]' --output text
#   rental-fees.txt, trainer-details.txt, unicorn-details.txt  -> 3 ficheros

# --------------------------------------------------------------------------
# TAREA 2 - Blindar el bucket secure-
# --------------------------------------------------------------------------
# 1) Deny explícito al rol comprometido (gana a cualquier Allow de su política IAM)
sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" politica-bucket-secure.json > /tmp/politica.json
aws s3api put-bucket-policy --bucket "$SECURE" --policy file:///tmp/politica.json

# 2) Block Public Access con las 4 opciones
aws s3api put-public-access-block --bucket "$SECURE" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api get-bucket-policy --bucket "$SECURE" --query Policy --output text
aws s3api get-public-access-block --bucket "$SECURE"
# (Después, pulsar "Evaluate" en el GameDay)

# --------------------------------------------------------------------------
# TAREA 3 - Rainbow Recovery: los 3 ficheros legítimos al bucket seguro
# --------------------------------------------------------------------------
# Cada fichero legítimo tiene un delete marker como versión actual. Se copia la versión ANTERIOR
# (la buena) directamente al bucket seguro, sin tocar el comprometido y sin copiar nada de chaos_file_*.
for KEY in rental-fees.txt trainer-details.txt unicorn-details.txt; do
  VID=$(aws s3api list-object-versions --bucket "$CREW" --prefix "$KEY" \
    --query "Versions[?Key=='$KEY'] | sort_by(@,&LastModified)[0].VersionId" --output text)
  echo "$KEY -> $VID"
  aws s3api copy-object --bucket "$SECURE" --key "$KEY" --copy-source "${CREW}/${KEY}?versionId=${VID}"
done
aws s3 ls "s3://${SECURE}/"          # tienen que salir solo los 3 ficheros

# Preguntas extra 3 y 4: leer los ficheros recuperados
aws s3 cp "s3://${SECURE}/rental-fees.txt" -        # precio diario del Glitter Unicorn
aws s3 cp "s3://${SECURE}/trainer-details.txt" -    # entrenadores: buscar el "Atlas" de chaos_file_Atlas_*
aws s3 cp "s3://${SECURE}/unicorn-details.txt" -

# --------------------------------------------------------------------------
# TAREA 4 - Restaurar unicorn-stories desde AWS Backup (hecho desde la consola, 11:32)
# --------------------------------------------------------------------------
VAULT=unicorn-stories-backup-vault
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT" \
  --query 'RecoveryPoints[].[RecoveryPointArn,ResourceArn,CreationDate,Status]' --output text
RP_ARN=arn:aws:backup:us-east-1:${ACCOUNT_ID}:recovery-point:xxxx      # el más reciente
BACKUP_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName,`BackupRole`)].Arn | [0]' --output text)

# Metadatos que pide el restore de S3 (ver get-recovery-point-restore-metadata)
aws backup get-recovery-point-restore-metadata --backup-vault-name "$VAULT" --recovery-point-arn "$RP_ARN"

# Restaurar al bucket ORIGINAL (el rol solo tiene permisos sobre ese nombre)
aws backup start-restore-job --recovery-point-arn "$RP_ARN" --iam-role-arn "$BACKUP_ROLE" \
  --resource-type S3 \
  --metadata "DestinationBucketName=${STORIES},NewBucket=true,Encrypted=false,CreationToken=$(date +%s)"
aws backup list-restore-jobs --query 'RestoreJobs[].[RestoreJobId,Status,StatusMessage,PercentDone]' --output text
aws s3 ls "s3://${STORIES}/" --recursive

# --------------------------------------------------------------------------
# TAREA 5 - Eliminar el bucket comprometido (con Object Lock GOVERNANCE). En el GameDay se hizo desde la consola
# --------------------------------------------------------------------------
# ¡Solo DESPUÉS de la tarea 3! Al borrar el bucket se pierden las versiones buenas.
aws s3api get-object-lock-configuration --bucket "$CREW"

# 1) Objetos con retención: borrarlos uno a uno con bypass (requiere s3:BypassGovernanceRetention)
aws s3api list-object-versions --bucket "$CREW" --query 'Versions[].[Key,VersionId]' --output text |
while read -r KEY VID; do
  if aws s3api get-object-retention --bucket "$CREW" --key "$KEY" --version-id "$VID" >/dev/null 2>&1; then
    echo "Retención en $KEY ($VID)"
    aws s3api delete-object --bucket "$CREW" --key "$KEY" --version-id "$VID" --bypass-governance-retention
  fi
done
# (Con ~1.900 versiones este bucle tarda: si se sabe qué objeto está bloqueado, ir a por él directamente)

# 2) Resto de versiones y delete markers, por lotes de 1.000 (máximo de delete-objects)
for Q in Versions DeleteMarkers; do
  while :; do
    LOTE=$(aws s3api list-object-versions --bucket "$CREW" --max-items 1000 \
      --query "{Objects: ${Q}[].{Key:Key,VersionId:VersionId}}" --output json)
    [ "$(echo "$LOTE" | jq '.Objects | length')" -eq 0 ] && break
    aws s3api delete-objects --bucket "$CREW" --delete "$LOTE" --bypass-governance-retention >/dev/null
  done
done

# 3) Bucket vacío -> borrarlo
aws s3api delete-bucket --bucket "$CREW"
aws s3api head-bucket --bucket "$CREW"    # 404 Not Found = eliminado
