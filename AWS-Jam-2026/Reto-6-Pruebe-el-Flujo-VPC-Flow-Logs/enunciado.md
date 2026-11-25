# Enunciado - Reto 6: Pruebe el flujo (Probe The Flow)

Región: us-west-2.

Propiedades de salida: `MyVpcId`, `VPCFlowLogsBucketName`, `VPCFlowLogsLogGroupName`, `DeliverVPCFlowLogsRoleName` y `AthenaFlowLogsQueryBucketName`.

## Visión general

Te acabas de incorporar a SecureNow Pvt Ltd. como arquitecto de soluciones de seguridad. El equipo está estableciendo una línea base para la cuenta de AWS y ha detectado una carencia grave: no hay ningún mecanismo para monitorizar y analizar el tráfico de red de la VPC donde están todas las aplicaciones. Esto impide detectar y responder a un posible ataque de malware.

La oficina de servicios de TI (ITSO) te pide activar la monitorización del tráfico de entrada y salida de la VPC de aplicaciones con VPC Flow Logs, publicando los datos en Amazon CloudWatch y en Amazon S3, y usar después Amazon Athena para obtener información útil sobre el tráfico.

## Tarea 1 - Activar los flow logs (45 puntos)

La aplicación funciona en una instancia EC2 dentro de una VPC, y la empresa quiere monitorizar el tráfico de entrada y salida.

**Tarea:** activar los VPC Flow Logs de la VPC **MyVPC** para enviar los logs a un bucket de Amazon S3 y a un log group de Amazon CloudWatch.

Los flow logs capturan información sobre el tráfico IP de las interfaces de red de la VPC y pueden publicarse en CloudWatch Logs, S3 o Kinesis Data Firehose.

Inventario: la VPC MyVPC, el bucket S3 para los flow logs, el log group de CloudWatch y el rol IAM necesario para la entrega de logs.

**Validación:** automática, cuando los flow logs estén activados hacia S3 y hacia CloudWatch. Los logs tardan unos minutos en aparecer en los destinos.

## Tarea 2 - Filtrar los flow logs (53 puntos)

Los datos tardan unos minutos en publicarse en CloudWatch. Cuando estén disponibles, se pueden filtrar para encontrar el tráfico rechazado.

**Tarea:** crear un filtro de métrica y una alarma que avisen al equipo cada vez que la red recibe y rechaza peticiones. En el log group de los flow logs, crear el filtro y la alarma con estos nombres, para filtrar TODO el tráfico RECHAZADO:

- Metric Name: `NetworkRejects`
- Metric Namespace: `vpcflowlogs`
- Alarm Name: `NetworkRejects`

El destino de la alarma es el topic de Amazon SNS `VpcAlarmTopic`. Puede aparecer un aviso de falta de permisos en los endpoints de email al crear la alarma: se puede ignorar, porque no hace falta para el reto.

**Validación:** automática, cuando existan el filtro de métrica y la alarma de rechazos.

## Tarea 3 - Consultar los logs (52 puntos)

Los datos tardan unos minutos en publicarse en S3. Cuando estén disponibles, se pueden consultar con Amazon Athena.

**Tarea:** crear y ejecutar consultas sobre una tabla de la base de datos `default` de Athena que lea los datos de S3, para ver las peticiones de red. Los resultados de las consultas se guardan en el bucket *AthenaFlowLogsQueryBucket*.

**Validación:** escribir el nombre de la tabla de Athena (creada en la base de datos `default`) en la caja de respuesta y pulsar "Submit Answer".
