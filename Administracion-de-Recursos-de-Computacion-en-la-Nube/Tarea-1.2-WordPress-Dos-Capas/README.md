<div align="center">

# Tarea 1.2 - WordPress en dos capas

![EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=for-the-badge&logo=apache&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Completado-brightgreen?style=for-the-badge)

**UD01 - Servicios computacionales basados en máquinas virtuales**

</div>

## Objetivo

Desplegar WordPress separando la aplicación y los datos en dos instancias EC2, todo desde la consola y por SSH: una capa web con Apache y PHP accesible a través de una IP elástica, y una capa de datos con MariaDB a la que solo puede llegar la capa web.

## Arquitectura

```text
Internet ──HTTP 80──> wp-web-pln (34.195.127.214, IP elástica) ──3306──> wp-bd-pln (172.31.81.10)
Mi equipo ──SSH 22──> wp-web-pln ──SSH 22 (ProxyJump)──────────────────> wp-bd-pln
```

| Recurso | wp-web-pln | wp-bd-pln |
|:--|:--|:--|
| Tipo / AMI | t3.micro / Ubuntu Server 26.04 LTS | t3.micro / Ubuntu Server 26.04 LTS |
| Subred | us-east-1a (`172.31.80.0/20`) | us-east-1a (`172.31.80.0/20`) |
| IP privada | `172.31.86.209` | `172.31.81.10` (fijada al lanzar) |
| IP pública | `34.195.127.214` (elástica) | automática, inaccesible desde Internet |
| Grupo de seguridad | `wp-web-pln-sg`: HTTP desde 0.0.0.0/0, SSH desde el rango del instituto | `wp-bd-pln-sg`: 3306 y 22 solo desde `wp-web-pln-sg` |
| Software | Apache, PHP, WordPress (es_ES) | MariaDB |

Todos los recursos llevan las etiquetas `Name`, `Proyecto=UD01`, `Propietario=pln` y `Rol=web|bd`.

## Pasos principales

```bash
# wp-bd: MariaDB escuchando en todas las interfaces
sudo apt update && sudo apt install -y mariadb-server
sudo cp 99-wordpress.cnf /etc/mysql/mariadb.conf.d/ && sudo systemctl restart mariadb
sudo mariadb < mariadb_wordpress.sql

# wp-web: Apache, PHP y WordPress
sudo apt install -y apache2 libapache2-mod-php php-mysql php-curl php-gd \
     php-intl php-mbstring php-xml php-zip php-imagick mariadb-client
mariadb -h 172.31.81.10 -u wpuser -p -e "SELECT USER(), @@hostname;"
cd /tmp && wget https://es.wordpress.org/latest-es_ES.tar.gz
sudo tar xf latest-es_ES.tar.gz -C /var/www && sudo chown -R www-data:www-data /var/www/wordpress
sudo cp wordpress.conf /etc/apache2/sites-available/
sudo a2enmod rewrite && sudo a2dissite 000-default && sudo a2ensite wordpress
sudo apache2ctl configtest && sudo systemctl restart apache2
```

## Ampliación: base de datos en una subred privada

La capa de datos se traslada a una subred privada sin reconstruirla desde cero:

| Recurso | Detalle |
|:--|:--|
| Subred `wp-priv-pln` | `172.31.96.0/24` en us-east-1a |
| Tabla de rutas `wp-priv-pln-rt` | Solo la ruta local, sin salida a Internet |
| AMI `wp-bd-pln-ami` | Imagen de wp-bd-pln con MariaDB y la base de datos |
| Instancia `wp-bdpriv-pln` | Lanzada desde la AMI, sin IP pública, IP `172.31.96.10` |

Solo cambian `DB_HOST` en `wp-config.php` y el `HostName` de `wp-bd` en `~/.ssh/config`. El usuario `wpuser@172.31.86.209` sigue siendo válido porque la capa web no cambia.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/ssh_config`](scripts/ssh_config) | Entradas de `~/.ssh/config` con `ProxyJump` |
| [`scripts/99-wordpress.cnf`](scripts/99-wordpress.cnf) | Configuración propia de MariaDB (`bind-address`) |
| [`scripts/mariadb_wordpress.sql`](scripts/mariadb_wordpress.sql) | Base de datos y usuario `wpuser` con mínimo privilegio |
| [`scripts/wordpress.conf`](scripts/wordpress.conf) | Sitio de Apache para WordPress |
| [`capturas/`](capturas) | Consola de EC2 y VPC, terminal y blog (01-08 tarea, 09-12 ampliación) |
| [`entrega/LopezPau_Tarea1-2.pdf`](entrega/LopezPau_Tarea1-2.pdf) | Documento entregado |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)
