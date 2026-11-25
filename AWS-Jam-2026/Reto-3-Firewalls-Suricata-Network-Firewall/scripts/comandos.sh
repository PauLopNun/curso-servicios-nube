#!/bin/bash
# Reto 3 - De Suricata en EC2 a AWS Network Firewall
# Comandos usados para resolver las 4 tareas. Ejecutar por bloques, no de golpe.
# Los identificadores (vpc-, rtb-, vpce-, i-) cambian en cada laboratorio: se sacan del paso 0.

export AWS_REGION=us-east-1

# --------------------------------------------------------------------------
# 0. Reconocimiento: dibujar la red antes de tocar nada
# --------------------------------------------------------------------------
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,PrivateIpAddress,VpcId,SourceDestCheck]' --output table
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]' --output table
aws ec2 describe-subnets --query 'Subnets[].[SubnetId,VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]' --output table
aws ec2 describe-route-tables \
  --query 'RouteTables[].{tabla:Tags[?Key==`Name`]|[0].Value,subred:Associations[0].SubnetId,rutas:Routes[].[DestinationCidrBlock,GatewayId||NatGatewayId||TransitGatewayId||VpcEndpointId]}'
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].[VpcEndpointId,VpcEndpointType,VpcId,SubnetIds[0],ServiceName]' --output table

# Tablas del Transit Gateway (qué VPC están conectadas y a dónde va 0.0.0.0/0)
for rt in $(aws ec2 describe-transit-gateway-route-tables --query 'TransitGatewayRouteTables[].TransitGatewayRouteTableId' --output text); do
  aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id "$rt" \
    --filters Name=state,Values=active,blackhole \
    --query 'Routes[].[DestinationCidrBlock,Type,TransitGatewayAttachments[0].ResourceId]' --output table
done

# El Gateway Load Balancer de Suricata, su target group y su endpoint service
aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,Type,VpcId]' --output table
aws elbv2 describe-target-groups --query 'TargetGroups[].[TargetGroupName,Protocol,Port,TargetGroupArn]' --output table
aws ec2 describe-vpc-endpoint-service-configurations --query 'ServiceConfigurations[].[ServiceName,AcceptanceRequired]' --output table

# --------------------------------------------------------------------------
# TAREA 1 - Hacer pasar el tráfico por Suricata (GWLB endpoint + rutas)
# --------------------------------------------------------------------------
PERIM_VPC=vpc-xxxxxxxx                 # Perimeter-VPC
PERIM_PRIV_FW_SUBNET=subnet-xxxxxxxx   # Perim-Priv-FW
RT_PERIM_PRIV_TGW=rtb-xxxxxxxx         # Perim-Priv-TGW-RT
RT_PERIM_PUB=rtb-xxxxxxxx              # Perim-Pub-RT
SURICATA_SVC=com.amazonaws.vpce.us-east-1.vpce-svc-xxxxxxxx   # endpoint service del GWLB de Suricata
CLOUD1_CIDR=10.0.1.0/24

# 1.1 GWLB endpoint del servicio de Suricata en Perimeter-VPC
SURI_VPCE=$(aws ec2 create-vpc-endpoint --vpc-endpoint-type GatewayLoadBalancer --vpc-id "$PERIM_VPC" \
  --service-name "$SURICATA_SVC" --subnet-ids "$PERIM_PRIV_FW_SUBNET" \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=Perim-Suricata-GWLBe}]' \
  --query VpcEndpoint.VpcEndpointId --output text)
aws ec2 wait vpc-endpoint-available --vpc-endpoint-ids "$SURI_VPCE" 2>/dev/null || \
  aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$SURI_VPCE" --query 'VpcEndpoints[0].State'

# 1.2 Ida: lo que llega del TGW sale por el endpoint (Suricata)
aws ec2 create-route --route-table-id "$RT_PERIM_PRIV_TGW" --destination-cidr-block 0.0.0.0/0 --vpc-endpoint-id "$SURI_VPCE"
# 1.3 Vuelta: lo que vuelve del NAT hacia Cloud1 también pasa por Suricata (simetría)
aws ec2 create-route --route-table-id "$RT_PERIM_PUB" --destination-cidr-block "$CLOUD1_CIDR" --vpc-endpoint-id "$SURI_VPCE"

# 1.4 Probar desde la web (Session Manager en la consola o con el script)
WEB=i-xxxxxxxx         # Cloud1-WebServer
SURICATA=i-xxxxxxxx    # suricata-instance
./ssm-ejecutar.sh "$WEB" "ping -c 4 8.8.8.8"
./ssm-ejecutar.sh "$SURICATA" "sudo tail -n 5 /var/log/suricata/fast.log"   # deben salir alertas ICMP

# --------------------------------------------------------------------------
# TAREA 2 - Cambiar la regla de Suricata de alert a drop
# --------------------------------------------------------------------------
./ssm-ejecutar.sh "$SURICATA" "sudo sed -i 's/^alert  *http any any -> any any (msg:\"amazon.com is blocked\"/drop http any any -> any any (msg:\"amazon.com is blocked\"/' /var/lib/suricata/rules/suricata.rules && sudo cat /var/lib/suricata/rules/suricata.rules"

# Reiniciar Suricata. OJO: con restart puede quedarse parado aunque systemctl diga "active".
# Arranque seguro: parar, borrar el pid y lanzarlo a mano en modo IPS (NFQUEUE 0).
./ssm-ejecutar.sh "$SURICATA" "sudo systemctl stop suricata; sudo rm -f /var/run/suricata.pid; \
  sudo /usr/bin/suricata -c /etc/suricata/suricata.yaml --pidfile /var/run/suricata.pid -q 0 -D; sleep 20; \
  pgrep -a Suricata; sudo grep -E 'rules successfully loaded|engine started' /var/log/suricata/suricata.log | tail -2" 120

# Pruebas: amazon.com bloqueado, www.amazon.com y HTTPS permitidos
./ssm-ejecutar.sh "$WEB" "for u in http://amazon.com http://www.amazon.com https://amazon.com; do echo \"\$u -> \$(curl -s -m 8 -o /dev/null -w '%{http_code}' \$u || echo BLOQUEADO)\"; done"
./ssm-ejecutar.sh "$SURICATA" "sudo tail -n 3 /var/log/suricata/fast.log"   # debe salir [Drop]

# --------------------------------------------------------------------------
# TAREA 3 - Mover el tráfico a AWS Network Firewall
# --------------------------------------------------------------------------
NFW_VPCE=vpce-xxxxxxxx   # endpoint con el tag AWSNetworkFirewallManaged=true

aws network-firewall describe-firewall --firewall-name Inspection-NFW \
  --query '{estado:FirewallStatus.Status,endpoints:FirewallStatus.SyncStates}'

# 3.1 Cambiar las dos rutas del endpoint de Suricata al del firewall
aws ec2 replace-route --route-table-id "$RT_PERIM_PRIV_TGW" --destination-cidr-block 0.0.0.0/0 --vpc-endpoint-id "$NFW_VPCE"
aws ec2 replace-route --route-table-id "$RT_PERIM_PUB" --destination-cidr-block "$CLOUD1_CIDR" --vpc-endpoint-id "$NFW_VPCE"

# 3.2 Revisar la política: tenía un grupo "Block-All" con DROP de todo
aws network-firewall describe-firewall-policy --firewall-policy-name Inspection-NFW-Policy --query FirewallPolicy
aws network-firewall describe-rule-group --rule-group-name Inspection-Block-All-Rule-Group --type STATEFUL --query RuleGroup

# 3.3 Cambiarlo a PASS (IP + ICMP). Toda modificación necesita el UpdateToken actual.
T=$(aws network-firewall describe-rule-group --rule-group-name Inspection-Block-All-Rule-Group --type STATEFUL --query UpdateToken --output text)
aws network-firewall update-rule-group --rule-group-name Inspection-Block-All-Rule-Group --type STATEFUL \
  --update-token "$T" --rule-group file://rg-pass.json

# 3.4 Esperar a que el endpoint tenga la configuración nueva (IN_SYNC) y probar
aws network-firewall describe-firewall --firewall-name Inspection-NFW --query 'FirewallStatus.SyncStates.*.Config'
./ssm-ejecutar.sh "$WEB" "ping -c 4 8.8.8.8 | tail -2; curl -s -m 8 -o /dev/null -w 'https %{http_code}\n' https://aws.amazon.com"

# --------------------------------------------------------------------------
# TAREA 4 - Migrar la regla de Suricata a un grupo de reglas de Network Firewall
# --------------------------------------------------------------------------

# 4.1 Grupo stateful nuevo a partir de un fichero de reglas en formato Suricata
RG_ARN=$(aws network-firewall create-rule-group --rule-group-name Inspection-Suricata-IPS-Rule-Group \
  --type STATEFUL --capacity 100 --description "Migrated Suricata rule - drop HTTP to amazon.com" \
  --rules file://amazon.rules --query RuleGroupResponse.RuleGroupArn --output text)

# 4.2 Política con SOLO el grupo nuevo (se quita Block-All: su PASS ganaría al DROP)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" policy.json > policy-cuenta.json
T=$(aws network-firewall describe-firewall-policy --firewall-policy-name Inspection-NFW-Policy --query UpdateToken --output text)
aws network-firewall update-firewall-policy --firewall-policy-name Inspection-NFW-Policy \
  --update-token "$T" --firewall-policy file://policy-cuenta.json

# 4.3 Esperar IN_SYNC y probar: amazon.com bloqueado, el resto permitido
aws network-firewall describe-firewall --firewall-name Inspection-NFW --query 'FirewallStatus.SyncStates.*.Config'
./ssm-ejecutar.sh "$WEB" "for u in http://amazon.com http://www.amazon.com https://amazon.com; do echo \"\$u -> \$(curl -s -m 8 -o /dev/null -w '%{http_code}' \$u || echo BLOQUEADO)\"; done; ping -c 2 8.8.8.8 | tail -1"
