#!/bin/bash
rm -rf /usr/share/nginx/html

#cp /opt/codedeploy/deploy/index.html /usr/share/nginx/index.html
mkdir -p /usr/share/nginx/html
cp /opt/codedeploy/deploy/index.html /usr/share/nginx/html/index.html
systemctl start nginx
nc -vz localhost 80  || { echo 'Port 80 not listening' ; exit 1; }
curl localhost | grep SecurityJamCodeDeployCompleted  || { echo 'Could not find text' ; exit 1; }
