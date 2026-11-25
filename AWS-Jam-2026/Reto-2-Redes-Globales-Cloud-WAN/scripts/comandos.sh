#!/bin/bash
# Reto 2 - ¡Dijeron que la creación de redes globales es fácil! (AWS Cloud WAN)
# Comandos de investigación y solución de las 3 tareas.
# Cloud WAN es un servicio global: su API se usa en us-west-2.

export AWS_REGION=us-west-2

# --------------------------------------------------------------------------
# 0. Verificación en el CGW simulado (por Session Manager, SIN cambiar nada)
# --------------------------------------------------------------------------
#   sudo vtysh -c "sh ip route bgp"        # rutas aprendidas por BGP
#   sudo vtysh -c "sh ip bgp summary"      # estado de las sesiones BGP con AWS
#   sudo vtysh -c "sh ip bgp neighbors"    # detalle de los vecinos (169.254.x.x)

# --------------------------------------------------------------------------
# 1. Reconocimiento de la core network
# --------------------------------------------------------------------------
GN=$(aws networkmanager describe-global-networks --query 'GlobalNetworks[0].GlobalNetworkId' --output text)
CN=$(aws networkmanager list-core-networks --query 'CoreNetworks[0].CoreNetworkId' --output text)
echo "global=$GN core=$CN"

# Attachments: tipo, estado y segmento en el que han caído
aws networkmanager list-attachments --core-network-id "$CN" \
  --query 'Attachments[].[AttachmentId,AttachmentType,State,SegmentName,EdgeLocation,Tags]' --output json

# Política vigente (LIVE): segmentos, attachment-policies y segment-actions
aws networkmanager get-core-network-policy --core-network-id "$CN" --alias LIVE \
  --query 'CoreNetworkPolicy.PolicyDocument' --output text | python3 -m json.tool > politica-actual.json

# Rutas que ve cada segmento (sustituir el segmento y el edge location)
# aws networkmanager get-network-routes --global-network-id "$GN" \
#   --route-table-identifier "CoreNetworkSegmentEdge={CoreNetworkId=$CN,SegmentName=hybrid,EdgeLocation=us-west-2}"

# --------------------------------------------------------------------------
# 2. Tarea 1 - Si el attachment de la VPN está pendiente de aceptar
# --------------------------------------------------------------------------
# aws networkmanager accept-attachment --attachment-id <attachment-vpn>

# --------------------------------------------------------------------------
# 3. Tareas 1 y 2 - Editar la política (shares entre segmentos) y aplicarla
# --------------------------------------------------------------------------
# Editar politica-actual.json (ver core-network-policy-ejemplo.json) y subir una versión nueva
# aws networkmanager put-core-network-policy --core-network-id "$CN" \
#   --policy-document file://politica-nueva.json
# Ver el estado de la versión nueva (READY_TO_EXECUTE) y aplicarla
# aws networkmanager list-core-network-policy-versions --core-network-id "$CN"
# aws networkmanager execute-core-network-change-set --core-network-id "$CN" --policy-version-id <n>

# --------------------------------------------------------------------------
# 4. Tarea 3 - Integrar el Transit Gateway existente
# --------------------------------------------------------------------------
# TGW=tgw-xxxxxxxx; TGW_RT=tgw-rtb-xxxxxxxx
# Peering entre la core network y el TGW
# aws networkmanager create-transit-gateway-peering --core-network-id "$CN" \
#   --transit-gateway-arn arn:aws:ec2:us-west-2:<cuenta>:transit-gateway/$TGW
# Attachment de la tabla de rutas del TGW, con el tag que la manda al segmento nonprod
# aws networkmanager create-transit-gateway-route-table-attachment --peering-id <peering-id> \
#   --transit-gateway-route-table-arn arn:aws:ec2:us-west-2:<cuenta>:transit-gateway-route-table/$TGW_RT \
#   --tags Key=segment,Value=nonprod
# En el TGW (solo verificar): la VPC Non Prod tiene que estar propagada en esa tabla
# aws ec2 get-transit-gateway-route-table-propagations --transit-gateway-route-table-id "$TGW_RT"
