# -*- coding: utf-8 -*-
"""El escritorio sobre el que descansan las laminas. Marco a lo Isaac."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dibujo import Lamina, TINTA, GRIS, GRIS2, CIAN, AMAR

VAR = float(os.environ.get("VARIANTE", "0"))
l = Lamina(640, 360, 7.0 + VAR)
MESA = "#B9AE97"; MESA2 = "#A99D85"; HOJA = "#E7E0D0"
l.partes.append('<rect width="640" height="360" fill="%s"/>' % MESA)
for i in range(7):                                   # veta de la madera
    y = 18 + i * 52
    l.linea(-10, y, 650, y + 8 * math.sin(i), 1.0, MESA2, pasadas=1)
for x, y, w, h, g in [(-40, 22, 150, 190, -9), (520, 14, 160, 200, 7), (470, 250, 190, 150, -5)]:
    pts = [(x, y), (x + w, y + g), (x + w - 6, y + h + g), (x + 4, y + h)]
    l.relleno(pts, HOJA); l.poli(pts, 1.4, cerrar=True)      # hojas sueltas
for i in range(5):
    l.linea(x + 20, y + 30 + i * 22, x + w - 26, y + 32 + i * 22, 1.0, GRIS, pasadas=1)
for px, py, ang in [(34, 300, -18), (596, 118, 74)]:         # lapices
    a = math.radians(ang); dx, dy = math.cos(a), math.sin(a)
    L = 120
    cuerpo = [(px, py), (px + dx * L, py + dy * L),
              (px + dx * L - dy * 9, py + dy * L + dx * 9), (px - dy * 9, py + dx * 9)]
    l.relleno(cuerpo, AMAR); l.poli(cuerpo, 1.5, cerrar=True)
    punta = [(px + dx * L, py + dy * L), (px + dx * (L + 20), py + dy * (L + 20)),
             (px + dx * L - dy * 9, py + dy * L + dx * 9)]
    l.relleno(punta, HOJA); l.poli(punta, 1.3, cerrar=True)
    l.linea(px + dx * 6, py + dy * 6 - dy * 4, px + dx * (L - 8), py + dy * (L - 8) - dy * 4, 1.0, MESA2, pasadas=1)
l.circ(150, 322, 26, 1.2, MESA2, pasadas=1, ry=9)            # cerco de taza
l.circ(154, 320, 22, 1.0, MESA2, pasadas=1, ry=7)
for i in range(9):                                           # migas y manchas
    a = i * 2.399
    l.circ(320 + math.cos(a) * 230, 180 + math.sin(a) * 130, 2 + (i % 3), 0.9, MESA2, pasadas=1)
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "laminas",
                  "escritorio%s.svg" % os.environ.get("SUF", "")), "w", encoding="utf-8").write(l.svg(con_marco=False))
print("escritorio listo")
