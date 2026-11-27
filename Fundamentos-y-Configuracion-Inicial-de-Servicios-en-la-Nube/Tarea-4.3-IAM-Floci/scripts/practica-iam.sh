#!/usr/bin/env bash
# Tarea 4.3 - IAM con Floci: fases 0 a 4 de forma reproducible.
# Requiere Floci arrancado con FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true.
#
# Uso: ./practica-iam.sh [endpoint] [directorio-de-trabajo]
#   endpoint por defecto:  http://localhost:4567
#   directorio por defecto: ~/practica-iam-nightly
#
# Los perfiles se guardan en <directorio>/.aws para no tocar ~/.aws/credentials.
set -uo pipefail

SCRIPTS=$(cd "$(dirname "$0")" && pwd)
ENDPOINT=${1:-http://localhost:4567}
WORK=${2:-$HOME/practica-iam-nightly}
mkdir -p "$WORK/.aws" && cd "$WORK" || exit 1

export AWS_ENDPOINT_URL=$ENDPOINT AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
export AWS_SHARED_CREDENTIALS_FILE=$WORK/.aws/credentials AWS_CONFIG_FILE=$WORK/.aws/config
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

cp "$SCRIPTS"/politicas/*.json "$SCRIPTS/totp.py" .

# Muestra la orden como en la terminal y su salida
r() { echo "\$ $*"; eval "$@" 2>&1; echo; }
perfil() { aws configure set aws_access_key_id "$2" --profile "$1"
           aws configure set aws_secret_access_key "$3" --profile "$1"
           [ -n "${4:-}" ] && aws configure set aws_session_token "$4" --profile "$1"; }
claves() { aws iam create-access-key --user-name "$1" --profile "$2" \
             --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text; }
codigo() { python3 -I totp.py eva.seed; }

echo "## Fase 0 - Identificar a root"
perfil root test test
r aws sts get-caller-identity --profile root
r aws iam list-users --profile root

echo "## Fase 1 - Usuario administrador"
r aws iam create-group --group-name Admins --profile root --query Group.Arn
r aws iam attach-group-policy --group-name Admins --profile root \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
r aws iam create-user --user-name admin-lab --profile root --query User.Arn
r aws iam add-user-to-group --group-name Admins --user-name admin-lab --profile root
read -r AK SK < <(claves admin-lab root); perfil admin "$AK" "$SK"
r aws sts get-caller-identity --profile admin

echo "## Fase 2 - Recursos, políticas, grupos y usuarios"
echo "hola desde IAM" > hola.txt
r aws s3 mb s3://lab-datos --profile admin
r aws s3 cp hola.txt s3://lab-datos/hola.txt --profile admin
ID=$(aws ec2 run-instances --image-id ami-alpine --instance-type t2.micro --profile admin \
       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2-pln}]' \
       --query 'Instances[0].InstanceId' --output text)
echo "Instancia ec2-pln: $ID"; echo "$ID" > instance.id; echo

pol() { aws iam create-policy --policy-name "$1" --policy-document "file://$2" \
          --query Policy.Arn --output text --profile admin; }
S3_POL=$(pol S3-LabDatos-Lectura s3-lectura.json)
EC2_POL=$(pol EC2-Operacion ec2-operadores.json)
for g in S3-Lectura EC2-Operadores; do aws iam create-group --group-name $g --profile admin > /dev/null; done
aws iam attach-group-policy --group-name S3-Lectura --policy-arn "$S3_POL" --profile admin
aws iam attach-group-policy --group-name EC2-Operadores --policy-arn "$EC2_POL" --profile admin
for u in ana luis eva; do
  aws iam create-user --user-name $u --profile admin > /dev/null
  read -r AK SK < <(claves $u admin); perfil $u "$AK" "$SK"
done
aws iam add-user-to-group --group-name S3-Lectura --user-name ana --profile admin
aws iam add-user-to-group --group-name EC2-Operadores --user-name luis --profile admin
aws iam add-user-to-group --group-name S3-Lectura --user-name eva --profile admin
aws iam add-user-to-group --group-name EC2-Operadores --user-name eva --profile admin
r aws iam get-group --group-name S3-Lectura --profile admin --query 'Users[].UserName'
r aws iam get-group --group-name EC2-Operadores --profile admin --query 'Users[].UserName'

echo "## Fase 3 - Matriz de pruebas"
ACCIONES=(
  "s3-ls|aws s3 ls s3://lab-datos"
  "s3-descargar|aws s3 cp s3://lab-datos/hola.txt descarga.txt"
  "s3-subir|aws s3 cp hola.txt s3://lab-datos/subido.txt"
  "ec2-describe|aws ec2 describe-instances --query Reservations[].Instances[].InstanceId"
  "ec2-run|aws ec2 run-instances --image-id ami-alpine --instance-type t2.micro --query Instances[0].InstanceId --output text"
  "ec2-terminate|aws ec2 terminate-instances --instance-ids $ID"
  "iam-list-users|aws iam list-users --query Users[].UserName"
)
for u in ana luis eva; do
  for a in "${ACCIONES[@]}"; do
    rm -f descarga.txt
    if eval "${a#*|} --profile $u" > /dev/null 2>&1; then res=Si; else res=No; fi
    printf '%-5s %-15s %s\n' "$u" "${a%%|*}" "$res"
  done
done
echo

echo "## Fase 3.2 - Denegación explícita"
DENY_POL=$(pol S3-Sin-Descarga sin-descarga.json)
aws iam create-group --group-name Sin-Descarga --profile admin > /dev/null
aws iam attach-group-policy --group-name Sin-Descarga --policy-arn "$DENY_POL" --profile admin
r aws iam add-user-to-group --group-name Sin-Descarga --user-name eva --profile admin
r aws s3 cp s3://lab-datos/hola.txt descarga.txt --profile eva
r aws iam remove-user-from-group --group-name Sin-Descarga --user-name eva --profile admin
r aws s3 cp s3://lab-datos/hola.txt descarga.txt --profile eva

echo "## Fase 4 - MFA"
MFA_ARN=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name eva-mfa \
  --bootstrap-method Base32StringSeed --outfile eva.seed \
  --query VirtualMFADevice.SerialNumber --output text --profile admin)
echo "Dispositivo: $MFA_ARN"
C1=$(codigo); echo "Código 1: $C1"; sleep 31; C2=$(codigo); echo "Código 2: $C2"; echo
r aws iam enable-mfa-device --user-name eva --serial-number "$MFA_ARN" \
    --authentication-code1 "$C1" --authentication-code2 "$C2" --profile admin
MFA_POL=$(pol EC2-Requiere-MFA requiere-mfa.json)
r aws iam attach-group-policy --group-name EC2-Operadores --policy-arn "$MFA_POL" --profile admin

echo "## Fase 4.5 - Parar sin MFA"
r aws ec2 stop-instances --instance-ids "$ID" --profile eva

echo "## Fase 4.6 - Sesión temporal con MFA (esperando un intervalo TOTP nuevo)"
sleep 31
read -r AK SK TK < <(aws sts get-session-token --serial-number "$MFA_ARN" \
  --token-code "$(codigo)" --profile eva \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
perfil eva-mfa "$AK" "$SK" "$TK"
echo "Perfil eva-mfa con la clave temporal $AK"; echo

echo "## Fase 4.7 - Parar con MFA"
r aws ec2 stop-instances --instance-ids "$ID" --profile eva-mfa
