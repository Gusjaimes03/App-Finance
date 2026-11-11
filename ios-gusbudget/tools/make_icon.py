#!/usr/bin/env python3
"""Dibuja el icono de la app (1024x1024, sin canal alfa) sin dependencias externas.

Azul noche del llano con la 'G' en el amarillo del sol de la sabana.
Uso: python3 tools/make_icon.py [ruta_de_salida]
"""
import math
import struct
import sys
import zlib

SIZE = 1024
SS = 2  # supermuestreo para bordes suaves

CX = CY = SIZE / 2
R_OUT = 330.0
R_IN = 210.0
R_MID = (R_OUT + R_IN) / 2
CAP = (R_OUT - R_IN) / 2

GAP_START = -42.0
GAP_END = 12.0

BAR_Y = CY + R_MID * math.sin(math.radians(GAP_END))
BAR_X0 = CX + 40
BAR_X1 = CX + R_MID * math.cos(math.radians(GAP_END))

ARRIBA = (0x14, 0x20, 0x4A)   # azul noche
ABAJO = (0x1D, 0x2D, 0x63)
GLIFO = (0xFF, 0xB6, 0x27)    # sol


def en_glifo(x, y):
    dx, dy = x - CX, y - CY
    dist = math.hypot(dx, dy)

    if R_IN <= dist <= R_OUT:
        angulo = math.degrees(math.atan2(dy, dx))
        if not (GAP_START < angulo < GAP_END):
            return True

    for grados in (GAP_START, GAP_END):
        rad = math.radians(grados)
        if math.hypot(x - (CX + R_MID * math.cos(rad)), y - (CY + R_MID * math.sin(rad))) <= CAP:
            return True

    if BAR_X0 <= x <= BAR_X1 and abs(y - BAR_Y) <= CAP:
        return True
    if math.hypot(x - BAR_X0, y - BAR_Y) <= CAP:
        return True
    if math.hypot(x - BAR_X1, y - BAR_Y) <= CAP:
        return True

    return False


def fondo(y):
    t = y / (SIZE - 1)
    return tuple(round(ARRIBA[i] + (ABAJO[i] - ARRIBA[i]) * t) for i in range(3))


def render():
    filas = []
    muestras = SS * SS
    for py in range(SIZE):
        base = fondo(py)
        fila = bytearray()
        for px in range(SIZE):
            aciertos = 0
            for sy in range(SS):
                y = py + (sy + 0.5) / SS
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS
                    if en_glifo(x, y):
                        aciertos += 1
            if aciertos == 0:
                fila += bytes(base)
            else:
                a = aciertos / muestras
                fila += bytes(round(base[i] + (GLIFO[i] - base[i]) * a) for i in range(3))
        filas.append(bytes(fila))
    return filas


def escribir_png(ruta, filas):
    crudo = b"".join(b"\x00" + fila for fila in filas)

    def bloque(etiqueta, datos):
        cuerpo = etiqueta + datos
        return struct.pack(">I", len(datos)) + cuerpo + struct.pack(">I", zlib.crc32(cuerpo) & 0xFFFFFFFF)

    cabecera = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # RGB, sin alfa
    png = (b"\x89PNG\r\n\x1a\n"
           + bloque(b"IHDR", cabecera)
           + bloque(b"IDAT", zlib.compress(crudo, 9))
           + bloque(b"IEND", b""))
    with open(ruta, "wb") as destino:
        destino.write(png)


if __name__ == "__main__":
    salida = sys.argv[1] if len(sys.argv) > 1 else "GusBudget/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    escribir_png(salida, render())
    print("Icono escrito en", salida)
