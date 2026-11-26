# Enunciado - Quest 2: Forge the Mythic Bond

Región: us-east-1.

## Bienvenida - ¡Estamos creciendo!

Unicorn.Rentals acaba de comprar Mystique.Rentals, que también está en AWS. Hay que poder usar su famosa aplicación web **MystiqueAI**, pero no como un cliente más: ahora forman parte de nuestro sistema. El problema es que las dos empresas eligieron lo mismo al crear su VPC, así que **los CIDR se solapan**.

El CTO decide y el equipo DevOps lo ejecuta: hay que conseguir que la aplicación **AwesomeUnicorn** (en la VPC de Producción de Unicorn.Rentals) se conecte a **MystiqueAI** (en la VPC de Mystique.Rentals) para añadir funciones de IA al producto. **La conexión tiene que ser privada.**

## Tarea 1 - Conectar Unicorn.Rentals con Mystique.Rentals

El entorno de Mystique.Rentals aparece en la cuenta: una VPC, un Application Load Balancer y la aplicación MystiqueAI en una EC2.

Hay que establecer comunicación privada entre la VPC de Producción de Unicorn.Rentals y la aplicación MystiqueAI. Para no molestar al equipo de Mystique.Rentals, **no se puede borrar ni modificar su VPC**, pero sí se pueden **crear** recursos en ella.

Para probar desde Producción se puede usar la EC2 de AwesomeUnicorn, que ya tiene Systems Manager configurado, con `curl http://www.example.com`.

**Validación:** escribir la **URL del endpoint** que usa AwesomeUnicorn para llegar a MystiqueAI, con el formato `http://abc.xyz.amazonaws.com:80`.

## Tarea 2 - ¡Tenemos un problema! Proteger MystiqueAI

Mystique.Rentals no tiene el mismo nivel de seguridad que nosotros. El CISO ha llamado diez veces: **MystiqueAI es vulnerable a inyección SQL** y puede que la estén atacando.

Hay que **bloquear la inyección SQL** contra MystiqueAI cuanto antes. AWS tiene servicios que lo hacen, e incluso **reglas gestionadas** para ello.

**Validación:** automática.
