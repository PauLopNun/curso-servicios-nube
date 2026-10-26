#!/usr/bin/env bash
# cambia_tipo_ec2.sh - Cambia el tipo de una instancia EC2
# Autor/a: Pau López Núñez (PLN)
# Fecha:    21/10/2026
# Uso:      cambia_tipo_ec2.sh [-y] ID_INSTANCIA TIPO_NUEVO
# Ampliación: comprueba que el tipo nuevo admite la arquitectura de la instancia

set -uo pipefail
export AWS_PAGER=""               # sin paginador: el script no se detiene

# Solo se modifican las instancias con esta etiqueta Propietario
PROPIETARIO="PLN"
I="Reservations[0].Instances[0]"
# Tamaños que el Learner Lab permite arrancar
TAMANOS_PERMITIDOS="nano micro small medium large"

error() {                                 # error MENSAJE CODIGO
  echo "ERROR: $1" >&2
  exit "$2"
}

uso() {
  echo "Uso: $(basename "$0") [-y] ID_INSTANCIA TIPO_NUEVO" >&2
  exit 1
}

# --- 1. Opciones y parámetros -------------------------------------------
CONFIRMAR=1
while getopts ":y" OPCION; do
  case $OPCION in
    y) CONFIRMAR=0 ;;
    *) uso ;;
  esac
done
shift $((OPTIND - 1))

[ $# -eq 2 ] || uso
ID=$1
TIPO_NUEVO=$2

# --- 2. La instancia existe (una sola llamada a describe-instances) ------
DATOS=$(aws ec2 describe-instances --instance-ids "$ID" --output text \
  --query "$I.[State.Name,InstanceType,Architecture,Tags[?Key=='Propietario'].Value | [0],Tags[?Key=='Name'].Value | [0]]" \
  2>/dev/null) \
  || error "La instancia $ID no existe o no es accesible" 2
IFS=$'\t' read -r ESTADO TIPO_ACTUAL ARQUITECTURA PROP NOMBRE <<< "$DATOS"

# --- 3. La instancia es mía ----------------------------------------------
[ "$PROP" = "$PROPIETARIO" ] \
  || error "La instancia $ID no tiene la etiqueta Propietario=$PROPIETARIO (tiene: $PROP)" 3

# --- 4. No está terminada ni terminándose --------------------------------
case $ESTADO in
  terminated|shutting-down)
    error "La instancia $ID está en estado $ESTADO" 4 ;;
esac

# --- 5. El tipo es distinto -----------------------------------------------
if [ "$TIPO_NUEVO" = "$TIPO_ACTUAL" ]; then
  echo "La instancia $ID ya es de tipo $TIPO_ACTUAL: no hay nada que hacer."
  exit 0
fi

# --- 6. El tipo existe y su tamaño está permitido -------------------------
TAMANO=${TIPO_NUEVO#*.}
[[ " $TAMANOS_PERMITIDOS " == *" $TAMANO "* ]] \
  || error "Tamaño '$TAMANO' no permitido en el Learner Lab ($TAMANOS_PERMITIDOS)" 5
ARQ_TIPO=$(aws ec2 describe-instance-types --instance-types "$TIPO_NUEVO" --output text \
  --query "InstanceTypes[0].ProcessorInfo.SupportedArchitectures" 2>/dev/null) \
  || error "El tipo $TIPO_NUEVO no existe" 5

# --- Ampliación: el tipo admite la arquitectura de la instancia -------------
# (un t4g es ARM: con una AMI x86_64 la instancia no arrancaría)
grep -qw -- "$ARQUITECTURA" <<< "$ARQ_TIPO" \
  || error "El tipo $TIPO_NUEVO es para $ARQ_TIPO y la instancia es $ARQUITECTURA" 5

# --- 7. Confirmación --------------------------------------------------------
echo "Instancia:   $ID ($NOMBRE)"
echo "Estado:      $ESTADO"
echo "Tipo actual: $TIPO_ACTUAL"
echo "Tipo nuevo:  $TIPO_NUEVO"
if [ "$CONFIRMAR" -eq 1 ]; then
  [ "$ESTADO" = "running" ] && echo "AVISO: la instancia se detendrá y volverá a arrancar."
  read -r -p "¿Continuar? (s/n): " RESPUESTA
  [ "$RESPUESTA" = "s" ] || error "Cancelado por el usuario" 6
fi

# --- Cambio de tipo ---------------------------------------------------------
if [ "$ESTADO" = "running" ]; then
  echo "Deteniendo la instancia..."
  aws ec2 stop-instances --instance-ids "$ID" >/dev/null \
    || error "No se ha podido detener la instancia" 7
fi
# Si estaba deteniéndose o se acaba de detener, esperamos a que pare del todo
if [ "$ESTADO" = "running" ] || [ "$ESTADO" = "stopping" ]; then
  aws ec2 wait instance-stopped --instance-ids "$ID" \
    || error "La instancia no ha llegado a detenerse" 7
fi

echo "Cambiando el tipo a $TIPO_NUEVO..."
aws ec2 modify-instance-attribute --instance-id "$ID" \
  --instance-type "Value=$TIPO_NUEVO" \
  || error "No se ha podido cambiar el tipo" 7

if [ "$ESTADO" = "running" ]; then
  echo "Arrancando la instancia..."
  aws ec2 start-instances --instance-ids "$ID" >/dev/null \
    || error "No se ha podido arrancar la instancia" 7
  aws ec2 wait instance-running --instance-ids "$ID" \
    || error "La instancia no ha llegado a arrancar" 7
fi

# --- Comprobación final en AWS ----------------------------------------------
FINAL=$(aws ec2 describe-instances --instance-ids "$ID" --output text \
  --query "$I.[InstanceType,State.Name]") \
  || error "No se ha podido consultar el estado final" 7
read -r TIPO_FINAL ESTADO_FINAL <<< "$FINAL"
echo "Resultado:   tipo $TIPO_FINAL, estado $ESTADO_FINAL"
[ "$TIPO_FINAL" = "$TIPO_NUEVO" ] || error "El tipo final no coincide con el pedido" 7
echo "Tiempo total: ${SECONDS} s"
