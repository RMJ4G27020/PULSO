# -*- coding: utf-8 -*-
"""
Iconos de lanzador de Android para PULSO, a partir de retrato.png.

    python3 build_iconos.py

Escribe en ../pulso-godot/arte/icono/:
  icono_192.png               el icono clasico (y el del proyecto en escritorio)
  adaptativo_frente_432.png   TSL-04 sobre transparente, dentro de la zona segura
  adaptativo_fondo_432.png    el halo cian sobre el azul del juego, a sangre

Por que DOS piezas para el adaptativo: desde Android 8 el lanzador recorta el
icono con su propia mascara (circulo, gota, cuadrado redondeado...) y mueve el
frente sobre el fondo con efecto de paralaje. Un icono de una sola pieza sale
recortado por donde caiga la mascara. La zona que se ve siempre es el circulo
central de 66/108 del lienzo (264 de 432 px): TSL-04 va dentro de ese circulo
para que ninguna mascara le corte la cara.

El fondo y el tamano del personaje son los mismos que los del icono de la
tienda (prueba/cap_ficha.gd, _icono): el halo del cian del juego fundido al azul
del fondo, con el cuadrado de la distancia. Asi el icono del telefono y el de
Google Play son el mismo dibujo.
"""
import os
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RETRATO = os.path.join(AQUI, "retrato.png")
SALIDA = os.path.join(AQUI, "..", "pulso-godot", "arte", "icono")

FONDO = (0.031, 0.055, 0.086)      # el azul casi negro del juego
HALO = (0.09, 0.28, 0.40)          # el cian apagado del centro


def fondo(n, alcance=0.70):
    """Halo radial: HALO en el centro hasta FONDO, con el cuadrado de la distancia."""
    img = Image.new("RGBA", (n, n))
    px = img.load()
    c = n * 0.5
    for y in range(n):
        for x in range(n):
            d = min(((x - c) ** 2 + (y - c) ** 2) ** 0.5 / (n * alcance), 1.0)
            k = d * d
            col = tuple(int(round((HALO[i] + (FONDO[i] - HALO[i]) * k) * 255)) for i in range(3))
            px[x, y] = col + (255,)
    return img


def personaje(lado):
    """TSL-04 recortado a lo que ocupa y escalado a `lado` px en su lado mayor."""
    r = Image.open(RETRATO).convert("RGBA")
    r = r.crop(r.getbbox())
    k = lado / max(r.size)
    return r.resize((max(1, int(r.size[0] * k)), max(1, int(r.size[1] * k))), Image.LANCZOS)


def centrar(lienzo, pieza):
    x = (lienzo.size[0] - pieza.size[0]) // 2
    y = (lienzo.size[1] - pieza.size[1]) // 2
    lienzo.alpha_composite(pieza, (x, y))
    return lienzo


def main():
    os.makedirs(SALIDA, exist_ok=True)

    # 1. clasico de 192: igual que el de la tienda, personaje al 80%
    n = 192
    clasico = centrar(fondo(n), personaje(int(n * 0.80)))
    clasico.save(os.path.join(SALIDA, "icono_192.png"))

    # 2. adaptativo: el personaje cabe en el circulo seguro de 264 px. La
    # caja del retrato es casi cuadrada y TSL-04 es redondo, asi que con 240 px
    # de lado su silueta queda dentro del circulo con margen.
    n = 432
    frente = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    centrar(frente, personaje(240))
    frente.save(os.path.join(SALIDA, "adaptativo_frente_432.png"))
    # el fondo va a sangre (las mascaras recortan desde fuera) y el halo un
    # poco mas abierto, porque la parte visible es solo el centro
    fondo(n, alcance=0.55).save(os.path.join(SALIDA, "adaptativo_fondo_432.png"))

    for f in sorted(os.listdir(SALIDA)):
        if f.endswith(".png"):
            im = Image.open(os.path.join(SALIDA, f))
            print("%-28s %s %s" % (f, im.size, im.mode))


if __name__ == "__main__":
    main()
