#!/usr/bin/env bash
# Comandos ejecutados dentro de la instancia Lab como ec2-user (tareas 4, 5 y 6 del laboratorio)

# Tarea 4: sistema de archivos ext3 en el volumen nuevo (/dev/sdb)
df -h
sudo mkfs -t ext3 /dev/sdb
sudo mkdir /mnt/data-store
sudo mount /dev/sdb /mnt/data-store
echo "/dev/sdb   /mnt/data-store ext3 defaults,noatime 1 2" | sudo tee -a /etc/fstab
cat /etc/fstab
df -h
sudo sh -c "echo some text has been written > /mnt/data-store/file.txt"
cat /mnt/data-store/file.txt

# Tarea 5: después de crear el snapshot, se borra el fichero
sync                       # antes del snapshot, para que lo escrito esté en disco
sudo rm /mnt/data-store/file.txt
ls /mnt/data-store/

# Tarea 6: montar el volumen restaurado desde el snapshot (/dev/sdc)
sudo mkdir /mnt/data-store2
sudo mount /dev/sdc /mnt/data-store2
ls /mnt/data-store2/       # vuelve a aparecer file.txt
