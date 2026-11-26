# Enunciado - Quest 3: Operational Readiness

Región: us-east-1.

## Introducción

Bienvenido a Unicorn.Rentals, donde los momentos mágicos se encuentran con la tecnología moderna. El éxito depende del sistema de inventario, que encuentra para cada cliente su unicornio perfecto. Pero en el ajetreado mundo del alquiler de criaturas míticas surgen problemas.

En cinco retos se practican técnicas de alta disponibilidad, despliegues bajo presión y buenas prácticas para que la experiencia del cliente siga siendo mágica:

1. Detectar antipatrones.
2. Gestionar caídas de sistemas heredados (*legacy*).
3. Detectar el latido (*heartbeat*) de la aplicación.
4. Evaluar de forma continua la resiliencia de la aplicación.
5. Monitorizar el uso de memoria del servidor heredado.

## Reto 1 - Detectar antipatrones

Durante las pruebas de carga, el equipo ve que los tiempos de respuesta suben poco a poco hasta que el sistema deja de estar disponible. Han descubierto que un servicio heredado a veces tarda **10-12 minutos** en responder. Según el diagrama, la petición a la API la atiende una **función Lambda que orquesta** las llamadas de detalle del artículo, precio y disponibilidad. La Lambda orquestadora se queda **esperando** y no procesa ninguna otra petición.

**Validación:** automática (*Detection of anti-pattern check*).

## Reto 2 - Gestionar caídas de sistemas heredados

Después de que el equipo de operaciones despliega la **Step Function** que orquesta los servicios de precio y disponibilidad, el sistema funciona bien un tiempo. Pero al poco llegan tickets: la disponibilidad del artículo (que da el sistema heredado) **no devuelve respuesta** ni tras varios intentos. El equipo tampoco puede reprocesar las peticiones, porque **se pierden**.

Hay que implementar un mecanismo que **guarde las peticiones fallidas para reprocesarlas**, de modo que el cliente reciba respuesta aunque sea con retraso. El progreso se comprueba de forma continua.

**Validación:** automática.

## Reto 3 - Detectar el latido de la aplicación

Con el servicio de disponibilidad arreglado, el equipo quiere comprobar **cada minuto** la disponibilidad básica del endpoint de la aplicación (*Application Url*: `https://<api-id>.execute-api.us-east-1.amazonaws.com/v1/getitem?id=1111`) y actuar de forma proactiva. Hay que crear un mecanismo de **comprobaciones periódicas del código de estado**. Quieren usar un **blueprint existente**, sin crear ni mantener código propio.

**Validación:** automática.

## Reto 4 - Evaluar de forma continua la resiliencia

Si la aplicación de inventario cae, los clientes no pueden comprar y se pierden ingresos. El equipo tiene que asegurarse de que la aplicación crítica es resiliente y definir métricas de recuperación ante desastres por si hay una caída. Quieren **definir, validar y tener una vista global** del estado de resiliencia de la aplicación, y evaluar el impacto de cada cambio con una **evaluación automática diaria**.

La aplicación está desplegada con el stack de CloudFormation `arn:aws:cloudformation:us-east-1:<cuenta>:stack/gdQuests-...-TeamEnable/...`.

**Validación:** automática.

## Reto 5 - Monitorizar la memoria del servidor heredado

El *Availability Service* estaba en un servidor de aplicaciones Java (**Tomcat**) on-premise y se migró tal cual (*lift-and-shift*) a una EC2 (nombre: `Web Server - Availability Service`). El servidor es inestable: a veces se cuelga o se cae, y se sospecha de una **fuga de memoria**. Hay que crear un mecanismo para **monitorizar de forma continua el uso de memoria del sistema**.

**Validación:** automática.
