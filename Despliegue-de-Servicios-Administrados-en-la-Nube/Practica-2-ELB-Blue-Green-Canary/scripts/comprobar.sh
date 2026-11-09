#!/usr/bin/env bash
# Hace N peticiones a una URL y cuenta qué versión ha respondido
# Uso: ./comprobar.sh http://dns-del-balanceador [peticiones]
URL=$1; N=${2:-20}
for i in $(seq $N); do
  curl -s -m 5 --retry 2 -H 'Connection: close' "$URL" | grep -o 'Versión [a-z]*'
done | sort | uniq -c
