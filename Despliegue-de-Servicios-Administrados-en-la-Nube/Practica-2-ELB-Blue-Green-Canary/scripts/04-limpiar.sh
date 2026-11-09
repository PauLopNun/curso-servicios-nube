#!/usr/bin/env bash
# Borra todo lo creado en la práctica
set -uo pipefail
source "$(dirname "$0")/config.sh"
source "$ESTADO"
for LB in ${ALB:-} ${NLB:-}; do aws elbv2 delete-load-balancer --load-balancer-arn $LB; done
for LB in ${ALB:-} ${NLB:-}; do aws elbv2 wait load-balancers-deleted --load-balancer-arns $LB; done
for TG in ${TG_BLUE:-} ${TG_GREEN:-} ${TG_NLB:-}; do aws elbv2 delete-target-group --target-group-arn $TG; done
aws ec2 terminate-instances --instance-ids $ID_BLUE $ID_GREEN >/dev/null
aws ec2 wait instance-terminated --instance-ids $ID_BLUE $ID_GREEN
sleep 30 # las interfaces de red de los balanceadores tardan en liberarse
for SG in ${SG_ALB:-} ${SG_NLB:-} $SG_EC2; do aws ec2 delete-security-group --group-id $SG; done
echo "Recursos eliminados"
