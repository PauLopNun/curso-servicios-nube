# Enunciado - Reto 4: DevOps Detective: La difícil situación del oleoducto

Nombre original: *DevOps Detective: The Pipeline Predicament*.

## Visión general

Eres ingeniero DevOps en TechCorp, una empresa de software en crecimiento. El equipo de desarrollo ha montado un pipeline de CI/CD con AWS CodePipeline para desplegar su aplicación web en un grupo de instancias EC2, pero los despliegues fallan y no consiguen encontrar la causa. Tienes que investigar y arreglar el pipeline.

Inventario:

- AWS CodePipeline: `devops-detective-pipeline`
- 2 instancias EC2 en el target group del ALB `jam-codepipeline-target-group`
- Bucket de artefactos: `devops-detective-jam-artifact-store-<cuenta>`
- Bucket de origen: `devops-detective-jam-source-bucket-<cuenta>`

## Tarea 1 - Validar la configuración (75 puntos)

El primer paso es revisar la configuración del pipeline y comprobar si los despliegues están bien configurados para las instancias EC2 que forman parte del target group del ALB.

**Tarea:** revisar la acción **EC2 Deploy** de la etapa "Deploy" y asegurarse de que esté dirigida a las instancias del target group del ALB.

Al guardar el pipeline, si NO se cambia la etapa "Source", hay que marcar la casilla *"No resource updates needed for this source action change"*.

**Validación:** encontrar el elemento que falta en la configuración de la acción EC2 Deploy, añadirlo y pulsar "Check my progress".

## Tarea 2 - Investigar el pipeline (75 puntos)

Con el target group ya en la etapa Deploy, los cambios se pueden desplegar con CodePipeline directamente en las instancias que dan servicio detrás del balanceador. Pero el pipeline sigue en estado "Failed" porque no encuentra en el Source los ficheros que necesita. TechCorp ha decidido desplegar también la configuración del servidor web con el mismo pipeline, siguiendo las buenas prácticas de CI/CD, en lugar de ejecutar a mano los scripts de despliegue del servidor web.

**Tarea** (LOS NOMBRES DE LOS FICHEROS TIENEN QUE SER EXACTAMENTE ESTOS):

1. Descargar en local:
   - `https://aws-jam-challenge-resources.s3.amazonaws.com/code-pipeline-ec2/index.html`
   - `https://aws-jam-challenge-resources.s3.amazonaws.com/code-pipeline-ec2/styles.css`
   - `https://aws-jam-challenge-resources.s3.amazonaws.com/code-pipeline-ec2/script.js`
2. Crear el fichero `deployspec.yml`, que tiene que hacer referencia a 2 scripts: uno "BeforeDeploy" (`.sh`) y otro "AfterDeploy" (`.sh`).
   - El script BeforeDeploy instala el servidor web, sus dependencias y cualquier otro paquete necesario.
   - El script AfterDeploy arranca el servidor web.
   - Referencia: tutorial de AWS para crear un servidor web (documentación de RDS, *Create a web server*).
3. Para diagnosticar, se puede entrar en las instancias con Systems Manager (EC2 → Connect → Session Manager).
4. Empaquetar todos los ficheros (`index.html`, `styles.css`, `script.js`, `deployspec.yml` y los 2 scripts) y subirlos al bucket de origen para que el pipeline se ejecute correctamente.

No hacen falta cambios de red. NO hay que cambiar el nombre ni el contenido de `index.html`, `styles.css` ni `script.js`.

**Validación:** empaquetar los ficheros y conseguir que el pipeline termine bien. Después, abrir el DNS del ALB `devops-detective-lb` y comprobar que la página HTML carga. Escribir ese DNS en la caja de respuesta y pulsar "Submit Answer".
