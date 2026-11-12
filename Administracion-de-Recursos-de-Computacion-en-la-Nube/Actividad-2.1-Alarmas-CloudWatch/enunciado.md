# Actividad 2.1 - Alarmas de CloudWatch: avisos y recuperación automática

Enunciado completo en [`material/CE_RSN-ARCN-UD02-Act2_1.pdf`](material/CE_RSN-ARCN-UD02-Act2_1.pdf). Resumen:

- **Parte 1.** Lanzar `mon-xx` (Ubuntu 26.04, t3.micro, `vockey`, `LabInstanceProfile`) con el grupo `mon-xx-sg` (SSH y HTTP desde el instituto) y datos de usuario que instalan `stress-ng` y `apache2`.
- **Parte 2.** Consultar métricas de EC2 en la consola y con `list-metrics` / `get-metric-statistics`; activar la monitorización detallada.
- **Parte 3.** Alarma `mon-xx-sistema` sobre `StatusCheckFailed_System` con acción Detener y simulacro con `set-alarm-state`.
- **Parte 4.** Tema SNS `avisos-xx` con suscripción por correo, mensaje de prueba y `mon-xx-sistema` con Recuperar y aviso.
- **Parte 5.** Alarma `mon-xx-cpu` (> 70 %, 3 de 5, 1 minuto) y prueba de carga con `stress-ng`.
- **Parte 6.** Alarma `mon-xx-instancia` sobre `StatusCheckFailed_Instance` con Reiniciar; fallo provocado desactivando `ens5`.
- **Parte 7.** Comprobación de estado de la aplicación `apache-xx` (HTTP 80) y fallo parando Apache.
- **Parte 8.** Panel `panel-xx` con CPU, estado de las alarmas y `StatusCheckFailed`.
- **Ampliación.** Copia de la alarma de CPU con `put-metric-alarm`.
- **Parte 9.** Borrar la comprobación de aplicación y las alarmas extra, detener la instancia y conservar el resto para la siguiente actividad.

Tipo: actividad guiada sin entregable (se ha preparado igualmente el documento).
