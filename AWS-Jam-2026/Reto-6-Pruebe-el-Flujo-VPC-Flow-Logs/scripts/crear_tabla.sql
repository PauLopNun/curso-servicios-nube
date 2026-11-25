CREATE EXTERNAL TABLE IF NOT EXISTS default.vpc_flow_logs (
  version int,
  account_id string,
  interface_id string,
  srcaddr string,
  dstaddr string,
  srcport int,
  dstport int,
  protocol bigint,
  packets bigint,
  bytes bigint,
  start bigint,
  `end` bigint,
  action string,
  log_status string
)
PARTITIONED BY (`date` string)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ' '
LOCATION 's3://FLOWLOGS_BUCKET/AWSLogs/ACCOUNT_ID/vpcflowlogs/us-west-2/'
TBLPROPERTIES (
  'skip.header.line.count' = '1',
  'projection.enabled' = 'true',
  'projection.date.type' = 'date',
  'projection.date.format' = 'yyyy/MM/dd',
  'projection.date.range' = '2026/11/01,NOW',
  'projection.date.interval' = '1',
  'projection.date.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://FLOWLOGS_BUCKET/AWSLogs/ACCOUNT_ID/vpcflowlogs/us-west-2/${date}'
)
