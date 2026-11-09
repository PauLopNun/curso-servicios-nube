<div align="center">

# Práctica 2 - Estrategia Blue/Green y Canary con ELB

![ELB](https://img.shields.io/badge/AWS-Elastic%20Load%20Balancing-8C4FFF?style=for-the-badge&logoColor=white)
![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-AWS%20CLI-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Python-Boto3-3776AB?style=for-the-badge&logo=python&logoColor=white)

**UP de Despliegue de servicios administrados en la nube**

<img src="https://skillicons.dev/icons?i=aws,bash,python,linux" />

</div>

## Qué se pide

El enunciado ([PDF](material/enunciado-elb-blue-green-canary.pdf), resumen en [`enunciado.md`](enunciado.md)) parte de una web sencilla con dos versiones, una con fondo azul y otra con fondo verde. Para pasar de una a otra sin cortes se usa un balanceador de carga:

1. Entorno: dos instancias EC2 con servidor web, **blue (servidor1)** y **green (servidor2)**, con un grupo de seguridad que permite SSH y HTTP y el par de claves `vockey`.
2. Balanceador de carga de red con su grupo de seguridad (puerto 80) y un grupo de destino TCP 80 de tipo instancia.
3. Actividad: que el balanceador muestre primero la instancia blue y después la green.
4. Actividad: crear el balanceador también con la CLI.

## Qué se ha hecho

| Paso | Cómo | Resultado |
|:--|:--|:--|
| Entorno | [`01-crear-entorno.sh`](scripts/01-crear-entorno.sh) + [`userdata.sh`](scripts/userdata.sh) | `blue` en us-east-1a y `green` en us-east-1b, Apache con una página que muestra la versión y el hostname |
| NLB con blue | [`02-nlb-blue-green.sh crear`](scripts/02-nlb-blue-green.sh) | `nlb-pln` + `tar-pln-nlb` con solo blue registrada: 20 de 20 peticiones a blue |
| Blue/Green | `02-nlb-blue-green.sh green` | Se registra green, se espera a que esté *healthy* y se retira blue: 20 de 20 peticiones a green |
| Vuelta atrás | `02-nlb-blue-green.sh blue` | Blue sigue encendida, así que se recupera en cuanto pasa la comprobación de estado |
| Canary (ampliación) | [`03-alb-canary.sh`](scripts/03-alb-canary.sh) | `alb-pln` con dos grupos de destino (`tar-pln-blue`, `tar-pln-green`) y reparto por pesos |
| Programa en Boto3 | [`elb_blue_green.py`](scripts/elb_blue_green.py) | Hace todo lo anterior en un solo programa (`todo`) o por pasos. Ejecución completa en [`05-boto3-todo.txt`](evidencias/05-boto3-todo.txt): blue 20/20, green 20/20 y Canary 38/2, 19/21 y 0/40 |
| Limpieza | [`04-limpiar.sh`](scripts/04-limpiar.sh) / `elb_blue_green.py limpiar` | Borra balanceadores, grupos de destino, instancias y grupos de seguridad |

### Blue/Green frente a Canary

- **Blue/Green** (NLB): las dos versiones están desplegadas a la vez, pero el balanceador solo envía tráfico a una. El cambio es completo y la vuelta atrás es inmediata, porque la versión antigua no se apaga.
- **Canary** (ALB): el balanceador de red no admite repartir el tráfico por pesos entre grupos de destino, así que para esta parte se usa un balanceador de aplicaciones. La versión nueva recibe primero una parte pequeña del tráfico y se sube poco a poco.

Reparto medido con [`comprobar.sh`](scripts/comprobar.sh) (40 peticiones por paso, [`evidencias/04-alb-canary.txt`](evidencias/04-alb-canary.txt)):

| Pesos blue / green | Respuestas blue | Respuestas green |
|:--|--:|--:|
| 100 / 0 | 20 de 20 | 0 |
| 90 / 10 | 36 | 4 |
| 50 / 50 | 25 | 15 |
| 0 / 100 | 0 | 40 |

## Nombres de los recursos

Todos siguen el formato *tres letras del servicio + iniciales*:

| Recurso | Nombre |
|:--|:--|
| Instancias | `blue`, `green` (como pide el enunciado) |
| Grupos de seguridad | `sec-pln-web`, `sec-pln-nlb`, `sec-pln-alb` |
| Grupos de destino | `tar-pln-nlb`, `tar-pln-blue`, `tar-pln-green` |
| Balanceadores | `nlb-pln`, `alb-pln` |

## Cómo reproducirlo

Con las credenciales del Learner Lab en `~/.aws/credentials`:

```bash
cd scripts
./01-crear-entorno.sh
./02-nlb-blue-green.sh crear       # solo blue
./comprobar.sh http://<dns-del-nlb> 20
./02-nlb-blue-green.sh green       # cambio a green
./03-alb-canary.sh crear           # 100 % blue
./03-alb-canary.sh pesos 90 10     # 10 % a green, y luego 50 50 y 0 100
./04-limpiar.sh
```

Con Boto3 (`pip install boto3`):

```bash
python3 scripts/elb_blue_green.py todo      # todo seguido, con las comprobaciones
python3 scripts/elb_blue_green.py limpiar
```

La variable `INI` cambia el sufijo de los nombres (por defecto `pln`). La prueba completa del programa se hizo con `INI=pln2` para no tocar los recursos creados con la CLI.

En el navegador la conexión se reutiliza y al recargar suele salir la misma versión; para ver el reparto es mejor `comprobar.sh`, que abre una conexión nueva en cada petición.

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`scripts/`](scripts) | Scripts de la CLI y programa en Boto3 |
| [`evidencias/`](evidencias) | Salida de cada script en la ejecución real |
| [`capturas/`](capturas) | Capturas de la consola y del navegador |
| [`entrega/`](entrega) | Documento para entregar en Aules |
| [`material/`](material) | Enunciado en PDF |

---

[Volver a la asignatura](../README.md)
