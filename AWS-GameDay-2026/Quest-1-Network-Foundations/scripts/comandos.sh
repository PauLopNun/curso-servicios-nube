#!/bin/bash
# Quest 1 - Network Foundations (IPAM, CloudFormation y Transit Gateway)
# Comandos usados para resolver las 3 tareas. Ejecutar por bloques, no de golpe.
# Los IDs (ipam-..., vpc-..., subnet-..., rtb-..., tgw-...) son los del laboratorio:
# cada vez que se abre el reto son distintos. Sacarlos con los describe-... de cada bloque.

export AWS_REGION=us-east-1
aws sts get-caller-identity          # comprobar credenciales (rol WSParticipantRole/Participant)

# Esperas: los pools y los CIDR tardan unos segundos en estar listos
wait_pool() { until [ "$(aws ec2 describe-ipam-pools --ipam-pool-ids "$1" --query 'IpamPools[0].State' --output text)" = "create-complete" ]; do sleep 3; done; }
wait_cidr() { until [ "$(aws ec2 get-ipam-pool-cidrs --ipam-pool-id "$1" --query 'IpamPoolCidrs[0].State' --output text)" = "provisioned" ]; do sleep 3; done; }

# --------------------------------------------------------------------------
# TAREA 1 - IPAM y jerarquía de pools
# --------------------------------------------------------------------------
IPAM_ID=$(aws ec2 create-ipam --description "Unicorn.Rentals IPAM" \
  --operating-regions RegionName=us-east-1 \
  --tag-specifications 'ResourceType=ipam,Tags=[{Key=Name,Value=unicorn-ipam}]' \
  --query 'Ipam.IpamId' --output text)
until [ "$(aws ec2 describe-ipams --ipam-ids "$IPAM_ID" --query 'Ipams[0].State' --output text)" = "create-complete" ]; do sleep 3; done
SCOPE=$(aws ec2 describe-ipams --ipam-ids "$IPAM_ID" --query 'Ipams[0].PrivateDefaultScopeId' --output text)

# Pool top-level: 10.0.0.0/8, sin locale
TOP=$(aws ec2 create-ipam-pool --ipam-scope-id "$SCOPE" --address-family ipv4 --description top-level \
  --query 'IpamPool.IpamPoolId' --output text)
wait_pool "$TOP"; aws ec2 provision-ipam-pool-cidr --ipam-pool-id "$TOP" --cidr 10.0.0.0/8; wait_cidr "$TOP"

# Pool regional: 65.536 x 1,35 = 88.474 -> siguiente potencia de 2 = 131.072 = /15
REG=$(aws ec2 create-ipam-pool --ipam-scope-id "$SCOPE" --address-family ipv4 --locale us-east-1 \
  --source-ipam-pool-id "$TOP" --description us-east-1 --query 'IpamPool.IpamPoolId' --output text)
wait_pool "$REG"; aws ec2 provision-ipam-pool-cidr --ipam-pool-id "$REG" --cidr 10.0.0.0/15; wait_cidr "$REG"

# Pools de entorno. OJO: min-netmask-length = bloque MÁS GRANDE (máscara más corta)
#   producción / no producción: 512 IP = /23 (min), 128 IP = /25 (max), 256 IP = /24 (default)
#   servicios compartidos:      256 IP = /24 (min),  32 IP = /27 (max), 128 IP = /25 (default)
crear_pool() {  # nombre cidr min max default
  local id
  id=$(aws ec2 create-ipam-pool --ipam-scope-id "$SCOPE" --address-family ipv4 --locale us-east-1 \
    --source-ipam-pool-id "$REG" --description "$1" \
    --allocation-min-netmask-length "$3" --allocation-max-netmask-length "$4" --allocation-default-netmask-length "$5" \
    --tag-specifications "ResourceType=ipam-pool,Tags=[{Key=Name,Value=$1}]" \
    --query 'IpamPool.IpamPoolId' --output text)
  wait_pool "$id"; aws ec2 provision-ipam-pool-cidr --ipam-pool-id "$id" --cidr "$2" >/dev/null; wait_cidr "$id"
  echo "$1 = $id"
}
crear_pool production      10.0.0.0/19  23 25 24
crear_pool non-production  10.0.32.0/19 23 25 24
crear_pool shared-services 10.0.64.0/22 24 27 25

# Comprobación: jerarquía y reglas de asignación
aws ec2 describe-ipam-pools --query 'IpamPools[].{Name:Description,Id:IpamPoolId,Locale:Locale,Min:AllocationMinNetmaskLength,Max:AllocationMaxNetmaskLength,Def:AllocationDefaultNetmaskLength}' --output table
echo "Respuesta 1 (top-level): $TOP"
echo "Respuesta 2 (regional):  $REG"

# --------------------------------------------------------------------------
# TAREA 2 - Stack de CloudFormation con la red base
# --------------------------------------------------------------------------
# La URL de la plantilla sale del enlace "Create CloudFormation stack" del reto
# (el parámetro templateURL=... de la URL de la consola).
TEMPLATE_URL="https://ws-assets-prod-iad-r-iad-xxxx.s3.amazonaws.com/<id-del-evento>/GD-Participant-CFT.yml"

# Ver qué parámetros y capacidades pide antes de lanzarla
aws cloudformation get-template-summary --template-url "$TEMPLATE_URL" \
  --query '{Params:Parameters[].ParameterKey,Caps:Capabilities}'

PROD_POOL=ipam-pool-xxxx; NONPROD_POOL=ipam-pool-xxxx; SS_POOL=ipam-pool-xxxx
aws cloudformation create-stack --stack-name network-foundations --template-url "$TEMPLATE_URL" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=pProdIpamPoolID,ParameterValue=$PROD_POOL \
               ParameterKey=pNonProdIpamPoolID,ParameterValue=$NONPROD_POOL \
               ParameterKey=pSharedServicesPoolID,ParameterValue=$SS_POOL
aws cloudformation wait stack-create-complete --stack-name network-foundations
aws cloudformation describe-stack-resources --stack-name network-foundations \
  --query 'StackResources[].[ResourceType,LogicalResourceId,PhysicalResourceId]' --output text

# --------------------------------------------------------------------------
# TAREA 3 - Reconocimiento antes de tocar las rutas
# --------------------------------------------------------------------------
TGW=$(aws ec2 describe-transit-gateways --query 'TransitGateways[0].TransitGatewayId' --output text)
# DefaultRouteTableAssociation/Propagation = disable -> hay que crear las tablas del TGW a mano
aws ec2 describe-transit-gateways --transit-gateway-ids "$TGW" --query 'TransitGateways[0].Options'

# Subredes con nombre (TGW Subnet, Private, Public, FW) y tablas de rutas de las 3 VPC
aws ec2 describe-subnets --query 'Subnets[].[VpcId,SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`]|[0].Value]' --output text | sort
aws ec2 describe-route-tables --query 'RouteTables[].{Id:RouteTableId,Vpc:VpcId,Name:Tags[?Key==`Name`]|[0].Value,Main:Associations[?Main]|[0].Main,Subnets:Associations[].SubnetId}'
# En qué subred (AZ) está cada NAT
aws ec2 describe-nat-gateways --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output text

# Rellenar con lo que salga arriba
PROD_VPC=vpc-xxxx;   PROD_TGW_SUBNETS="subnet-a subnet-b"
DEV_VPC=vpc-xxxx;    DEV_TGW_SUBNETS="subnet-a subnet-b"
SS_VPC=vpc-xxxx;     SS_TGW_SUBNETS="subnet-a subnet-b"
PROD_MAIN_RT=rtb-xxxx; DEV_MAIN_RT=rtb-xxxx            # PROD y DEV solo usan su tabla principal
SS_PRIV_RT1=rtb-xxxx; SS_PRIV_RT2=rtb-xxxx
SS_TGW_RT1=rtb-xxxx;  SS_TGW_RT2=rtb-xxxx
SS_PUB_RT1=rtb-xxxx;  SS_PUB_RT2=rtb-xxxx
NAT1=nat-xxxx; NAT2=nat-xxxx                          # NAT1 en la AZ a, NAT2 en la AZ b
IGW=igw-xxxx

# --------------------------------------------------------------------------
# TAREA 3 - Attachments del TGW (en las subredes "TGW Subnet")
# --------------------------------------------------------------------------
att() {  # vpc subnets nombre opciones
  aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id "$TGW" --vpc-id "$1" --subnet-ids $2 \
    --options "$4" --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=$3}]" \
    --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' --output text
}
A_PROD=$(att "$PROD_VPC" "$PROD_TGW_SUBNETS" PROD-att DnsSupport=enable)
A_DEV=$(att "$DEV_VPC" "$DEV_TGW_SUBNETS" DEV-att DnsSupport=enable)
# Appliance mode en la VPC de inspección: necesario cuando se meta Network Firewall (simetría de flujos)
A_SS=$(att "$SS_VPC" "$SS_TGW_SUBNETS" SHARED-SERVICES-att DnsSupport=enable,ApplianceModeSupport=enable)
# Tardan 2-5 minutos en pasar de pending a available
aws ec2 describe-transit-gateway-vpc-attachments --transit-gateway-attachment-ids $A_PROD $A_DEV $A_SS \
  --query 'TransitGatewayVpcAttachments[].[TransitGatewayAttachmentId,State]' --output text

# --------------------------------------------------------------------------
# TAREA 3 - Tablas de rutas del TGW (spoke-rt y shared-rt)
# --------------------------------------------------------------------------
RT_SPOKE=$(aws ec2 create-transit-gateway-route-table --transit-gateway-id "$TGW" \
  --tag-specifications 'ResourceType=transit-gateway-route-table,Tags=[{Key=Name,Value=spoke-rt}]' \
  --query 'TransitGatewayRouteTable.TransitGatewayRouteTableId' --output text)
RT_SHARED=$(aws ec2 create-transit-gateway-route-table --transit-gateway-id "$TGW" \
  --tag-specifications 'ResourceType=transit-gateway-route-table,Tags=[{Key=Name,Value=shared-rt}]' \
  --query 'TransitGatewayRouteTable.TransitGatewayRouteTableId' --output text)

# Asociación: con qué tabla se decide el tráfico QUE ENTRA por cada attachment
aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id "$RT_SPOKE"  --transit-gateway-attachment-id "$A_PROD"
aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id "$RT_SPOKE"  --transit-gateway-attachment-id "$A_DEV"
aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id "$RT_SHARED" --transit-gateway-attachment-id "$A_SS"

# Propagación: qué CIDR de VPC aprende cada tabla
for a in $A_PROD $A_DEV $A_SS; do aws ec2 enable-transit-gateway-route-table-propagation --transit-gateway-route-table-id "$RT_SPOKE" --transit-gateway-attachment-id "$a"; done
for a in $A_PROD $A_DEV;       do aws ec2 enable-transit-gateway-route-table-propagation --transit-gateway-route-table-id "$RT_SHARED" --transit-gateway-attachment-id "$a"; done

# Salida a Internet de los spokes -> attachment de servicios compartidos
aws ec2 create-transit-gateway-route --transit-gateway-route-table-id "$RT_SPOKE" \
  --destination-cidr-block 0.0.0.0/0 --transit-gateway-attachment-id "$A_SS"

# --------------------------------------------------------------------------
# TAREA 3 - Rutas dentro de las VPC
# --------------------------------------------------------------------------
# Spokes: todo lo que no es local, al TGW
aws ec2 create-route --route-table-id "$PROD_MAIN_RT" --destination-cidr-block 0.0.0.0/0 --transit-gateway-id "$TGW"
aws ec2 create-route --route-table-id "$DEV_MAIN_RT"  --destination-cidr-block 0.0.0.0/0 --transit-gateway-id "$TGW"

# Servicios compartidos, subredes privadas: Internet por la NAT de su AZ, resto de la red por el TGW
aws ec2 create-route --route-table-id "$SS_PRIV_RT1" --destination-cidr-block 0.0.0.0/0  --nat-gateway-id "$NAT1"
aws ec2 create-route --route-table-id "$SS_PRIV_RT2" --destination-cidr-block 0.0.0.0/0  --nat-gateway-id "$NAT2"
aws ec2 create-route --route-table-id "$SS_PRIV_RT1" --destination-cidr-block 10.0.0.0/8 --transit-gateway-id "$TGW"
aws ec2 create-route --route-table-id "$SS_PRIV_RT2" --destination-cidr-block 10.0.0.0/8 --transit-gateway-id "$TGW"

# Servicios compartidos, subredes del TGW: lo que llega de los spokes hacia Internet va a la NAT de su AZ
# (cuando haya Network Firewall, este 0.0.0.0/0 apuntará al endpoint del firewall de la subred FW)
aws ec2 create-route --route-table-id "$SS_TGW_RT1" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"
aws ec2 create-route --route-table-id "$SS_TGW_RT2" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT2"

# Servicios compartidos, subredes públicas: Internet por el IGW y la VUELTA del NAT hacia los spokes por el TGW
aws ec2 create-route --route-table-id "$SS_PUB_RT1" --destination-cidr-block 0.0.0.0/0  --gateway-id "$IGW"
aws ec2 create-route --route-table-id "$SS_PUB_RT2" --destination-cidr-block 0.0.0.0/0  --gateway-id "$IGW"
aws ec2 create-route --route-table-id "$SS_PUB_RT1" --destination-cidr-block 10.0.0.0/8 --transit-gateway-id "$TGW"
aws ec2 create-route --route-table-id "$SS_PUB_RT2" --destination-cidr-block 10.0.0.0/8 --transit-gateway-id "$TGW"

# --------------------------------------------------------------------------
# Comprobación
# --------------------------------------------------------------------------
for rt in $RT_SPOKE $RT_SHARED; do
  echo "--- $rt"
  aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id "$rt" --filters Name=state,Values=active \
    --query 'Routes[].[DestinationCidrBlock,Type,TransitGatewayAttachments[0].TransitGatewayAttachmentId]' --output text
done
aws ec2 describe-transit-gateway-attachments --filters Name=transit-gateway-id,Values="$TGW" \
  --query 'TransitGatewayAttachments[].[ResourceId,State,Association.TransitGatewayRouteTableId,Association.State]' --output text
