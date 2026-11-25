<div align="center">

# Reto 5 - Implementaciones en desarrollo (CodeDeploy con Auto Scaling)

![CodeDeploy](https://img.shields.io/badge/AWS-CodeDeploy-3F8624?style=for-the-badge&logoColor=white)
![Auto Scaling](https://img.shields.io/badge/EC2-Auto%20Scaling-FF9900?style=for-the-badge&logoColor=white)
![S3](https://img.shields.io/badge/Amazon-S3-569A31?style=for-the-badge&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

**Nombre en el Jam:** *Implementaciones en desarrollo* · 3 tareas · us-east-1

![Resuelto](https://img.shields.io/badge/Resuelto%20y%20verificado-2ea44f?style=flat-square)

</div>

## De qué va

Una web de cara al cliente funciona con **Nginx** en instancias EC2 de un **Auto Scaling group** (`ASG-CD-Jam`). Se quiere desplegar con **AWS CodeDeploy** para entregar cambios rápido y con seguridad, y que cada instancia nueva que lance Auto Scaling reciba el código automáticamente. Un compañero ya ha preparado el código (`source.zip`), pero su `appspec.yml` está mal.

## Cómo funciona CodeDeploy en EC2

```text
 source.zip en S3                CodeDeploy (aplicación jam-app, grupo jam)            Instancias del ASG
┌──────────────────┐   create-   ┌─────────────────────────────────────────┐   agente  ┌──────────────────────┐
│ appspec.yml      │ deployment  │ elige instancias (ASG) · una cada vez   │ ────────► │ ApplicationStop      │
│ deploy/*.sh      │ ──────────► │ rollback si falla · rol de servicio     │           │ (descarga e Install) │
│ deploy/index.html│             └─────────────────────────────────────────┘           │ BeforeInstall        │
└──────────────────┘                                                                    │ ApplicationStart     │
                                  Lifecycle hook en el ASG: cada instancia nueva        └──────────────────────┘
                                  espera en Pending:Wait hasta recibir el despliegue
```

| Concepto | Explicación corta |
|:--|:--|
| **Revisión** | El paquete que se despliega (zip, tar o tgz en S3, o un repositorio de GitHub). Lleva el código y el `appspec.yml`. |
| **appspec.yml** | Dice **qué ficheros** copiar y **adónde** (`files`), y **qué scripts** ejecutar en cada fase (`hooks`). Tiene que estar en la **raíz** de la revisión. |
| **Hooks** | Fases del despliegue en las que se ejecutan scripts. Orden in-place: ApplicationStop → DownloadBundle → **BeforeInstall** → *Install* → AfterInstall → **ApplicationStart** → ValidateService. |
| **Aplicación / grupo de despliegue** | La aplicación es un contenedor con nombre; el grupo dice **en qué instancias** se despliega, **cómo** (in-place / blue-green, de una en una...) y con **qué rol**. |
| **Agente de CodeDeploy** | Servicio instalado en cada instancia que descarga la revisión y ejecuta los hooks. |

---

## Tarea 1 - Preparar el artefacto (24 puntos)

### Qué pide

Crear un `appspec.yml` válido, con la clave **`location`** en los hooks `ApplicationStop`, `BeforeInstall` y `ApplicationStart` (sin `Install`), que copie los ficheros a **`/opt/codedeploy`**. Volver a comprimir con `appspec.yml` en la raíz y subirlo como `source.zip` al bucket.

### Cómo pensarlo

Al descomprimir `source.zip` sale:

```text
appspec_FIXME.yml          ← tiene los hooks pero sin "location": CodeDeploy no sabe qué ejecutar
deploy/applicationstop.sh  ← systemctl stop nginx
deploy/before.sh           ← instala nginx, jq y netcat
deploy/applicationstart.sh ← copia index.html a nginx, lo arranca y comprueba que la página
                              contiene "SecurityJamCodeDeployCompleted" (si no, exit 1)
deploy/index.html
```

Cada hook necesita una lista con `location` (ruta del script **relativa a la raíz de la revisión**), `timeout` y `runas`:

```yaml
hooks:
  ApplicationStop:
    - location: deploy/applicationstop.sh
      timeout: 60
      runas: root
```

`Install` no se pone: es la fase en la que **el propio agente** copia los ficheros de `files`, y no admite scripts.

### Paso a paso (en el equipo)

1. Descargar `source.zip` desde el enlace de la tarea y descomprimirlo en una carpeta vacía.
2. Crear `appspec.yml` con el contenido de [`scripts/appspec.yml`](scripts/appspec.yml) y **borrar `appspec_FIXME.yml`**, porque solo vale el nombre por defecto.
3. Opcional: en `deploy/index.html`, cambiar `UPDATE-ME` por `Today is Wednesday`. **No tocar** `SecurityJamCodeDeployCompleted`, porque es lo que comprueba `applicationstart.sh`.
4. Comprimir con `appspec.yml` en la raíz: `zip -r source.zip appspec.yml deploy`. Comprobarlo con `unzip -l source.zip`.

### Paso a paso en la consola

1. **S3** → bucket `jam-codedeploy-<cuenta>-us-east-1` (*S3Bucket* en las propiedades de salida) → **Upload** → **Add files** → `source.zip` → **Upload**.
2. Abrir el objeto y copiar el **S3 URI** (`s3://jam-codedeploy-.../source.zip`): hace falta en la Tarea 3.

### Con la CLI

Bloque *TAREA 1* de [`scripts/comandos.sh`](scripts/comandos.sh).

---

## Tarea 2 - Aplicación y grupo de despliegue (24 puntos)

### Qué pide

Crear la aplicación **`jam-app`** y el grupo de despliegue **`jam`**: **in-place**, **una instancia cada vez**, **rollback si falla** y sin balanceador. El rol de servicio "Jam-CodeDeploy" ya existe.

### Paso a paso en la consola

1. **CodeDeploy** → **Applications** → **Create application**:
   - **Name:** `jam-app` → **Compute platform:** *EC2/On-premises* → **Create application**.
2. Dentro de `jam-app` → **Create deployment group**:
   - **Deployment group name:** `jam`.
   - **Service role:** el que empieza por `Jam-CodeDeploy`. Su nombre real es `Jam-CodeDeploy-<cuenta>-us-east-1`.
   - **Deployment type:** *In-place*.
   - **Environment configuration:** *Amazon EC2 Auto Scaling groups* → `ASG-CD-Jam`.
   - **Deployment settings:** `CodeDeployDefault.OneAtATime`.
   - **Load balancer:** desmarcar *Enable load balancing*.
   - **Advanced** → **Rollbacks:** marcar *Roll back when a deployment fails*.
   - **Create deployment group**.

### Con la CLI

Bloque *TAREA 2* de [`scripts/comandos.sh`](scripts/comandos.sh).

> **Trampa:** si se pasa `arn:aws:iam::<cuenta>:role/Jam-CodeDeploy`, da `AccessDenied ... iam:PassRole`. Ese rol no existe y el permiso PassRole solo está concedido sobre el ARN real. Para encontrarlo: `aws iam list-roles --query 'Roles[?starts_with(RoleName,`Jam-CodeDeploy`)].Arn'`.

### Qué pasa por debajo

Al asociar el ASG, CodeDeploy le añade un **lifecycle hook** de lanzamiento. Cada instancia nueva se queda en `Pending:Wait` hasta que CodeDeploy le despliega la **última revisión correcta**, y solo entonces pasa a `InService`. Así se cumple "desplegar cada vez que Auto Scaling lance una instancia". Se ve con `aws autoscaling describe-lifecycle-hooks --auto-scaling-group-name ASG-CD-Jam`.

---

## Tarea 3 - Lanzar el despliegue (32 puntos)

### Qué pide

Crear un despliegue en `jam-app` desde el `source.zip` de S3, que **sobrescriba** el contenido. El validador comprueba que el último despliegue haya terminado bien y que la web muestre el texto correcto.

### Paso a paso en la consola

1. **CodeDeploy** → `jam-app` → grupo `jam` → **Create deployment**:
   - **Revision type:** *My application is stored in Amazon S3*.
   - **Revision location:** el S3 URI de la Tarea 1 → **Revision file type:** *.zip*.
   - **Additional deployment behavior settings** → **Content options:** *Overwrite the content*.
   - **Create deployment**.
2. Esperar a que el estado pase a **Succeeded**. En la pestaña de eventos de la instancia se ve cada hook en verde.
3. Para ver la web: **Systems Manager** → **Parameter Store** → `/sj/codedeploy/dns` → copiar el **Value** y abrirlo en el navegador.

### Con la CLI

Bloque *TAREA 3* de [`scripts/comandos.sh`](scripts/comandos.sh): `create-deployment --file-exists-behavior OVERWRITE`, `wait deployment-successful` y la comprobación con `curl`.

### Resultado obtenido

`Succeeded` en la instancia del ASG, sin fallos ni instancias saltadas.

---

## Errores típicos

| Síntoma | Causa | Solución |
|:--|:--|:--|
| El despliegue falla en `ApplicationStop` la primera vez | Se usan los scripts de la revisión **anterior** | En el primer despliegue no hay anterior; si falla, revisar el log del agente |
| *"The overall deployment failed because too many individual instances failed"* | Un script terminó con código distinto de 0 | `get-deployment-instance` → ver qué hook y qué mensaje |
| `applicationstart.sh` falla con *"Could not find text"* | Se borró `SecurityJamCodeDeployCompleted` del index.html | Dejar ese texto |
| *"The specified key does not exist"* o falta el appspec | `appspec.yml` no está en la raíz del zip | Comprimir desde dentro de la carpeta |
| `iam:PassRole` denegado | Nombre de rol incorrecto | Usar el ARN real del rol |
| *"file already exists"* | Comportamiento por defecto `DISALLOW` | Content options → *Overwrite the content* |

## Preguntas de repaso

<details>
<summary>¿Por qué no se puede usar el hook Install?</summary>

Porque en Install es el agente de CodeDeploy el que copia los ficheros de la sección `files` a su destino. Es una fase reservada y no admite scripts del usuario.
</details>

<details>
<summary>¿Por qué ApplicationStop usa los scripts de la revisión anterior?</summary>

Se ejecuta **antes** de descargar la revisión nueva, para parar la aplicación que está funcionando. Por eso usa el `appspec.yml` y los scripts de la última revisión que se desplegó bien en esa instancia.
</details>

<details>
<summary>¿Qué configuraciones de despliegue predefinidas hay y qué diferencia hay entre in-place y blue/green?</summary>

`CodeDeployDefault.OneAtATime`, `HalfAtATime` y `AllAtOnce`. **In-place** actualiza las mismas instancias (cada una deja de dar servicio mientras se actualiza). **Blue/green** crea instancias nuevas con la versión nueva, les pasa el tráfico con un balanceador y después retira las antiguas.
</details>

<details>
<summary>¿Qué opciones tiene file-exists-behavior?</summary>

`DISALLOW` (por defecto: el despliegue falla si el fichero ya existe y no era de un despliegue anterior), `OVERWRITE` (lo sustituye) y `RETAIN` (conserva el que hay).
</details>

<details>
<summary>¿Qué necesita una instancia para recibir despliegues de CodeDeploy?</summary>

El **agente de CodeDeploy** instalado y en marcha, y un **perfil de instancia** con permiso para leer la revisión del bucket S3. El grupo de despliegue necesita además un **rol de servicio** que deje a CodeDeploy consultar EC2 y Auto Scaling.
</details>

<details>
<summary>¿Dónde se miran los logs de un despliegue en la instancia?</summary>

En `/var/log/aws/codedeploy-agent/codedeploy-agent.log` (agente) y en `/opt/codedeploy-agent/deployment-root/<grupo>/<despliegue>/logs/scripts.log` (salida de cada script).
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 3 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Solución por CLI de las 3 tareas |
| [`scripts/appspec.yml`](scripts/appspec.yml) | appspec.yml corregido |
| [`scripts/deploy/`](scripts/deploy) | Scripts de los hooks e index.html del paquete |

---

[Volver al índice del Jam](../README.md)
