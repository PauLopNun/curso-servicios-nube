# Laboratorio 4: Working with EBS

- Plataforma: AWS Academy (laboratorio guiado, se corrige con el botón Submit del propio laboratorio)
- Duración aproximada: 30 minutos
- Sin entregable en Aules

Crear un volumen EBS, conectarlo a una instancia, darle un sistema de archivos, hacer un snapshot y restaurarlo en un volumen nuevo.

## Tareas

1. Crear un volumen **My Volume**: gp2, 1 GiB, en la misma zona de disponibilidad que la instancia **Lab**
2. Conectarlo a la instancia Lab como `/dev/sdb`
3. Conectarse a la instancia con Session Manager (`sudo su -l ec2-user`)
4. Crear un sistema de archivos ext3 en `/dev/sdb`, montarlo en `/mnt/data-store`, añadirlo a `/etc/fstab` y escribir `file.txt`
5. Crear el snapshot **My Snapshot** del volumen y, cuando esté completo, borrar `file.txt`
6. Crear el volumen **Restored Volume** a partir del snapshot, conectarlo como `/dev/sdc`, montarlo en `/mnt/data-store2` y comprobar que `file.txt` sigue ahí
