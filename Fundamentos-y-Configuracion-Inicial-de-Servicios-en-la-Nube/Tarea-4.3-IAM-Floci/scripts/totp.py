#!/usr/bin/env python3
"""Genera un código TOTP (RFC 6238) a partir de una semilla Base32.

Equivale a `oathtool --totp -b <semilla>`: 6 dígitos, intervalo de 30 s, HMAC-SHA1.
Uso: python3 totp.py eva.seed
"""
import base64
import hashlib
import hmac
import struct
import sys
import time


def totp(semilla_b32: str, intervalo: int = 30, digitos: int = 6) -> str:
    semilla = semilla_b32.strip().replace(" ", "").upper()
    semilla += "=" * (-len(semilla) % 8)
    clave = base64.b32decode(semilla)
    contador = struct.pack(">Q", int(time.time()) // intervalo)
    resumen = hmac.new(clave, contador, hashlib.sha1).digest()
    desplazamiento = resumen[-1] & 0x0F
    numero = struct.unpack(">I", resumen[desplazamiento:desplazamiento + 4])[0] & 0x7FFFFFFF
    return str(numero % 10 ** digitos).zfill(digitos)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Uso: python3 totp.py <fichero-semilla>")
    with open(sys.argv[1], encoding="ascii") as f:
        print(totp(f.read()))
