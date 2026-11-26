# Enunciado - Quest 4: Storage Security

Región: us-east-1.

## Bienvenida

Bienvenidos a Unicorn.Rentals, la startup legendaria de alquiler de animales que está revolucionando la economía colaborativa de criaturas mágicas. Una auditoría de seguridad reciente ha encontrado vulnerabilidades graves en la infraestructura de **Amazon S3**, donde están los activos más valiosos. Sois el equipo de Seguridad y Operaciones: hay que proteger el entorno S3, aplicar buenas prácticas y mantener los datos protegidos mientras la empresa crece.

## Tarea 1 - Neutralizar la amenaza interna

La semana pasada, en una verificación rutinaria de antecedentes de los entrenadores senior, el equipo de seguridad descubrió algo inquietante: uno de los entrenadores de confianza tiene un **pasado de ciberdelincuente** que ocultó al ser contratado. En el portátil de empresa del entrenador apareció una nota con fecha de hoy:

> "Hoy es el día. No lo verán venir. Los datos de la tripulación de unicornios serán míos y se quedarán en el caos. Acceso concedido, misión lista."

El tiempo apremia. Hay que **identificar el punto de acceso comprometido**. Trabajar en la región us-east-1.

**Validación:** automática (*Monitor tool check*).

## Pregunta extra 1

¿Qué bucket de CloudTrail se investigó para resolver el caso?

## Pregunta extra 2

¿Cuántos ficheros había en el bucket antes de que empezara el ataque?

## Tarea 2 - Seguridad a prueba de futuro

El CTO ha perdido la confianza en el bucket comprometido y quiere empezar de cero. Se ha creado un bucket nuevo con el prefijo **`secure-`** para guardar los datos de la tripulación de unicornios. Hay que blindarlo contra las amenazas que acabamos de ver.

Resultados mínimos de seguridad:

- **Dejar fuera la identidad comprometida:** el rol IAM identificado antes (**`UnicornS3FullAccessRole`**) no puede escribir ni modificar objetos en este bucket. Se puede hacer como se quiera: quitar al rol el acceso al bucket, poner una política del bucket con **Deny** o eliminar el rol.
- **Impedir la exposición pública:** que ni el bucket ni su contenido sean accesibles públicamente.

Cuando estén los dos, pulsar **Evaluate** y esperar hasta un minuto. La evaluación se repite cada minuto después de pulsar Evaluate, y **resta puntos cada minuto** hasta que se cumplen los dos resultados.

## Tarea 3 - Operación Rainbow Recovery

El entrenador borró ficheros críticos de la tripulación, pero gracias al **versionado de S3** no se han perdido. Hay que **restaurar los ficheros originales** del bucket comprometido y **migrarlos al bucket seguro**.

Hay que ser preciso: transferir **solo** los datos legítimos. Cada fichero de caos malicioso que llegue al bucket seguro resta puntos, y una recuperación perfecta (cero ficheros de caos) da un bonus.

La comprobación es automática cada minuto, sin botón ni penalización por esperar. La tarea se completa cuando los **tres ficheros legítimos** estén en el bucket seguro sin ningún fichero de caos.

## Pregunta extra 3

Los ficheros restaurados esconden información crítica de precios. ¿Cuál es el **precio diario de un Glitter Unicorn**?

## Pregunta extra 4

Todo criminal deja su firma. Los ficheros de caos inyectados en el bucket siguen un **patrón de nombres** que revela la identidad del atacante. Además, los ficheros de la tripulación restaurados (ya en el bucket seguro) contienen las asignaciones de entrenadores y los registros de personal que confirman la sospecha.

Las dos pistas siguen disponibles aunque se elimine el bucket comprometido: los nombres de los ficheros de caos y los ficheros restaurados del bucket seguro.

¿Cuál es el **nombre completo** del estafador?

## Tarea 4 - Restaurar las historias perdidas

La colección de historias de unicornios ha desaparecido de los archivos. Por suerte, el equipo de TI la protegió con **AWS Backup**: el bucket `unicorn-stories-<cuenta>` y todo su contenido están en el **backup vault**. Hay que **restaurar el bucket completo con su nombre original** y todos sus cuentos.

La duración del restore varía: de unos minutos a más de 10, según el tipo de backup. La comprobación es automática cada minuto.

Importante: el restore usa el rol IAM ya creado `gdQuests-...-BackupRole-...`. Sus permisos de S3 están limitados al bucket original de historias. Si se restaura con el mismo nombre, el rol ya tiene el acceso necesario. Si el restore falla por permisos (por ejemplo, porque AWS Backup apunta a otro destino), hay que revisar la política S3 del rol, incluir el ARN del bucket destino en `Resource` y reintentar.

## Tarea 5 - Eliminar el bucket contaminado

Hay que eliminar cualquier rastro del caos. El bucket original `unicorn-crew-<cuenta>` sigue contaminado por el ataque. Como medida final, hay que **eliminarlo de forma permanente**, para que no quede nada del vector de ataque.

Atención: el equipo de cumplimiento ha puesto una retención de **Object Lock en modo GOVERNANCE** en al menos un objeto del bucket. Un borrado normal se rechaza para los objetos bloqueados. Para eliminarlos hay que borrar con la excepción de gobernanza, por ejemplo `aws s3api delete-object --bucket <bucket> --key <key> --version-id <id> --bypass-governance-retention`, que exige el permiso `s3:BypassGovernanceRetention`. Solo entonces se puede vaciar y eliminar el bucket.

La comprobación es automática cada minuto. La tarea se completa cuando el bucket comprometido está eliminado del todo.
