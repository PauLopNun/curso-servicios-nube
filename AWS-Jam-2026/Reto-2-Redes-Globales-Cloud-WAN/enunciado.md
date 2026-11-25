# Enunciado - Reto 2: ¡Dijeron que la creación de redes globales es fácil!

## Visión general

Te acaban de contratar en Nice and Simple Company, una cadena de tiendas global que lo tiene todo en AWS. En Nice and Simple todo tiene que ser sencillo, y como nuevo ingeniero de red de AWS tienes que conseguir que la red global esté a la altura del lema.

Tu jefa estuvo en re:Invent 2021 y oyó hablar de un servicio nuevo que simplifica mucho las redes globales. Empezó una prueba de concepto con AWS Cloud WAN, y la dirección está muy ilusionada con ella.

La prueba consiste en conectar 3 VPC nuevas (Prod, Shared y NonProd) en una sola región, entre ellas y con las oficinas on-prem, usando solo AWS Cloud WAN y una conexión Site-to-Site VPN. Si sale bien, se desplegará en varias regiones y sustituirá la arquitectura actual de Transit Gateways con peering.

**Misión:** tu jefa cayó enferma de COVID la semana pasada, antes de terminar la prueba, pero antes de irse dejó apuntados en JIRA todos los fallos que había visto. Ahora te toca resolverlos, terminar la prueba de concepto y conseguir que la red funcione bien. El enunciado incluye el diagrama de red de la página de Confluence de la prueba.

En todas las tareas, el ingeniero de on-prem asegura que ha configurado bien el router (CGW) siguiendo las instrucciones de AWS, así que el problema está en AWS. **Solo se puede usar AWS Cloud WAN para arreglarlo.** No hay que cambiar nada en la instancia del CGW: solo se usa para comprobar.

Comprobación (en la EC2 `OnPremCGW-jam-cloudwan...`, por Session Manager):

```bash
sudo bash
vtysh
sh ip route bgp
# o directamente: sudo vtysh -c "sh ip route bgp"
```

Las rutas tardan varios minutos en propagarse entre los componentes de red: hay que esperar al menos 5 minutos después de cada cambio.

## Tarea 1 - [JIRA-282] No se ven rutas BGP en el CGW

El ingeniero de on-prem ha seguido todas las instrucciones de AWS para configurar el CGW, pero no se anuncia ninguna ruta BGP.

**Tarea:** conseguir que las rutas de la VPC de Shared Services (el enunciado pone `10.0.3.0/16`, pero el rango real es `10.3.0.0/16`) se anuncien al CGW.

**Validación:** `sh ip route bgp` devuelve una ruta BGP, por ejemplo:

```text
B>* 10.3.0.0/16 [20/100] via 169.254.100.1, vti11, 00:05:00
```

## Tarea 2 - [JIRA-534] Las VPC de Non Prod y Prod no son accesibles desde on-prem (80 puntos)

Ahora que BGP anuncia la ruta de Shared Services, deberían llegar también las de Non Prod y Prod.

**Tarea:** arreglar la red para que el CGW reciba por BGP las rutas de las tres VPC: Non Prod (`10.1.0.0/16`), Prod (`10.0.0.0/16`) y Shared (`10.3.0.0/16`).

**Validación:** `sh ip route bgp` devuelve las tres rutas.

## Tarea 3 - [JIRA-787] Las VPC conectadas al Transit Gateway no son accesibles desde on-prem (40 puntos)

La prueba de concepto va bien y la dirección quiere demostrar que se puede migrar desde la red actual con Transit Gateway. El siguiente paso es conectar las VPC Non Prod reales (conectadas al TGW existente) a la core network de Cloud WAN, para que las oficinas on-prem lleguen por la VPN a las instancias de la VPC TGW Non Prod.

**Tarea:** modificar la red de AWS para que las rutas de la VPC TGW Non Prod se anuncien por BGP al CGW. Solo se puede modificar AWS Cloud WAN; la consola de Transit Gateway se puede usar para revisar y diagnosticar.

**Validación:** `sh ip route bgp` devuelve las CUATRO rutas, incluida `192.168.0.0/16`.
