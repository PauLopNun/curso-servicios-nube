# Enunciado - Reto 5: Implementaciones en desarrollo

Región: us-east-1. Propiedades de salida: `AutoScalingGroupName` (ASG-CD-Jam), `S3Bucket` (jam-codedeploy-<cuenta>-us-east-1) y `SecurityGroup`.

## Visión general

Eres desarrollador de una aplicación web muy importante, de cara al cliente. Está alojada en EC2 con Nginx, y tienes que ayudar al equipo a montar un mecanismo de despliegue continuo para entregar cambios de forma rápida, segura y fiable. AWS CodeDeploy es un servicio totalmente gestionado que automatiza los despliegues. La aplicación está en un Auto Scaling group y quieres que la actualización llegue a las instancias actuales y que se despliegue también cada vez que Auto Scaling lance una instancia nueva. Otro desarrollador ya ha empaquetado el código (ZIP). Tu trabajo es recuperarlo y modificarlo para poder desplegarlo con CodeDeploy.

## Tarea 1 - Preparar el artefacto de despliegue (24 puntos)

Crear un `appspec.yml` válido con claves `location` para los hooks ApplicationStop, BeforeInstall y ApplicationStart. Solo se admite el nombre por defecto del fichero, y solo se sube un ZIP a S3: `source.zip`.

1. Descargar `source.zip` desde el enlace de la tarea (incluye un `appspec-FIXME.yml` de ejemplo) y descomprimirlo.
2. Crear un `appspec.yml` válido. CodeDeploy tiene que extraer los ficheros en `/opt/codedeploy`, porque otro código depende de esa ruta. Se usan los hooks ApplicationStop, BeforeInstall y ApplicationStart; **no** se usa Install.
3. Opcional: cambiar el texto `UPDATEME` de `deploy/index.html` por el día de hoy (por ejemplo, "Today is Friday").
4. Indicar la ubicación del script en cada hook. Ejemplo:

   ```yaml
   ApplicationStop:
        - location: deploy/applicationstop.sh
          timeout: 60
          runas: root
   ```

5. Comprimir sin cambiar la estructura: `appspec.yml` en la raíz del ZIP, junto a la carpeta `deploy` con los scripts y el index.html.
6. Subir el código modificado al bucket S3 y copiar el S3 URI de `source.zip`.

**Validación:** automática, cuando se vuelve a subir el fichero al bucket.

## Tarea 2 - Crear la aplicación y el grupo de despliegue de CodeDeploy (24 puntos)

Crear una aplicación y un grupo de despliegue de CodeDeploy, desde la consola o con la AWS CLI.

- La aplicación se tiene que llamar **`jam-app`** y el grupo de despliegue **`jam`**. Es importante para que la validación funcione.
- Despliegue **in-place** y **one-at-a-time**.
- Si el despliegue falla, tiene que hacer **rollback**.
- No hace falta balanceador de carga.
- El rol de servicio de CodeDeploy ya existe y se llama `Jam-CodeDeploy`. No hay que modificar nada de IAM.

**Validación:** automática, cuando existen la aplicación y el grupo de despliegue.

## Tarea 3 - Crear el despliegue (32 puntos)

Crear un despliegue en la aplicación `jam-app` que apunte al `source.zip` de S3 subido en la Tarea 1. El despliegue tiene que **sobrescribir** el contenido.

**Validación:** la plataforma comprueba que el ÚLTIMO despliegue haya terminado bien, abre el security group y comprueba que la web muestra el texto correcto. Hay que esperar a que el despliegue termine bien antes de comprobar.

Opcional: para ver la web en el navegador, ir a AWS Systems Manager → Parameter Store → `/sj/codedeploy/dns` y abrir el valor en el navegador.
