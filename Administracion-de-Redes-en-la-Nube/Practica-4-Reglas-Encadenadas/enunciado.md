# Práctica 4: Reglas encadenadas

- Curso: Administración de redes en la nube
- Tarea en Aules: aws2 13 reglas encadenadas
- Documento original: `Materiales/aws2_13reglas_enca.pdf` (local)

Lanzar varias instancias EC2 de forma que solo se pueda acceder desde fuera a una de ellas (servidor bastión) y al resto únicamente desde la anterior, encadenando los grupos de seguridad.

## Escenario

| Recurso | Direccionamiento |
|:--|:--|
| VPC | `10.0.0.0/16` |
| Subred pública | `10.0.1.0/24` (us-east-1a) con Internet Gateway |
| Bastión (`SSHServer`) | `10.0.1.20`, grupo `gs_bastion` (SSH desde Internet) |
| Servidor de aplicación (`mi_app`) | `10.0.1.30`, grupo `miapp-ape-nombre` |

## Pasos

1. Bastión con el grupo `gs_bastion`, que permite SSH.
2. Grupo `miapp-ape-nombre` en la VPC: HTTPS desde cualquier origen y SSH solo desde `gs_bastion`.
3. Instancia `mi_app`: Ubuntu Server 22.04 LTS (64 bits), `t3.micro`, par de claves nuevo `vockey2`, subred de us-east-1a, IP pública automática, IP privada `10.0.1.30`, perfil `LabInstanceProfile` e IP elástica asociada.
4. Conexión por SSH con reenvío de agente:
   - `eval $(ssh-agent)`
   - `ssh-add labsuser.pem` y `ssh-add vockey2.pem`, comprobando con `ssh-add -l`
   - `ssh -A` al bastión y desde él `ssh ubuntu@10.0.1.30`
   - Comprobar que desde fuera solo se llega al bastión
5. El bastión no guarda `vockey2.pem`, así que quien lo comprometa no puede saltar a la aplicación.

## Actividades

- Capturar todo el proceso de conexión por SSH con reglas encadenadas.
- Permitir el ping a la aplicación solo desde el bastión, no desde otro equipo.
- ¿Se puede encadenar grupos de seguridad entre VPC distintas?
