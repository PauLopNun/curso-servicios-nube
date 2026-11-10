# Actividad 4.2: modificación de un volumen EBS

- Módulo: Administración de sistemas y almacenamiento en la nube
- Unidad: UD04 - Servicios de almacenamiento de bloques
- Tipo: tarea guiada por la profesora, sin entregable
- Documento original: [`material/enunciado-modificar-volumen-ebs.pdf`](material/enunciado-modificar-volumen-ebs.pdf) (`CE_ARSN-ASAN-UD02-Act2_2.pdf`)

Ampliar el volumen raíz de una instancia EC2 Linux con la AWS CLI (credenciales del laboratorio en el sistema o CloudShell).

## Pasos

1. Crear una instancia EC2: Amazon Linux, `t3.micro`, clave `vockey`, volumen de 8 GB y perfil de instancia `LabInstanceProfile`
2. Con `aws ec2 describe-instances`, localizar el id del volumen raíz y la zona de disponibilidad
3. Con `aws ec2 describe-volumes`, ver el volumen; dentro de la instancia, `sudo lsblk` y `df -hT`
4. Copia de seguridad: `aws ec2 create-snapshot` y esperar a que esté completa con `aws ec2 describe-snapshots`
5. Ampliar el volumen a 10 GB con `aws ec2 modify-volume` y seguir el estado con `aws ec2 describe-volumes-modifications` hasta `completed`
6. Ampliar la partición y el sistema de archivos:
   - `df -hT` sigue mostrando 8 GB
   - Averiguar si la instancia es Xen o Nitro: `aws ec2 describe-instance-types --instance-type t3.micro --query "InstanceTypes[].Hypervisor"`
   - `sudo growpart /dev/xvda 1` (Xen) o `sudo growpart /dev/nvme0n1 1` (Nitro) y comprobar con `sudo lsblk`
   - `sudo xfs_growfs -d /` (XFS) o `sudo resize2fs /dev/xvda1` (ext4) y comprobar con `df -hT`
7. Borrar el snapshot con `aws ec2 delete-snapshot`

Al terminar, eliminar todos los recursos creados en el laboratorio.
