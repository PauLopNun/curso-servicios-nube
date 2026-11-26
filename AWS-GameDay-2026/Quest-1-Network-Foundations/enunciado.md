# Enunciado - Quest 1: Network Foundations

Región: us-east-1 · Dificultad: nivel 400 · Tiempo medio: 60 minutos.

Casos de uso: salida a Internet centralizada, infraestructura de red base y enrutamiento entre VPC. Servicios: Amazon VPC IP Address Manager (IPAM), AWS Transit Gateway y Amazon VPC.

## Visión general

Unicorn.Rentals empieza su transformación digital y va a migrar sus primeras cargas a la nube. Antes necesita una *landing zone* sólida, y una landing zone no está completa sin unos cimientos de red.

## Tarea 1 - Planificación de direcciones IP

Unicorn.Rentals tiene que poder planificar, controlar y gestionar su espacio de direcciones IP para crecer sin quedarse sin direcciones.

Un compañero ha elegido **10.0.0.0/8** para el entorno de AWS. Se planifican tres entornos (producción, no producción y servicios compartidos), los tres en **us-east-1**. El compañero preparó este esquema (en el reto venía en un diagrama, *IPAM Hierarchy Diagram*):

- **us-east-1** necesita 65.536 direcciones IP más un **35 %** de margen para crecer.
- **Producción** y **no producción**: 8.192 direcciones IP cada uno.
  - Cada asignación: como máximo 512 IP y como mínimo 128.
  - Asignación por defecto: 256 IP.
- **Servicios compartidos**: 1.024 direcciones IP.
  - Cada asignación: como máximo 256 IP y como mínimo 32.
  - Asignación por defecto: 128 IP.

El compañero no ha llegado a crear el IPAM que implementa este esquema. Hay que crearlo: se usará después para dar automáticamente los rangos de IP a las VPC cuando se despliegue la red base.

**Validación:** escribir en las cajas el **ID del pool top-level** y después el **ID del pool regional de us-east-1** (formato `ipam-pool-0123456789abcdef0`).

## Tarea 2 - Desplegar la infraestructura de red base

Para ahorrar tiempo, otro compañero ha preparado una plantilla de CloudFormation que despliega la red base. La plantilla recibe como parámetros los **IDs de los pools de IPAM**, así CloudFormation obtiene automáticamente los rangos de IP de las VPC.

La plantilla despliega la red según el diagrama del reto (3 VPC, subredes, tablas de rutas, Internet Gateway, NAT Gateway y Transit Gateway). **No** crea los attachments del Transit Gateway ni configura el enrutamiento de las VPC ni del TGW.

Nota: el stack puede tardar hasta 5 minutos.

**Validación:** automática, cuando el stack está desplegado.

## Tarea 3 - Configuración del enrutamiento

Con la red base desplegada, hay que configurar las rutas para que:

- Las VPC de producción, no producción y servicios compartidos se puedan comunicar entre sí a través del **Transit Gateway (TGW)**.
- Las EC2 de las subredes privadas de la VPC de servicios compartidos salgan a Internet por el **NAT Gateway** de su subred pública.
- **Todo** el tráfico a Internet de producción y no producción salga por la VPC de servicios compartidos (patrón de **salida a Internet centralizada**).

Las subredes, tablas de rutas y gateways ya están desplegados. Solo hay que configurar las rutas.

Se pueden consultar las buenas prácticas de diseño de Transit Gateway. Las decisiones de este reto pueden influir en la dificultad de retos posteriores: por ejemplo, podría hacer falta **filtrar o inspeccionar el tráfico entre producción y no producción con AWS Network Firewall** en la VPC de servicios compartidos, así que conviene diseñar pensando en ese futuro.

**Validación:** automática cada 2 minutos. Comprueba 9 caminos:

1. Producción → no producción por el TGW.
2. Producción → servicios compartidos por el TGW.
3. No producción → producción por el TGW.
4. No producción → servicios compartidos por el TGW.
5. Servicios compartidos → producción por el TGW.
6. Servicios compartidos → no producción por el TGW.
7. Servicios compartidos → Internet por su IGW.
8. Producción → Internet por el TGW.
9. No producción → Internet por el TGW.
