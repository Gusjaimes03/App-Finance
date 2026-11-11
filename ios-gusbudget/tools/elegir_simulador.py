#!/usr/bin/env python3
"""Imprime el UDID del primer simulador de iPhone disponible."""
import json
import subprocess
import sys

salida = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    capture_output=True, text=True, check=True,
).stdout

for runtime, lista in json.loads(salida).get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for aparato in lista:
        if aparato.get("isAvailable") and "iPhone" in aparato.get("name", ""):
            print(aparato["udid"])
            sys.exit(0)

print("No hay simuladores de iPhone disponibles", file=sys.stderr)
sys.exit(1)
