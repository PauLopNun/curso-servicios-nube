# Enunciado - Reto 3: AWS, ¡ayúdeme a administrar mis firewalls!

Región: us-east-1. A las instancias de prueba se accede por SSM (Session Manager).

## Visión general

Eres consultor de seguridad y tienes experiencia con Suricata IDS/IPS. Instintivamente lanzas una EC2 y configuras Suricata, pero te das cuenta de que tendrás que automatizar sus parches, endurecer el sistema operativo, gestionar el acceso, darle alta disponibilidad... Todo eso es trabajo pesado que no aporta: lo que necesitas es centrarte en las reglas de red. Investigando descubres AWS Network Firewall, un servicio gestionado.

Aun así, el servidor ya está desplegado y Suricata funciona. Primero quieres probar la configuración y después migrar a Network Firewall. En este reto vas a:

1. Completar la configuración actual (basada en EC2) para que el tráfico de salida a Internet pase por la instancia Suricata.
2. Crear una regla de Suricata que demuestre que funciona.
3. Migrar el flujo de tráfico para que pase por AWS Network Firewall en lugar de por Suricata.
4. Migrar la regla de Suricata a AWS Network Firewall.

El enunciado incluye dos diagramas: el modelo de firewall centralizado con Suricata (tareas 1 y 2) y el modelo objetivo con AWS Network Firewall (tareas 3 y 4).

## Tarea 1 - Completar el despliegue

Desplegaste la infraestructura hace unas semanas, pero no llegaste a validarla. Hoy, al revisarla, ves que no funciona como esperabas.

- Conectarse por SSM a `Cloud1-Priv-Web` y hacer `ping 8.8.8.8`. El ping falla.
- **Tarea:** revisar el despliegue e identificar, desplegar o configurar lo que falte para poder hacer ping a 8.8.8.8 desde `Cloud1-Priv-Web`.

Importante: hay componentes de las tareas 3 y 4 ya desplegados. En concreto, un VPC endpoint de tipo GatewayLoadBalancer con el tag `AWSNetworkFirewallManaged:true`, que pertenece a AWS Network Firewall.

## Tarea 2 - Crear una regla de Suricata

El tráfico ya pasa por Suricata. Ahora quieres confirmar que lo inspecciona y que puedes controlar el flujo con reglas. Ya hay una regla que genera una alerta cuando se accede a amazon.com por HTTP.

- Reglas: `/var/lib/suricata/rules/suricata.rules`
- Logs: `/var/log/suricata/fast.log`

**Tarea:** modificar la regla para **descartar (drop)** todo el tráfico HTTP (no HTTPS) hacia `amazon.com` (no `www.amazon.com`).

## Tarea 3 - Migrar a AWS Network Firewall

Tu responsable está contenta con el resultado, pero el entorno tendrá que ser más resiliente y ofrecer dos o tres zonas de disponibilidad, y eso significa más instancias de Suricata que mantener. Antes de pasar a multi-AZ decides probar AWS Network Firewall.

**Tarea:** completar la configuración de red necesaria para migrar de la solución actual (Gateway Load Balancer con instancias Suricata) a AWS Network Firewall.

**Validación:** automática, cuando el tráfico pasa por AWS Network Firewall y llega a su destino.

## Tarea 4 - Migrar la regla de Suricata a un grupo de reglas de Network Firewall (60 puntos)

**Tarea:**

- Crear y asociar a `Inspection-NFW` un grupo de reglas IPS compatible con Suricata.
- Añadir la regla que estaba en la EC2: descartar todo el tráfico HTTP (no HTTPS) hacia `amazon.com` (no `www.amazon.com`).
- Asegurarse de que el resto del tráfico que pasa por el firewall se sigue permitiendo.
