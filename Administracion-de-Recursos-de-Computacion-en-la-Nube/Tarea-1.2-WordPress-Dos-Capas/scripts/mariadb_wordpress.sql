-- wp-bd: base de datos y usuario de WordPress (dentro de sudo mariadb)
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wpuser'@'172.31.86.209' IDENTIFIED BY '<contraseña>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'172.31.86.209';
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'wpuser'@'172.31.86.209';
