#!/usr/bin/env bash
# Parte 8: panel-pln en JSON (CPU por minuto, estado de las alarmas y StatusCheckFailed)
source "$(dirname "$0")/config.sh"; LOG=08-panel.txt; : > "$EVID/$LOG"
cat > "$EVID/panel-pln.json" <<JSON
{
  "widgets": [
    {"type": "metric", "x": 0, "y": 0, "width": 8, "height": 6,
     "properties": {"title": "CPUUtilization", "view": "timeSeries", "region": "us-east-1",
       "period": 60, "stat": "Average",
       "metrics": [["AWS/EC2", "CPUUtilization", "InstanceId", "$ID"]]}},
    {"type": "alarm", "x": 8, "y": 0, "width": 16, "height": 2,
     "properties": {"title": "Alarmas de mon-$OWNER", "alarms": [
       "arn:aws:cloudwatch:us-east-1:216772830502:alarm:mon-$OWNER-cpu",
       "arn:aws:cloudwatch:us-east-1:216772830502:alarm:mon-$OWNER-instancia",
       "arn:aws:cloudwatch:us-east-1:216772830502:alarm:mon-$OWNER-sistema"]}},
    {"type": "metric", "x": 8, "y": 2, "width": 6, "height": 4,
     "properties": {"title": "StatusCheckFailed", "view": "singleValue", "region": "us-east-1",
       "period": 300, "stat": "Maximum",
       "metrics": [["AWS/EC2", "StatusCheckFailed", "InstanceId", "$ID"]]}}
  ]
}
JSON
run 'aws cloudwatch put-dashboard --dashboard-name panel-$OWNER \
  --dashboard-body file://$EVID/panel-pln.json'
run 'aws cloudwatch list-dashboards --output table \
  --query "DashboardEntries[].{Panel:DashboardName,Bytes:Size}"'
