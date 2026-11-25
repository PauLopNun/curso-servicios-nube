-- Consultas de ejemplo sobre la tabla default.vpc_flow_logs
-- Filtrar siempre por la partición "date" (formato AAAA/MM/DD): Athena cobra por datos escaneados.

-- 1. Primeras filas del día
SELECT srcaddr, dstaddr, srcport, dstport, protocol, action, log_status
FROM vpc_flow_logs
WHERE date = '2026/11/25'
LIMIT 10;

-- 2. Recuento por acción (ACCEPT / REJECT / '-' para NODATA)
SELECT action, count(*) AS total
FROM vpc_flow_logs
GROUP BY action;

-- 3. Las 10 IP de origen con más tráfico rechazado
SELECT srcaddr, count(*) AS rechazos
FROM vpc_flow_logs
WHERE action = 'REJECT'
GROUP BY srcaddr
ORDER BY rechazos DESC
LIMIT 10;

-- 4. Puertos de destino más rechazados (posibles escaneos)
SELECT dstport, protocol, count(*) AS rechazos
FROM vpc_flow_logs
WHERE action = 'REJECT'
GROUP BY dstport, protocol
ORDER BY rechazos DESC
LIMIT 10;

-- 5. Tráfico por hora (start es un timestamp Unix en segundos)
SELECT date_trunc('hour', from_unixtime(start)) AS hora,
       sum(bytes) AS bytes, sum(packets) AS paquetes
FROM vpc_flow_logs
WHERE date = '2026/11/25'
GROUP BY 1
ORDER BY 1;

-- Protocolos: 6 = TCP, 17 = UDP, 1 = ICMP
