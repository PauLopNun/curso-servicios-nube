# Práctica 2 - Estrategia Green/Blue - Canary con Elastic Load Balancer

Enunciado completo: [`material/enunciado-elb-blue-green-canary.pdf`](material/enunciado-elb-blue-green-canary.pdf)

## Resumen

Una aplicación web sencilla se mejora cambiando el color de fondo. Para desplegar la versión nueva sin cortes se usa un balanceador de carga (ELB) y las metodologías Green/Blue y Canary.

## Entorno

- Dos instancias EC2 con un servidor web y una página que muestra el hostname: **blue (servidor1)** y **green (servidor2)**.
- Grupo de seguridad con SSH y HTTP, par de claves `vockey`.
- Comprobar con el DNS público de cada instancia que la página carga.

## Balanceador

- Balanceador de carga de red con un grupo de seguridad que permita el puerto 80.
- Grupo de destino de tipo instancia, TCP 80, en la VPC de las instancias y con las comprobaciones de estado por defecto.
- Registrar al principio solo una instancia y sustituirla después por la otra, manteniendo la antigua por si hay que volver atrás.

## Actividad

- Crea un balanceador de carga en el cual se muestre primero la instancia blue y luego la instancia green.
- Crea el balanceador también empleando la CLI.
