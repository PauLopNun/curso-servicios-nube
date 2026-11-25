<div align="center">

# Reto 4 - DevOps Detective: La difícil situación del oleoducto

![CodePipeline](https://img.shields.io/badge/AWS-CodePipeline-4053D6?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/Amazon-EC2-FF9900?style=for-the-badge&logoColor=white)
![ALB](https://img.shields.io/badge/Application-Load%20Balancer-8C4FFF?style=for-the-badge&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=for-the-badge&logo=apache&logoColor=white)

**Nombre en el Jam:** *DevOps Detective: La difícil situación del oleoducto* (*The Pipeline Predicament*) · 2 tareas · us-west-2

![Resuelto](https://img.shields.io/badge/Resuelto%20y%20verificado-2ea44f?style=flat-square)

</div>

> La Tarea 1 la resolvió otro miembro del equipo. La Tarea 2 se terminó y se verificó entre los dos: el pipeline acabó en *Succeeded* y la web cargó desde el ALB. Los ficheros de [`scripts/`](scripts) son los que funcionaron.

## De qué va

TechCorp tiene un pipeline de **AWS CodePipeline** (`devops-detective-pipeline`) que despliega su web en **2 instancias EC2** detrás de un **Application Load Balancer**. Los despliegues fallan y nadie sabe por qué. Hay que investigar el pipeline como un detective y arreglarlo.

## Arquitectura

```text
 S3 source bucket            CodePipeline: devops-detective-pipeline
 source.zip  ──────────► [ Source (S3) ] ──► [ Deploy: acción "EC2" ] ──SSM──► EC2 #1 ┐
 (Tarea 2)                                    deployspec.yml                    EC2 #2 ┤── target group ──► ALB
                                              TargetGroupNameList (Tarea 1)            │   jam-codepipeline-  devops-detective-lb
                                                                                       ┘   target-group
```

## Conceptos que hay que tener claros

| Concepto | Explicación corta |
|:--|:--|
| **Acción de despliegue "EC2" de CodePipeline** | Despliega directamente en instancias EC2, **sin CodeDeploy**. Elige las instancias por tag y ejecuta los scripts en ellas mediante **SSM**. |
| **deployspec.yml** | El equivalente al `appspec.yml` de CodeDeploy para esta acción: dice qué scripts se ejecutan en cada fase (`BeforeDeploy`, `AfterDeploy`...). |
| **TargetGroupNameList** | Si se indica el target group del ALB, el pipeline **saca cada instancia del target group**, despliega en ella y la **vuelve a registrar** cuando está sana. Así se evitan cortes. |
| **Source S3** | El pipeline se dispara cuando se sube una versión nueva del objeto (clave `S3ObjectKey`) al bucket de origen, que tiene que tener **versionado**. |

---

## Tarea 1 - Validar la configuración (75 puntos)

### Qué pide

Revisar la acción **EC2 Deploy** de la etapa *Deploy* y encontrar **qué elemento falta** para que despliegue en las instancias que están en el target group del ALB `jam-codepipeline-target-group`.

### Cómo pensarlo

Se revisa la configuración de la acción parámetro a parámetro:

| Parámetro | Pregunta |
|:--|:--|
| `InstanceTagKey` / `InstanceTagValue` | ¿Coincide con el tag de las 2 instancias del target group? |
| `InstanceType` | ¿Es `EC2`? |
| `TargetDirectory` | ¿Adónde se copian los ficheros? |
| `DeploySpec` | ¿Apunta a `deployspec.yml`? |
| **`TargetGroupNameList`** | **¿Está indicado el target group del ALB?** |

El enunciado insiste en el ALB, así que lo que falta es el **target group**: `TargetGroupNameList = jam-codepipeline-target-group`.

### Paso a paso en la consola

1. **CodePipeline** → `devops-detective-pipeline` → **Edit**.
2. Etapa **Deploy** → **Edit stage** → en la acción EC2, pulsar el **icono de editar**.
3. Revisar los campos. En **Target group** (o *Load balancer target groups*), elegir `jam-codepipeline-target-group`. Comprobar también que el tag de las instancias es el correcto.
4. **Done** → **Done** → **Save**. En el aviso que aparece, marcar **"No resource updates needed for this source action change"**, porque la etapa Source no se ha cambiado → **Save**.
5. En la tarea del Jam → **Check my progress**.

### Con la CLI

Bloques *0* y *TAREA 1* de [`scripts/comandos.sh`](scripts/comandos.sh): `get-pipeline` para leer la configuración y `update-pipeline` con el JSON editado.

---

## Tarea 2 - Investigar el pipeline (75 puntos)

### Qué pide

El pipeline sigue fallando porque **en el Source no están los ficheros que necesita**. Hay que preparar un paquete con:

- `index.html`, `styles.css` y `script.js`, descargados de `https://aws-jam-challenge-resources.s3.amazonaws.com/code-pipeline-ec2/` **sin cambiarles el nombre ni el contenido**.
- `deployspec.yml`, con un script **BeforeDeploy** (instala el servidor web) y otro **AfterDeploy** (lo arranca).

Se sube al bucket de origen, el pipeline tiene que terminar bien, y la respuesta es el **DNS del ALB** `devops-detective-lb`.

### Cómo pensarlo

- **El deployspec** dice qué ficheros se copian adónde (`files`) y qué scripts se ejecutan antes y después del despliegue (`scripts`):

  ```yaml
  version: 0.1
  files:
    - source: /index.html
      destination: /var/www/html/
    - source: /styles.css
      destination: /var/www/html/
    - source: /script.js
      destination: /var/www/html/
  scripts:
    BeforeDeploy:
      - location: before_deploy.sh
        timeout: 300
        runas: root
    AfterDeploy:
      - location: after_deploy.sh
        timeout: 300
        runas: root
  ```

  > **El error que tuvo el equipo:** escribir `version: 0.0` con `BeforeDeploy` y `AfterDeploy` dentro de `hooks:`, como en un `appspec.yml` de CodeDeploy. Según la [documentación de la acción EC2](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-EC2Deploy.html#action-reference-EC2Deploy-deployspec), `BeforeDeploy` y `AfterDeploy` solo existen en la sección **`scripts:`**. La sección `hooks:` (formato 0.0) solo admite `ApplicationStop`, `BeforeInstall`, `AfterInstall`, `ApplicationStart` y `ValidateService`. Con el formato equivocado, los scripts no se ejecutan: Apache no arranca, las instancias quedan *unhealthy*, el ALB da **502** y el despliegue se queda esperando al health check de la primera instancia.

- **BeforeDeploy** instala Apache, como en el tutorial de RDS que enlaza el enunciado (`dnf install -y httpd` en Amazon Linux 2023).
- **AfterDeploy** deja la web en `/var/www/html` (si `TargetDirectory` es otra carpeta, la copia) y arranca Apache.
- **El nombre del zip** tiene que ser el que espera la acción Source (`S3ObjectKey`). Si se sube con otro nombre, el pipeline no se entera.

Los scripts de [`scripts/`](scripts) contemplan las dos dudas típicas: si la instancia tiene `dnf` o `yum`, y si la carpeta de destino es `/var/www/html` u otra.

### Paso a paso en la consola

1. Descargar los 3 ficheros desde el navegador: abrir cada URL → clic derecho → **Guardar como**, con el mismo nombre. **No** copiar y pegar el contenido, porque se pueden cambiar los espacios.
2. Crear `deployspec.yml`, `before_deploy.sh` y `after_deploy.sh` con el contenido de [`scripts/`](scripts).
3. Comprimir los 6 ficheros **en la raíz** del zip.
4. **CodePipeline** → `devops-detective-pipeline` → **Edit** → etapa **Source** → ver el **S3 object key** que espera (por ejemplo, `source.zip`). Salir sin guardar.
5. **S3** → `devops-detective-jam-source-bucket-<cuenta>` → **Upload** → el zip, con ese mismo nombre → **Upload**.
6. **CodePipeline** → el pipeline arranca solo. Esperar a que *Source* y *Deploy* se pongan en verde (**Succeeded**).
7. **EC2** → **Load Balancers** → `devops-detective-lb` → copiar el **DNS name** → abrirlo en el navegador y comprobar que carga *"AWS JAM - Cloud Challenge Platform"*.
8. En la tarea del Jam, pegar el DNS en la caja de respuesta → **Submit Answer**.

### Si el despliegue falla

1. **CodePipeline** → etapa *Deploy* → **View details**: muestra qué fase y qué instancia fallaron.
2. **EC2** → instancia → **Connect** → **Session Manager**:

   ```bash
   sudo systemctl status httpd
   ls -l /var/www/html
   sudo ls /var/log/amazon/ssm/        # logs del agente de SSM, que ejecuta los scripts
   ```

3. Si el despliegue se queda **"In progress" mucho rato** con una instancia: **EC2** → **Target groups** → `jam-codepipeline-target-group` → **Targets**. Si sale *unhealthy*, Apache no responde con un 200 en `/`. Primero hay que revisar el deployspec: `scripts:` y `version: 0.1`, no `hooks:`. Para que una subida nueva se despliegue, se puede parar la ejecución atascada (**Stop execution** → *Stop and abandon*).
   - **Ojo:** al parar con *Stop and abandon*, el pipeline marca la acción como *Abandoned*, pero la acción de despliegue EC2 **sigue en marcha por debajo**, esperando al health check. Mientras tanto, las ejecuciones nuevas fallan en Deploy con *"A previous action execution is still in progress"*, y la etapa no se puede reintentar (*StageNotRetryableException*). Hay que esperar a que la acción vieja termine y lanzar otra ejecución con **Release change** (`aws codepipeline start-pipeline-execution`).
4. Otras causas habituales: scripts sin permiso de ejecución, `dnf` o `yum` equivocado, ficheros dentro de una subcarpeta del zip, o el zip subido con un nombre distinto del `S3ObjectKey`.

### Cómo se resolvió de verdad (resultado obtenido)

1. El primer paquete del equipo tenía el `deployspec.yml` en formato `version: 0.0` con `hooks:`. Los scripts no se ejecutaban, las 2 instancias quedaban *unhealthy* y el ALB daba **502**.
2. Se cambió a `version: 0.1` con `files:` y `scripts:` (el de [`scripts/deployspec.yml`](scripts/deployspec.yml)) y se volvió a subir `source.zip`.
3. La ejecución anterior se había parado con *Stop and abandon*, pero su acción seguía colgada y bloqueaba todas las ejecuciones nuevas (*"A previous action execution is still in progress"*). **Truco para desbloquearlo:** cambiar el **nombre de la acción** de despliegue (`EC2Deploy` → `EC2Deploy-v2`) con la misma configuración. Como es otra acción, la vieja ya no la bloquea:

   ```bash
   aws codepipeline get-pipeline --name devops-detective-pipeline > p.json
   # quitar "metadata" y renombrar la acción EC2Deploy -> EC2Deploy-v2
   aws codepipeline update-pipeline --cli-input-json file://p-nuevo.json
   aws codepipeline start-pipeline-execution --name devops-detective-pipeline
   ```

4. En unos 6 minutos: 2/2 instancias desplegadas (una cada vez), las dos *healthy*, pipeline en **Succeeded** y el ALB sirviendo *"AWS JAM - Cloud Challenge Platform"*. El validador comprueba: archivos válidos, target group encontrado, éxito del pipeline y coincidencia del HTML.

### Con la CLI

Bloque *TAREA 2* de [`scripts/comandos.sh`](scripts/comandos.sh): descarga, empaquetado, subida con la clave correcta, seguimiento de la ejecución y DNS del ALB.

---

## Preguntas de repaso

<details>
<summary>¿Qué secciones tiene el deployspec.yml de la acción EC2 y en cuál van BeforeDeploy y AfterDeploy?</summary>

`files` (origen y destino de los ficheros), `scripts` (los eventos **BeforeDeploy** y **AfterDeploy**, con `version: 0.1`) y `hooks`. Esta última solo existe por compatibilidad con el appspec de CodeDeploy (`version: 0.0`) y admite `ApplicationStop`, `BeforeInstall`, `AfterInstall`, `ApplicationStart` y `ValidateService`. Si se ponen `BeforeDeploy` y `AfterDeploy` dentro de `hooks`, no se ejecutan.
</details>

<details>
<summary>¿Qué diferencia hay entre la acción EC2 de CodePipeline y CodeDeploy?</summary>

La acción **EC2** despliega directamente desde el pipeline: elige las instancias por tag, ejecuta los scripts del `deployspec.yml` por SSM y puede sacar y meter las instancias en un target group. **CodeDeploy** es un servicio aparte, con aplicaciones, grupos de despliegue, un agente propio en las instancias, más fases (hooks) y estrategias como blue/green.
</details>

<details>
<summary>¿Para qué sirve indicar el target group en la acción de despliegue?</summary>

Para desplegar **sin cortes**. Antes de actualizar una instancia, la desregistra del target group (el ALB deja de enviarle tráfico); al terminar, la vuelve a registrar, y solo sigue con la siguiente cuando el health check está bien.
</details>

<details>
<summary>¿Por qué aparece "No resource updates needed for this source action change" al guardar?</summary>

Al guardar, la consola ofrece volver a crear los recursos del disparador del Source (la regla de EventBridge y el trail de CloudTrail para S3). Si no se ha cambiado la etapa Source, no hace falta y es mejor no tocarlos.
</details>

<details>
<summary>¿Por qué el bucket del Source tiene que tener versionado?</summary>

CodePipeline identifica cada ejecución por la **versión** del objeto. Así sabe qué revisión exacta desplegó y puede repetir o comparar ejecuciones.
</details>

<details>
<summary>¿Qué hacen MaxBatch y MaxError?</summary>

`MaxBatch` limita cuántas instancias se actualizan a la vez. `MaxError` fija cuántas pueden fallar antes de dar el despliegue por fallido.
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 2 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Investigación y solución por CLI |
| [`scripts/deployspec.yml`](scripts/deployspec.yml) | Fases y scripts del despliegue |
| [`scripts/before_deploy.sh`](scripts/before_deploy.sh) | Instala Apache (dnf o yum) |
| [`scripts/after_deploy.sh`](scripts/after_deploy.sh) | Copia la web a /var/www/html y arranca Apache |

---

[Volver al índice del Jam](../README.md)
