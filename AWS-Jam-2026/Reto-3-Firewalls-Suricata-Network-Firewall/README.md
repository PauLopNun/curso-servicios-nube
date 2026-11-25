<div align="center">

# Reto 3 - De Suricata en EC2 a AWS Network Firewall

![Network Firewall](https://img.shields.io/badge/AWS-Network%20Firewall-DD344C?style=for-the-badge&logoColor=white)
![GWLB](https://img.shields.io/badge/Gateway-Load%20Balancer-8C4FFF?style=for-the-badge&logoColor=white)
![Transit Gateway](https://img.shields.io/badge/Transit-Gateway-8C4FFF?style=for-the-badge&logoColor=white)
![Suricata](https://img.shields.io/badge/Suricata-IDS%2FIPS-EF3B2D?style=for-the-badge&logoColor=white)

**Nombre en el Jam:** *AWS, ¡ayúdeme a administrar mis firewalls!* · 4 tareas · us-east-1

![Resuelto](https://img.shields.io/badge/Resuelto%20y%20verificado-2ea44f?style=flat-square)

</div>

## De qué va

Eres consultor de seguridad. La empresa tiene un **firewall centralizado**: todo el tráfico de salida a Internet de las VPC de aplicaciones pasa por un único punto de inspección, donde hay una EC2 con **Suricata**, un IDS/IPS de código abierto. Funciona, pero hay que parchearla, endurecerla, darle alta disponibilidad... El plan es:

1. Terminar de montar el camino del tráfico a través de Suricata.
2. Demostrar que inspecciona, con una regla que bloquee algo.
3. Pasar el tráfico a **AWS Network Firewall**, que es gestionado.
4. Llevar la regla de Suricata a Network Firewall, que entiende el mismo formato de reglas.

## Arquitectura

```text
 Cloud1-VPC 10.0.1.0/24                Perimeter-VPC 10.0.0.0/24                        Internet
┌──────────────────────┐   ┌──────────────────────────────────────────────────────────┐
│ Cloud1-WebServer     │   │ Perim-Priv-TGW    Perim-Priv-FW          Perim-Pub        │
│ 0.0.0.0/0 → TGW ─────┼─► │ (attach. TGW) ──► GWLBe Suricata ───┐    NAT GW ──► IGW ──┼──►
└──────────────────────┘ ▲ │                   GWLBe Net. Firewall│     ▲               │
                         │ │                                      └─────┘               │
        Transit Gateway  │ └──────────────────────────────┬───────────────────────────────┘
        0.0.0.0/0 → Perimeter                             │ GENEVE (UDP 6081)
                                                          ▼
                                   Inspection-VPC 10.0.2.0/24: Gateway Load Balancer → Suricata (EC2)
```

- **Tareas 1 y 2:** el tráfico pasa por el **GWLB endpoint de Suricata**.
- **Tareas 3 y 4:** las mismas rutas apuntan al **endpoint de Network Firewall**, que ya estaba creado en la misma subred, con el tag `AWSNetworkFirewallManaged=true`.

## Conceptos que hay que tener claros

| Concepto | Explicación corta |
|:--|:--|
| **Gateway Load Balancer (GWLB)** | Balanceador de capa 3 que reparte el tráfico entre *appliances* (firewalls, IDS) de forma transparente. Encapsula los paquetes con **GENEVE** en el puerto UDP 6081. |
| **Endpoint service / GWLB endpoint** | El GWLB se publica como *endpoint service* en su VPC. En la VPC que quiere inspeccionar se crea un **GWLB endpoint**, que se usa como destino en las tablas de rutas. |
| **Tráfico simétrico** | Un firewall con estado tiene que ver la ida y la vuelta de cada conexión. Si la vuelta no pasa por él, la descarta. Por eso hay que poner rutas en los **dos sentidos**. |
| **Suricata en modo IPS** | Con **NFQUEUE**, iptables le pasa los paquetes y Suricata decide si los acepta o los descarta (`drop`). En modo IDS (pcap / af-packet) solo genera alertas. |
| **AWS Network Firewall** | Firewall gestionado de AWS. Tiene un motor *stateless* (5-tupla) y otro *stateful* que usa **reglas compatibles con Suricata**. Se despliega como un endpoint por AZ. |

---

## Tarea 1 - Que Cloud1-WebServer haga ping a 8.8.8.8 a través de Suricata

### Qué pide

Desde la instancia web de Cloud1, `ping 8.8.8.8` falla. Hay que revisar el despliegue y añadir o configurar lo que falte para que funcione.

### Cómo pensarlo: seguir un paquete

Hay que hacer el camino de un paquete salto a salto y, en cada sitio, preguntarse "¿qué ruta le dice adónde ir?":

| Salto | Tabla | Ruta que había | ¿Bien? |
|:--|:--|:--|:-:|
| Web → TGW | Cloud1-Priv-Web-RT | `0.0.0.0/0 → TGW` | Sí |
| TGW → Perimeter | TGW-Core-RT | `0.0.0.0/0 → attachment Perimeter` | Sí |
| Entra en Perimeter (subred del TGW) | Perim-Priv-TGW-RT | **solo `local`** | **No** |
| Sale de la inspección hacia el NAT | Perim-Priv-FW-RT | `0.0.0.0/0 → NAT`, `10.0.1.0/24 → TGW` | Sí |
| Vuelve de Internet por el NAT | Perim-Pub-RT | `0.0.0.0/0 → IGW` (falta la vuelta a 10.0.1.0/24) | **No** |

En Inspection-VPC ya estaba todo: el GWLB `Inspection-GWLB`, el target group GENEVE con Suricata en estado **healthy** y el *endpoint service*. Además, el *user data* de Suricata buscaba la IP del GWLB y configuraba GENEVE en el puerto 6081: Suricata estaba preparada para ir detrás de un GWLB. Lo único que faltaba era **conectar Perimeter-VPC con ese servicio**.

### Qué faltaba

1. Un **GWLB endpoint** en Perimeter-VPC (subred `Perim-Priv-FW`) que apunte al endpoint service de Suricata.
2. Ruta de ida en **Perim-Priv-TGW-RT**: `0.0.0.0/0 → GWLBe de Suricata`.
3. Ruta de vuelta en **Perim-Pub-RT**: `10.0.1.0/24 → GWLBe de Suricata`.

### Paso a paso en la consola

1. **VPC** → **Endpoint services**: copiar el **Service name** del servicio del `Inspection-GWLB` (`com.amazonaws.vpce.us-east-1.vpce-svc-...`).
2. **VPC** → **Endpoints** → **Create endpoint**:
   - **Name:** `Perim-Suricata-GWLBe`.
   - **Type:** *Endpoint services that use NLBs and GWLBs*.
   - **Service name:** pegarlo → **Verify service**.
   - **VPC:** `Perimeter-VPC` → **Subnet:** `Perim-Priv-FW`.
   - **Create endpoint** y esperar a que esté **Available**.
3. **VPC** → **Route tables** → `Perim-Priv-TGW-RT` → **Routes** → **Edit routes** → **Add route**: destino `0.0.0.0/0`, *Target* **Gateway Load Balancer Endpoint** → el endpoint recién creado → **Save changes**.
4. **Route tables** → `Perim-Pub-RT` → **Edit routes** → **Add route**: destino `10.0.1.0/24`, mismo endpoint → **Save changes**.
5. **EC2** → `Cloud1-WebServer` → **Connect** → **Session Manager** → **Connect** → `ping -c 4 8.8.8.8`. Tiene que responder.
6. Opcional: en `suricata-instance` (también por Session Manager), `sudo tail /var/log/suricata/fast.log` muestra las alertas `Alert on any ICMP` de ese ping.

### Con la CLI

Bloques *0* y *TAREA 1* de [`scripts/comandos.sh`](scripts/comandos.sh): reconocimiento completo de la red (instancias, VPC, subredes, tablas, endpoints, TGW, GWLB), seguido de `create-vpc-endpoint` y los dos `create-route`.

> Si el rol no deja usar `ssm:SendCommand`, [`scripts/ssm-ejecutar.sh`](scripts/ssm-ejecutar.sh) ejecuta comandos en las instancias abriendo una sesión de Session Manager (`start-session` con `AWS-StartInteractiveCommand`).

---

## Tarea 2 - Regla de Suricata para bloquear HTTP a amazon.com

### Qué pide

Ya hay una regla que da una **alerta** al acceder a amazon.com por HTTP. Hay que cambiarla para que lo **bloquee** (`drop`), solo por HTTP (no HTTPS) y solo `amazon.com` (no `www.amazon.com`).

### Cómo pensarlo

```text
alert http any any -> any any (msg:"amazon.com is blocked"; http.host; content:"amazon.com"; startswith; endswith; sid:1;)
└─┬─┘ └┬─┘ └──┬──┘ └┬┘ └──┬──┘ └──────────────────────────────── opciones ─────────────────────────────────────────┘
acción proto origen dir destino
```

- `http.host; content:"amazon.com"` compara la cabecera Host de la petición HTTP.
- `startswith; endswith` hacen que el Host sea **exactamente** `amazon.com`, así que `www.amazon.com` no coincide.
- Al ser una regla de protocolo `http`, **no afecta a HTTPS**: el Host va cifrado. Para HTTPS habría que usar `tls.sni`.

Solo hay que cambiar la palabra `alert` por `drop`.

### Paso a paso en la consola (Session Manager en `suricata-instance`)

```bash
sudo -i
cat /var/lib/suricata/rules/suricata.rules           # ver la regla actual
sed -i 's/^alert  *http any any -> any any (msg:"amazon.com is blocked"/drop http any any -> any any (msg:"amazon.com is blocked"/' \
  /var/lib/suricata/rules/suricata.rules
cat /var/lib/suricata/rules/suricata.rules           # comprobar (ver scripts/suricata.rules)

# Reiniciar Suricata de forma segura (ver "Problema" más abajo)
systemctl stop suricata; rm -f /var/run/suricata.pid
/usr/bin/suricata -c /etc/suricata/suricata.yaml --pidfile /var/run/suricata.pid -q 0 -D
sleep 20; pgrep -a Suricata
grep -E 'rules successfully loaded|engine started' /var/log/suricata/suricata.log | tail -2
```

Prueba desde `Cloud1-WebServer`:

```bash
curl -m 10 -I http://amazon.com        # se queda colgado: bloqueado
curl -m 10 -I http://www.amazon.com    # 301
curl -m 10 -I https://amazon.com       # 301
```

En Suricata, `tail /var/log/suricata/fast.log` muestra `[Drop] ... amazon.com is blocked`.

### Problema que apareció (y que conviene saber)

Después de `/etc/init.d/suricata restart`, `systemctl status suricata` decía **`active (exited)`**, pero **no había ningún proceso de Suricata** (`pgrep -a Suricata` no devolvía nada). El arranque se ejecutó cuando el proceso viejo aún no había terminado de pararse.

Lo peor es que **todo seguía funcionando**, pero sin inspeccionar. Las reglas de iptables usan `NFQUEUE --queue-bypass`: si nadie escucha en la cola, los paquetes pasan sin más. Por eso, después de cambiar reglas, siempre hay que comprobar en el log que Suricata ha cargado las reglas: *"2 rules successfully loaded"* y *"engine started"*.

---

## Tarea 3 - Mover el tráfico a AWS Network Firewall

### Qué pide

En el futuro el entorno será multi-AZ, y eso significa más instancias de Suricata que mantener. Hay que completar la red para que el tráfico pase por **Network Firewall**. La tarea se valida cuando el tráfico pasa por el firewall **y llega a su destino**.

### Cómo pensarlo

El firewall `Inspection-NFW` ya existía, con su endpoint en la misma subred `Perim-Priv-FW`. La parte de red se reduce a **cambiar el destino de las dos rutas** de la Tarea 1.

Pero, al hacerlo, el ping seguía sin funcionar. Mirando la **política** del firewall se ve por qué: tenía un único grupo de reglas, `Inspection-Block-All-Rule-Group`, con **DROP de todo el tráfico IP**. Era la segunda trampa de la tarea.

### Paso a paso en la consola

1. **VPC** → **Network Firewall** → **Firewalls** → `Inspection-NFW` → pestaña **Firewall details**: anotar el **endpoint ID** de us-east-1a (`vpce-...`).
2. **Route tables** → `Perim-Priv-TGW-RT` → **Edit routes** → la ruta `0.0.0.0/0` → cambiar el target al endpoint del firewall → **Save**.
3. **Route tables** → `Perim-Pub-RT` → la ruta `10.0.1.0/24` → endpoint del firewall → **Save**.
4. **Network Firewall** → **Network Firewall rule groups** → `Inspection-Block-All-Rule-Group` → **Edit rules**:
   - Cambiar la acción de la regla de **Drop** a **Pass**.
   - Añadir otra regla **Pass** con protocolo **ICMP**, origen y destino *Any* y dirección *Any*. Con solo el Pass de protocolo IP, el TCP pasaba pero el ping no.
   - **Save**.
5. Esperar 1-2 minutos a que el firewall esté **In sync** (pestaña *Firewall details* → *Configuration sync state*).
6. Probar desde `Cloud1-WebServer`: `ping -c 4 8.8.8.8` y `curl -I https://aws.amazon.com`.

### Con la CLI

Bloque *TAREA 3* de [`scripts/comandos.sh`](scripts/comandos.sh): dos `replace-route`, `describe-firewall-policy`, `describe-rule-group` y `update-rule-group` con [`scripts/rg-pass.json`](scripts/rg-pass.json).

> Cualquier modificación de una política o de un grupo de reglas necesita el **`UpdateToken`** actual (se obtiene con el `describe-...`). Es un control de concurrencia para que dos personas no se pisen los cambios.

---

## Tarea 4 - Migrar la regla de Suricata a Network Firewall (60 puntos)

### Qué pide

Crear un **grupo de reglas compatible con Suricata**, asociarlo a `Inspection-NFW` con la misma regla de bloqueo de amazon.com por HTTP, y que **el resto del tráfico siga pasando**.

### Cómo pensarlo

Network Firewall entiende reglas Suricata, así que la regla se copia tal cual. La parte difícil es **el orden de evaluación**:

- Por defecto, la política usa **action order**: las reglas no se evalúan por su posición, sino por su acción, en este orden: **pass → drop → reject → alert**.
- Si se deja el grupo de la Tarea 3 (`pass ip any any`), ese PASS gana al DROP y **amazon.com pasaría**.
- Solución: la política se queda **solo con el grupo nuevo**. Lo que no coincide con ninguna regla stateful, en *action order*, **pasa por defecto**. Así se cumple "el resto del tráfico sigue pasando".

Detalle importante: la regla usa `any` como origen y no `$HOME_NET`. En Network Firewall, `$HOME_NET` vale por defecto **el CIDR de la VPC del firewall** (10.0.0.0/24), y el tráfico viene de Cloud1 (10.0.1.0/24), así que la regla no coincidiría.

### Paso a paso en la consola

1. **Network Firewall** → **Network Firewall rule groups** → **Create rule group**:
   - **Type:** *Stateful rule group* → **Format:** *Suricata compatible rule string*.
   - **Name:** `Inspection-Suricata-IPS-Rule-Group` → **Capacity:** `100`.
   - **Rule order:** *Action order* (el de por defecto).
   - **Suricata compatible rules:** pegar el contenido de [`scripts/amazon.rules`](scripts/amazon.rules).
   - **Create rule group**.
2. **Firewall policies** → `Inspection-NFW-Policy` → sección **Stateful rule groups**:
   - **Actions** → **Add unmanaged stateful rule groups** → marcar el grupo nuevo → **Add**.
   - Seleccionar `Inspection-Block-All-Rule-Group` → **Actions** → **Disassociate**.
3. Esperar a que el firewall esté **In sync** y probar desde la web: `http://amazon.com` bloqueado; `http://www.amazon.com`, `https://amazon.com` y `ping 8.8.8.8` funcionan.

### Con la CLI

Bloque *TAREA 4* de [`scripts/comandos.sh`](scripts/comandos.sh): `create-rule-group --rules file://amazon.rules` y `update-firewall-policy` con [`scripts/policy.json`](scripts/policy.json).

---

## Errores típicos

| Síntoma | Causa | Solución |
|:--|:--|:--|
| El ping no sale de Cloud1 | Falta la ruta de la subred del TGW en Perimeter | `0.0.0.0/0 → GWLBe` en Perim-Priv-TGW-RT |
| Salen paquetes pero no vuelven | Tráfico asimétrico: la vuelta no pasa por el firewall | `10.0.1.0/24 → GWLBe` en Perim-Pub-RT |
| La regla `drop` no bloquea | Suricata no está en marcha (reinicio fallido + `--queue-bypass`) | Arrancarla a mano y comprobar el log |
| Con Network Firewall no pasa nada | La política tenía DROP de todo | Cambiar a PASS (IP + ICMP) |
| TCP sí, ping no | El PASS de protocolo IP no cubría ICMP | Regla PASS específica para ICMP |
| amazon.com no se bloquea en Network Firewall | El PASS de todo se evalúa antes que el DROP (action order) | Quitar el grupo del PASS de la política |
| La regla no coincide con nada | Se usó `$HOME_NET`, que es el CIDR de la VPC del firewall | Usar `any` o definir `HOME_NET` |
| El cambio de reglas "no se aplica" | El endpoint aún no se ha sincronizado | Esperar a *In sync* |

## Preguntas de repaso

<details>
<summary>¿Qué diferencia hay entre el GWLB, el endpoint service y el GWLB endpoint? ¿Dónde está cada uno?</summary>

El **GWLB** y su target group (los appliances) están en la VPC de inspección. El GWLB se publica como **endpoint service** en esa misma VPC. En la VPC cuyo tráfico se quiere inspeccionar (aquí, Perimeter) se crea un **GWLB endpoint**, que es el destino que se pone en las rutas. El tráfico viaja del endpoint al GWLB encapsulado en GENEVE.
</details>

<details>
<summary>¿Por qué la ruta de vuelta va en la tabla de la subred pública (la del NAT)?</summary>

La respuesta de Internet entra por el IGW hasta el NAT Gateway, que deshace la traducción y la reenvía hacia 10.0.1.x. Esa decisión la toma la tabla de rutas de la subred del NAT (Perim-Pub-RT). Si ahí `10.0.1.0/24` no apunta al endpoint, la vuelta se salta el firewall, y un firewall con estado descarta las respuestas de conexiones que no ha visto salir.
</details>

<details>
<summary>¿Qué acciones tiene una regla de Suricata y qué diferencia hay entre drop y reject?</summary>

`alert` (avisa y deja pasar), `pass` (deja pasar sin seguir evaluando), `drop` (descarta el paquete en silencio) y `reject` (descarta y además avisa al origen con un TCP RST o un ICMP unreachable). `drop` y `reject` solo bloquean de verdad en modo IPS.
</details>

<details>
<summary>¿Por qué la regla no bloquea https://amazon.com y cómo se bloquearía?</summary>

Con HTTPS, la cabecera Host va dentro del túnel TLS y Suricata no la ve. El nombre del dominio solo aparece en el **SNI** del saludo TLS, así que habría que usar una regla `tls` con `tls.sni; content:"amazon.com"; startswith; endswith;`.
</details>

<details>
<summary>¿Qué diferencia hay entre action order y strict order en Network Firewall?</summary>

En **action order** (el de por defecto), las reglas se evalúan según su acción, en el orden pass → drop → reject → alert, da igual en qué posición estén; lo que no coincide con nada, pasa. En **strict order** se evalúan en el orden en que están (prioridad del grupo y orden dentro del grupo), y hay una *default action* configurable para lo que no coincide (por ejemplo, `aws:drop_established`).
</details>

<details>
<summary>¿Qué ventajas tiene Network Firewall frente a Suricata en EC2?</summary>

Es gestionado (sin parches ni sistema operativo que mantener), tiene alta disponibilidad dentro de cada AZ, escala solo, se integra con CloudWatch, S3 y Kinesis para los logs, y usa el mismo formato de reglas. Para ir a multi-AZ basta con una subred de firewall y una ruta por AZ, sin desplegar más instancias.
</details>

<details>
<summary>¿Qué es el appliance mode de un attachment de TGW?</summary>

Hace que el TGW mande los dos sentidos de una conexión por la **misma AZ** de la VPC de inspección. Si los appliances están en varias AZ y no se activa, la ida y la vuelta pueden ir por AZ distintas (tráfico asimétrico) y el firewall descarta las respuestas.
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 4 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Reconocimiento y solución por CLI de las 4 tareas |
| [`scripts/ssm-ejecutar.sh`](scripts/ssm-ejecutar.sh) | Ejecutar comandos en las instancias por Session Manager |
| [`scripts/suricata.rules`](scripts/suricata.rules) | Reglas finales de Suricata (Tarea 2) |
| [`scripts/rg-pass.json`](scripts/rg-pass.json) | Grupo de reglas PASS de IP + ICMP (Tarea 3) |
| [`scripts/amazon.rules`](scripts/amazon.rules) | Regla Suricata para Network Firewall (Tarea 4) |
| [`scripts/policy.json`](scripts/policy.json) | Política del firewall con solo el grupo nuevo (Tarea 4) |

---

[Volver al índice del Jam](../README.md)
