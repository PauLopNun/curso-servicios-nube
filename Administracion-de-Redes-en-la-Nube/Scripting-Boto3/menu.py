#!/usr/bin/env python3
# Menú para lanzar los scripts de Boto3 sin recordar cada nombre
# Pau López Núñez

import subprocess
import sys
from pathlib import Path

CARPETA = Path(__file__).parent

OPCIONES = [
    ("Comprobar conexión y cuenta", "comprobar_conexion.py"),
    ("Listar recursos", "listar_recursos.py"),
    ("Crear VPC con subredes y EC2", "crear_vpc_ec2.py"),
    ("Terminar instancias", "terminar_instancias.py"),
    ("Eliminar VPC", "eliminar_vpc.py"),
    ("Control de gasto (cost_guard, borra sin preguntar)", "cost_guard.py"),
]

while True:
    print("\n=== Scripts de Boto3 ===")
    for i, (texto, _) in enumerate(OPCIONES, 1):
        print(f"  {i}. {texto}")
    print("  0. Salir")

    opcion = input("Opción: ").strip()
    if opcion == "0":
        break
    if not opcion.isdigit() or not 1 <= int(opcion) <= len(OPCIONES):
        print("Opción no válida")
        continue

    # Cada script se ejecuta aparte, igual que lanzándolo a mano
    script = OPCIONES[int(opcion) - 1][1]
    print()
    subprocess.run([sys.executable, str(CARPETA / script)])
