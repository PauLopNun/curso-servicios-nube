<div align="center">

# Reto 2 - ¡Dijeron que la creación de redes globales es fácil!

![Cloud WAN](https://img.shields.io/badge/AWS-Cloud%20WAN-8C4FFF?style=for-the-badge&logoColor=white)
![VPN](https://img.shields.io/badge/Site--to--Site-VPN-8C4FFF?style=for-the-badge&logoColor=white)
![Transit Gateway](https://img.shields.io/badge/Transit-Gateway-8C4FFF?style=for-the-badge&logoColor=white)
![BGP](https://img.shields.io/badge/BGP-FRRouting-232F3E?style=for-the-badge&logoColor=white)

**Nombre en el Jam:** *¡Dijeron que la creación de redes globales es fácil!* · 3 tareas · AWS Cloud WAN

![Propuesta](https://img.shields.io/badge/Soluci%C3%B3n%20propuesta-dbab09?style=flat-square)

</div>

> Este reto lo resolvió otro miembro del equipo. Aquí están los enunciados, cómo razonarlos y la solución esperada, explicada paso a paso. Al practicarlo, hay que confirmar los nombres reales de segmentos y attachments en la política del laboratorio.

## De qué va

Nice and Simple Company es una cadena de tiendas global y todo tiene que ser "sencillo". Tu jefa empezó una prueba de concepto con **AWS Cloud WAN**: una red global gestionada desde una **política** en JSON. Las oficinas on-prem se conectan por **Site-to-Site VPN**. El ingeniero de on-prem asegura que su router (el CGW) está bien configurado, así que **todo se arregla en Cloud WAN**. El CGW solo se usa para comprobar.

## Arquitectura

```text
                         AWS Cloud WAN - core network (edge location us-west-2)
              ┌───────────────────────────────────────────────────────────────────┐
              │ segmento hybrid ◄──share──► sharedservices   prod   nonprod        │
 On-prem      │   ▲ attachment VPN            ▲ VPC 10.3      ▲ VPC   ▲ VPC 10.1   │
 CGW (EC2) ═══╪═══╝ (túneles IPsec, BGP)       │               │ 10.0  │          │
 FRRouting    │                                                        ▲          │
 169.254.x.x  │                                     attachment de tabla de rutas  │
              └────────────────────────────────────────────── de TGW (Tarea 3) ───┘
                                                                         │ peering
                                                    Transit Gateway ── VPC TGW Non Prod 192.168.0.0/16
```

## Conceptos que hay que tener claros

| Concepto | Explicación corta |
|:--|:--|
| **Core network** | La red global de Cloud WAN. Se define entera en un **documento de política** JSON versionado. |
| **Segmento** | Una red aislada dentro de la core network (como una tabla de rutas global). Por defecto, **los segmentos no se ven entre sí**. |
| **Attachment** | Lo que se conecta a la core network: VPC, VPN, Connect, peering de TGW o tabla de rutas de TGW. |
| **attachment-policies** | Reglas de la política que deciden **a qué segmento va cada attachment**, normalmente según sus tags o su tipo. |
| **segment-actions: share** | Permite que dos segmentos se intercambien rutas. Sin un share, el segmento de la VPN no aprende las rutas de las VPC. |
| **Change set / execute** | Editar la política crea una **versión nueva**. No tiene efecto hasta que se **ejecuta** su *change set*. |
| **CGW + BGP** | El router on-prem (aquí simulado con FRRouting) habla BGP con AWS por los túneles. Las IP de los túneles son de `169.254.x.x` (link-local). |

## Cómo se comprueba (en las tres tareas)

En la EC2 `OnPremCGW-jam-cloudwan...`, por **Session Manager**:

```bash
sudo vtysh -c "sh ip route bgp"      # rutas aprendidas por BGP
sudo vtysh -c "sh ip bgp summary"    # vecinos BGP: tienen que estar Established
```

Los cambios en Cloud WAN tardan **5 minutos o más** en llegar al CGW.

---

## Tarea 1 - [JIRA-282] No se ven rutas BGP en el CGW

### Qué pide

`sh ip route bgp` no devuelve nada. Hay que conseguir que se anuncie **al menos la VPC de Shared Services** (`10.3.0.0/16`).

### Cómo pensarlo

Para que una ruta de una VPC llegue al CGW, se tienen que cumplir **cuatro condiciones**. Hay que revisarlas en orden:

1. El attachment de la **VPN** existe y está **Available**, no `Pending acceptance`.
2. La VPN ha caído en el **segmento correcto** (el híbrido), según las `attachment-policies`.
3. La VPC de Shared Services ha caído en su segmento y está Available.
4. Hay un **share** entre el segmento de la VPN y el de Shared Services.

La causa más probable es una de dos: el attachment de la VPN está pendiente de aceptar, o falta el share entre segmentos.

### Paso a paso en la consola

1. **VPC** → **Network Manager** (o buscar *Cloud WAN*) → **Global networks** → la red global → **Core network**.
2. Pestaña **Attachments**: comprobar el **estado** y el **segmento** de cada attachment.
   - Si la VPN está en **Pending acceptance**: seleccionarla → **Accept**.
   - Si está en un segmento equivocado: revisar sus **tags** y las `attachment-policies`.
3. Pestaña **Policy versions** → la versión **LIVE** → **Edit**:
   - En **Segment actions**, añadir una acción **Share** desde el segmento híbrido (el de la VPN) hacia el de Shared Services. En JSON, ver [`scripts/core-network-policy-ejemplo.json`](scripts/core-network-policy-ejemplo.json).
   - **Create policy**.
4. Volver a **Policy versions**: la versión nueva aparece como *Ready to execute* → **View or apply change set** → revisar los cambios → **Apply changes**.
5. Esperar 5 minutos o más y comprobar en el CGW: `B>* 10.3.0.0/16 [20/100] via 169.254.100.1, vti11`.

### Con la CLI

Bloques *1*, *2* y *3* de [`scripts/comandos.sh`](scripts/comandos.sh): `list-attachments`, `get-core-network-policy`, `accept-attachment`, `put-core-network-policy` y `execute-core-network-change-set`.

---

## Tarea 2 - [JIRA-534] Las VPC de Prod y Non Prod no llegan a on-prem

### Qué pide

Ya se ve Shared Services, pero faltan **Prod** (`10.0.0.0/16`) y **Non Prod** (`10.1.0.0/16`). Tienen que salir las 3 rutas.

### Cómo pensarlo

Es el mismo mecanismo que en la Tarea 1: si el segmento de la VPN solo comparte con Shared Services, solo aprende esas rutas. Hay que **ampliar el share** a `prod` y `nonprod`. También hay que comprobar que las dos VPC tengan su attachment *Available* en su segmento: si alguna tiene un tag que no coincide con ninguna regla, no entra en ningún segmento.

```json
"segment-actions": [
  { "action": "share", "mode": "attachment-route", "segment": "hybrid",
    "share-with": ["sharedservices", "prod", "nonprod"] }
]
```

### Paso a paso en la consola

1. **Core network** → **Attachments**: comprobar que las VPC de Prod y Non Prod estén *Available* y en su segmento.
2. **Policy versions** → editar la LIVE → en el share del segmento híbrido, añadir `prod` y `nonprod` a **Share with** → **Create policy**.
3. **Apply changes** en el *change set* de la versión nueva.
4. Esperar y comprobar en el CGW que salen `10.0.0.0/16`, `10.1.0.0/16` y `10.3.0.0/16`.

---

## Tarea 3 - [JIRA-787] La VPC del Transit Gateway no llega a on-prem (40 puntos)

### Qué pide

La empresa tiene una red antigua con un **Transit Gateway**, al que está conectada la VPC *TGW Non Prod*. Hay que integrarla en Cloud WAN para que su ruta `192.168.0.0/16` llegue al CGW. Al final tienen que salir 4 rutas. Solo se puede **modificar Cloud WAN**; la consola de TGW se usa para mirar.

### Cómo pensarlo

Cloud WAN se conecta con un TGW en dos pasos:

1. **Peering** entre la core network y el TGW: es el "cable".
2. **Attachment de tabla de rutas de TGW** sobre ese peering. Dice qué tabla del TGW se intercambia con qué segmento de Cloud WAN.

Ese attachment tiene que caer en un segmento que comparta con el de la VPN. Si va a `nonprod`, el share de la Tarea 2 ya lo cubre. Además, en el TGW la VPC tiene que estar **propagada** en la tabla elegida: si no, el TGW no anuncia su ruta.

### Paso a paso en la consola

1. **Core network** → **Peerings**: si no hay peering con el TGW, **Create peering** → *Transit gateway* → elegir el TGW → **Create**.
2. Esperar a que esté *Available* → **Attachments** → **Create attachment** → **Attachment type:** *Transit gateway route table*:
   - **Peering:** el del paso 1.
   - **Transit gateway route table:** la tabla del TGW en la que está la VPC Non Prod.
   - **Tags:** el que use la regla de `attachment-policies` para `nonprod` (por ejemplo, `segment = nonprod`).
   - **Create attachment** y aceptarlo si queda *Pending acceptance*.
3. **VPC** → **Transit gateway route tables** (solo mirar) → la tabla elegida → **Propagations**: la VPC TGW Non Prod tiene que aparecer. En **Routes**, tiene que estar `192.168.0.0/16`.
4. Si hace falta, ajustar la política (regla para el tag o share) y aplicar el *change set*.
5. Comprobar en el CGW que salen las 4 rutas, incluida `192.168.0.0/16`.

### Con la CLI

Bloque *4* de [`scripts/comandos.sh`](scripts/comandos.sh): `create-transit-gateway-peering` y `create-transit-gateway-route-table-attachment`.

---

## Errores típicos

| Síntoma | Causa probable | Solución |
|:--|:--|:--|
| El CGW no recibe ninguna ruta | Attachment de VPN pendiente, o sin share | Aceptar y añadir un share |
| Editada la política, pero nada cambia | No se ha ejecutado el *change set* | **Apply changes** |
| Una VPC no se anuncia | Su attachment no ha caído en ningún segmento (tag sin regla) | Corregir el tag o añadir una regla |
| La ruta del TGW no aparece | La VPC no está propagada en la tabla del TGW, o el attachment está en otro segmento | Revisar las propagaciones y el segmento del attachment |
| "Lo he cambiado hace un minuto" | La propagación tarda | Esperar 5 minutos o más |

## Preguntas de repaso

<details>
<summary>¿Qué es un segmento de Cloud WAN y cómo se comunican dos segmentos?</summary>

Es un dominio de enrutamiento aislado que existe en todas las edge locations donde se define. Por defecto, los attachments de un segmento solo se ven entre sí. Para que dos segmentos intercambien rutas, se añade en `segment-actions` una acción `share` (o rutas estáticas con `create-route`).
</details>

<details>
<summary>¿Cómo decide Cloud WAN en qué segmento entra un attachment?</summary>

Con las `attachment-policies`: reglas numeradas que se evalúan por orden y comprueban condiciones (tags, tipo de attachment, cuenta, región...). La primera que coincide asigna el segmento. Si el segmento tiene `require-attachment-acceptance: true`, además hay que aceptarlo a mano.
</details>

<details>
<summary>¿Por qué hay que ejecutar el change set después de editar la política?</summary>

Cada edición genera una versión nueva de la política y AWS calcula qué cambios supondría (el *change set*). No se aplica sola, para evitar cambios accidentales en una red global. Hay que revisarla y ejecutarla, y a partir de ahí esa versión pasa a ser la LIVE.
</details>

<details>
<summary>¿Cómo se integra un Transit Gateway existente con Cloud WAN?</summary>

Con un **peering de TGW** entre la core network y el TGW (los dos en la misma región) y, encima, un **attachment de tabla de rutas de TGW** que asocia una tabla del TGW a un segmento de Cloud WAN. Las rutas se intercambian por BGP de forma dinámica.
</details>

<details>
<summary>¿Por qué las IP del túnel de la VPN son de 169.254.x.x?</summary>

Son direcciones **link-local**, que solo existen dentro de cada túnel IPsec. Se usan para la sesión BGP entre el CGW y AWS, y no chocan con ninguna red real de la empresa ni de las VPC.
</details>

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`enunciado.md`](enunciado.md) | Enunciado de las 3 tareas |
| [`scripts/comandos.sh`](scripts/comandos.sh) | Comandos de investigación y solución propuesta |
| [`scripts/core-network-policy-ejemplo.json`](scripts/core-network-policy-ejemplo.json) | Ejemplo de política con segmentos, reglas y share |

---

[Volver al índice del Jam](../README.md)
