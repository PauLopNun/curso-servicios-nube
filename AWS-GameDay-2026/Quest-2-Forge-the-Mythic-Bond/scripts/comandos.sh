#!/bin/bash
# Quest 2 - Forge the Mythic Bond (PrivateLink con CIDR solapados y WAF contra SQLi)
# Comandos usados para resolver las 2 tareas. Ejecutar por bloques, no de golpe.

export AWS_REGION=us-east-1

# --------------------------------------------------------------------------
# 0. Reconocimiento: VPC solapadas, ALB de Mystique y EC2 de AwesomeUnicorn
# --------------------------------------------------------------------------
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]' --output text
#   Prod-VPC1-Region1    10.0.0.0/23
#   MystiqueRentalsVPC   10.0.0.0/23   <- mismo CIDR: peering y TGW descartados

aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,Type,Scheme,VpcId,DNSName]' --output text
aws elbv2 describe-load-balancers --names MystiqueWebALB \
  --query 'LoadBalancers[0].{AZ:AvailabilityZones[].[ZoneName,SubnetId],SG:SecurityGroups}'
# El SG del ALB ya permite 80/443 desde 10.0.0.0/23 (las IPs del NLB que se crea en su VPC entran ahí)
aws ec2 describe-security-groups --group-ids sg-xxxx --query 'SecurityGroups[].IpPermissions'

aws ec2 describe-instances --filters Name=tag:Name,Values=AwesomeUnicorn_WebApp \
  --query 'Reservations[].Instances[].[InstanceId,SubnetId,PrivateIpAddress]' --output text

MYS_VPC=vpc-xxxx                                       # MystiqueRentalsVPC
MYS_PRIV_SUBNETS="subnet-a subnet-b subnet-c"          # las privadas donde está el ALB (1a, 1b, 1c)
PROD_VPC=vpc-xxxx                                      # Prod-VPC1-Region1
PROD_PRIV_SUBNETS="subnet-a subnet-b"                  # Prod Private Subnet 1 y 2
AWESOME_ID=i-xxxx                                      # AwesomeUnicorn_WebApp

# --------------------------------------------------------------------------
# TAREA 1 - Proveedor: NLB interno delante del ALB + endpoint service
# --------------------------------------------------------------------------
ALB_ARN=$(aws elbv2 describe-load-balancers --names MystiqueWebALB --query 'LoadBalancers[0].LoadBalancerArn' --output text)

NLB_ARN=$(aws elbv2 create-load-balancer --name MystiqueAI-NLB --type network --scheme internal \
  --subnets $MYS_PRIV_SUBNETS --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Target group de tipo "alb": el NLB reenvía al ALB existente (no se toca el ALB)
TG_ARN=$(aws elbv2 create-target-group --name MystiqueAI-ALB-TG --target-type alb --protocol TCP --port 80 \
  --vpc-id "$MYS_VPC" --health-check-protocol HTTP --health-check-path / \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn "$TG_ARN" --targets "Id=$ALB_ARN,Port=80"
aws elbv2 create-listener --load-balancer-arn "$NLB_ARN" --protocol TCP --port 80 \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN"
aws elbv2 wait load-balancer-available --load-balancer-arns "$NLB_ARN"

# Endpoint service (PrivateLink) sobre el NLB, sin aceptación manual
SVC=$(aws ec2 create-vpc-endpoint-service-configuration --network-load-balancer-arns "$NLB_ARN" \
  --no-acceptance-required --query 'ServiceConfiguration.ServiceName' --output text)
echo "$SVC"      # com.amazonaws.vpce.us-east-1.vpce-svc-xxxx

# --------------------------------------------------------------------------
# TAREA 1 - Consumidor: interface endpoint en la VPC de Producción
# --------------------------------------------------------------------------
SG=$(aws ec2 create-security-group --group-name MystiqueAI-endpoint-sg \
  --description "Allow HTTP from Prod to MystiqueAI endpoint" --vpc-id "$PROD_VPC" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr 10.0.0.0/23

VPCE=$(aws ec2 create-vpc-endpoint --vpc-endpoint-type Interface --vpc-id "$PROD_VPC" --service-name "$SVC" \
  --subnet-ids $PROD_PRIV_SUBNETS --security-group-ids "$SG" --query 'VpcEndpoint.VpcEndpointId' --output text)
# Si da "Unavailable" (error temporal de la API), repetir a los pocos segundos
until [ "$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$VPCE" --query 'VpcEndpoints[0].State' --output text)" = "available" ]; do sleep 10; done

# Nombre DNS regional del endpoint = la respuesta del reto (con http:// delante y :80 detrás)
DNS=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$VPCE" --query 'VpcEndpoints[0].DnsEntries[0].DnsName' --output text)
echo "http://$DNS:80"

# --------------------------------------------------------------------------
# TAREA 1 - Comprobación desde AwesomeUnicorn (Run Command de SSM)
# --------------------------------------------------------------------------
# Esperar a que el target (el ALB) esté healthy: antes, el curl da timeout
until [ "$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)" = "healthy" ]; do sleep 10; done

CMD=$(aws ssm send-command --instance-ids "$AWESOME_ID" --document-name AWS-RunShellScript \
  --parameters "commands=[\"curl -s -m 10 -o /tmp/o.html -w '%{http_code}\\\\n' http://$DNS:80; head -c 400 /tmp/o.html\"]" \
  --query Command.CommandId --output text)
sleep 10
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$AWESOME_ID" \
  --query '[Status,StandardOutputContent]' --output text
# 200 + <h1>Hellow World from Mystique.Rentals</h1>

# --------------------------------------------------------------------------
# TAREA 2 - WAF con la regla gestionada de SQLi, asociado al ALB de Mystique
# --------------------------------------------------------------------------
WEBACL_ARN=$(aws wafv2 create-web-acl --scope REGIONAL --name MystiqueAI-WebACL --default-action 'Allow={}' \
  --rules file://waf-rules.json \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=MystiqueAI-WebACL \
  --query Summary.ARN --output text)

# Justo después de crearlo puede dar WAFUnavailableEntityException: reintentar a los 10 s
until aws wafv2 associate-web-acl --web-acl-arn "$WEBACL_ARN" --resource-arn "$ALB_ARN"; do sleep 10; done
aws wafv2 get-web-acl-for-resource --resource-arn "$ALB_ARN" --query 'WebACL.[Name,Rules[].Name]' --output text

# Comprobación: normal = 200, inyección SQL = 403
CMD=$(aws ssm send-command --instance-ids "$AWESOME_ID" --document-name AWS-RunShellScript \
  --parameters "commands=[\"curl -s -o /dev/null -w 'normal %{http_code}\\\\n' 'http://$DNS:80/'\",\"curl -s -o /dev/null -w 'sqli %{http_code}\\\\n' 'http://$DNS:80/?id=1%27%20OR%20%271%27%3D%271'\"]" \
  --query Command.CommandId --output text)
sleep 15
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$AWESOME_ID" --query StandardOutputContent --output text
