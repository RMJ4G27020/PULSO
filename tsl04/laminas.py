# -*- coding: utf-8 -*-
"""Las 9 vinetas de PULSO dibujadas en 2D, replicando el storyboard original."""
import math, os

# desplazamiento de semilla: genera el segundo dibujo del par que hierve
VARIANTE = float(os.environ.get('VARIANTE', '0'))
from dibujo import Lamina, TINTA, GRIS, GRIS2, CIAN, CIANC, ROJO, AZUL, AMAR

W, H = 400, 300

def onda(l, x0, y0, x1, y1, amp=6, n=5, gr=1.5, col=None):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t,
                    y0 + (y1 - y0) * t + math.sin(t * math.pi * 2 + x0) * amp))
    l.poli(pts, gr, col)

def cable(l, pts, ancho=7, anillos=0):
    """cable grueso: dos lineas paralelas y opcionalmente anillos de union"""
    for s in (-1, 1):
        l.poli([(x, y + s * ancho / 2) for x, y in pts], 1.5)
    if anillos:
        for k in range(anillos):
            t = (k + 0.5) / anillos
            i = min(int(t * (len(pts) - 1)), len(pts) - 2)
            u = t * (len(pts) - 1) - i
            x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * u
            y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * u
            l.linea(x, y - ancho / 2, x, y + ancho / 2, 1.3)

# ---------------------------------------------------------------- 1 maquina
def v1():
    l = Lamina(W, H, 11.0 + VARIANTE)
    for i in range(8):                                   # arcos de cable
        r = 92 + i * 12
        l.arco(200, 252, r, 180, 360, 1.5 - i * 0.06, TINTA, ry=r * 0.80, pasadas=1)
    l.linea(0, 252, W, 252, 1.8)
    for x, w, y, h in [(52, 46, 180, 72), (302, 46, 180, 72)]:
        l.relleno_caja(x, y, w, h, GRIS2); l.caja(x, y, w, h, 1.6)
    for x in (100, 248):                                 # modulos laterales
        l.relleno_caja(x, 156, 52, 96, GRIS2); l.caja(x, 156, 52, 96, 1.7)
        l.relleno_caja(x + 9, 168, 34, 24, "#F6F2E7"); l.caja(x + 9, 168, 34, 24, 1.3)
    l.relleno_caja(155, 120, 90, 132, GRIS2)             # maquina central
    l.caja(155, 120, 90, 132, 2.0)
    l.relleno_caja(148, 108, 104, 13, "#F6F2E7"); l.caja(148, 108, 104, 13, 1.7)
    l.relleno_caja(168, 133, 64, 46, "#F8F5EC"); l.caja(168, 133, 64, 46, 1.6)
    l.relleno_caja(170, 194, 60, 20, GRIS); l.caja(170, 194, 60, 20, 1.4)
    for i in range(7):                                   # cables por el suelo
        y = 258 + i * 5
        onda(l, -10 + (i % 3) * 14, y, 410 - (i % 2) * 20, y + 4, 5 + (i % 3) * 2, 7, 1.3)
    for x in (26, 374):                                  # bajantes
        l.poli([(x, 40), (x - 6, 110), (x + 5, 180), (x - 3, 250)], 1.7)
    return l

# ------------------------------------------------------------------ 2 celda
def v2():
    l = Lamina(W, H, 22.0 + VARIANTE)
    cuerpo = [(96, 132), (306, 120), (302, 262), (100, 266)]
    l.relleno(cuerpo, GRIS2); l.poli(cuerpo, 2.0, cerrar=True)
    capot = [(101, 88), (303, 78), (306, 134), (98, 140)]
    l.relleno(capot, GRIS); l.poli(capot, 1.9, cerrar=True)
    pant = [(117, 98), (288, 89), (290, 126), (115, 132)]
    l.relleno(pant, "#F7F3E9"); l.poli(pant, 1.5, cerrar=True)
    for k in range(6):                                   # rejilla inferior
        x = 128 + k * 26
        l.relleno_caja(x, 228, 15, 20, GRIS); l.caja(x, 228, 15, 20, 1.2)
    cab = [(-8, 176), (70, 170), (150, 166), (200, 165), (255, 167), (330, 172), (408, 180)]
    cable(l, cab, 11, 0)
    l.relleno_circ(200, 166, 23, GRIS2); l.circ(200, 166, 23, 2.0)   # la celda
    l.relleno_circ(193, 158, 9, "#F7F3E9", 0.9, ry=6)
    for s, x0 in ((-1, 40), (1, 360)):                   # cables de las esquinas
        l.poli([(x0 - s * 34, -6), (x0 - s * 10, 34), (x0 + s * 6, 74), (x0 - s * 4, 118)], 2.1)
        l.poli([(x0 - s * 60, -6), (x0 - s * 40, 40), (x0 - s * 24, 86)], 1.7)
    return l

# --------------------------------------------------------------- 3 el rayo
def v3():
    l = Lamina(W, H, 33.0 + VARIANTE)
    l.linea(0, 254, W, 254, 1.8)
    for x, y, w, h in [(46, 196, 40, 58), (86, 178, 32, 76), (288, 186, 36, 68), (322, 200, 40, 54)]:
        l.relleno_caja(x, y, w, h, GRIS2); l.caja(x, y, w, h, 1.4)
    l.relleno_caja(120, 152, 160, 102, GRIS2)            # el centro de datos
    l.caja(120, 152, 160, 102, 2.0)
    l.relleno_caja(112, 140, 176, 13, "#F6F2E7"); l.caja(112, 140, 176, 13, 1.7)
    for k in range(6):                                   # columnas
        x = 133 + k * 24
        l.relleno_caja(x, 162, 11, 90, "#F7F3E9"); l.caja(x, 162, 11, 90, 1.3)
    l.relleno_caja(246, 192, 26, 62, "#F7F3E9"); l.caja(246, 192, 26, 62, 1.4)
    l.linea(245, 140, 245, 92, 1.8)                      # antena
    for k in range(3):
        w = 13 - k * 3
        l.linea(245 - w, 104 - k * 7, 245 + w, 104 - k * 7, 1.3)
    zig = [(268, 14), (252, 44), (266, 48), (246, 76), (258, 78), (243, 92)]
    ancho = [7, 5, 6, 4, 5, 2]
    pol = [(x + a, y) for (x, y), a in zip(zig, ancho)] + \
          [(x - a, y) for (x, y), a in zip(reversed(zig), reversed(ancho))]
    l.relleno(pol, AMAR)                                 # el rayo
    l.poli(zig, 2.2, TINTA)
    return l

# ------------------------------------------------------------ 4 la descarga
def v4():
    l = Lamina(W, H, 44.0 + VARIANTE)
    cab = [(-6, 276), (48, 250), (98, 222), (140, 198)]
    cable(l, cab, 15, 4)
    l.relleno_circ(214, 158, 60, GRIS2); l.circ(214, 158, 60, 2.4)   # la celda
    l.relleno_circ(196, 138, 26, "#FAF7EF", 1.0, ry=16)
    l.circ(196, 138, 26, 1.7, ry=16)
    for i, (x, y) in enumerate([(392, 78), (398, 122), (386, 40)]):  # cables que la tocan
        l.poli([(x, y), (330, y + 26), (288, 132), (272, 146)], 1.9)
    for i in range(5):                                   # chispas del contacto
        a = math.radians(-52 + i * 28)
        x0, y0 = 268, 148
        pts = [(x0, y0)]
        for k in range(1, 4):
            d = k * 13
            pts.append((x0 + math.cos(a) * d + (-1) ** k * 5,
                        y0 + math.sin(a) * d + (-1) ** k * 4))
        l.poli(pts, 2.0)
    return l

# ----------------------------------------------------------- 5 el despertar
def v5():
    l = Lamina(W, H, 55.0 + VARIANTE)
    l.circ(238, 150, 80, 5.0, CIAN, pasadas=2)           # el aro
    l.circ(238, 150, 80, 2.0, CIANC, pasadas=1)
    ojo = []                                             # ojo de almendra inclinado
    for i in range(26):
        t = i / 25.0
        x = -52 + 104 * t
        y = -26 * math.sin(math.pi * t)
        a = math.radians(-16)
        ojo.append((238 + x * math.cos(a) - y * math.sin(a), 152 + x * math.sin(a) + y * math.cos(a)))
    for i in range(26):
        t = 1 - i / 25.0
        x = -52 + 104 * t
        y = 20 * math.sin(math.pi * t)
        a = math.radians(-16)
        ojo.append((238 + x * math.cos(a) - y * math.sin(a), 152 + x * math.sin(a) + y * math.cos(a)))
    l.relleno(ojo, CIAN)
    l.poli(ojo, 2.0, CIAN, cerrar=True, pasadas=1)
    l.poli([(186, 128), (240, 108), (290, 116)], 6.0, CIAN, pasadas=1)   # parpado
    l.poli([(24, 208), (74, 192), (124, 176), (156, 166)], 5.0, CIAN, pasadas=1)   # estelas
    l.poli([(34, 238), (90, 222), (140, 208), (166, 200)], 3.4, CIAN, pasadas=1)
    return l

# ---------------------------------------------------------------- 6 y 7 UI
def portatil(l, x, y, esc, color):
    """portatil abierto de perfil tres cuartos"""
    b = [(x, y), (x + 190 * esc, y - 6 * esc), (x + 208 * esc, y + 30 * esc), (x + 16 * esc, y + 38 * esc)]
    l.relleno(b, GRIS2); l.poli(b, 1.9, cerrar=True)     # base
    for r in range(3):                                   # teclas
        for c in range(11):
            kx = x + 22 * esc + c * 15.5 * esc
            ky = y + 6 * esc + r * 9 * esc
            l.relleno_caja(kx, ky, 11 * esc, 6 * esc, GRIS); l.caja(kx, ky, 11 * esc, 6 * esc, 0.7, sobra=0.5)
    t = [(x + 14 * esc, y - 2 * esc), (x + 196 * esc, y - 10 * esc),
         (x + 190 * esc, y - 108 * esc), (x + 20 * esc, y - 100 * esc)]
    l.relleno(t, GRIS2); l.poli(t, 2.0, cerrar=True)     # tapa
    p = [(x + 26 * esc, y - 12 * esc), (x + 184 * esc, y - 19 * esc),
         (x + 179 * esc, y - 96 * esc), (x + 32 * esc, y - 89 * esc)]
    l.relleno(p, "#F7F3E9"); l.poli(p, 1.4, cerrar=True) # pantalla
    cx = x + 105 * esc; cy = y - 55 * esc; s = 32 * esc
    l.relleno_caja(cx - s / 2, cy - s / 2, s, s, color)  # el cuadro de color
    l.caja(cx - s / 2, cy - s / 2, s, s, 1.3)

def tuberias(l, xs, y0=-8, y1=118):
    for i, x in enumerate(xs):
        l.poli([(x, y0), (x + 8, y0 + (y1 - y0) * 0.45), (x - 4, y1)], 2.2)

def v6():
    l = Lamina(W, H, 66.0 + VARIANTE)
    tuberias(l, [250, 276, 302, 330], -8, 104)
    l.circ(92, 152, 48, 4.4, CIAN)                       # el aro suelto
    l.circ(92, 152, 48, 1.8, CIANC, pasadas=1)
    cable(l, [(-6, 284), (24, 252), (46, 220), (60, 196)], 13, 3)
    portatil(l, 196, 214, 0.92, ROJO)
    l.relleno_caja(180, 246, 210, 22, GRIS)              # la mesa
    l.caja(180, 246, 210, 22, 1.6)
    return l

def v7():
    l = Lamina(W, H, 77.0 + VARIANTE)
    tuberias(l, [96, 126, 156, 186], -8, 96)
    l.poli([(62, -6), (48, 40), (60, 86)], 2.0)
    portatil(l, 84, 226, 1.12, AZUL)
    l.relleno_caja(64, 258, 250, 22, GRIS); l.caja(64, 258, 250, 22, 1.6)
    dx, dy = 336, 116                                    # cuadricoptero
    l.relleno_caja(dx - 13, dy - 7, 26, 14, TINTA)
    for sx in (-1, 1):
        for sy in (-1, 1):
            l.linea(dx, dy, dx + 26 * sx, dy + 13 * sy, 2.4, TINTA, pasadas=1)
            l.relleno_circ(dx + 26 * sx, dy + 13 * sy, 11, TINTA, 0.85, ry=3.4)
    for k in range(3):
        l.linea(dx + 44, dy - 10 + k * 10, dx + 60, dy - 10 + k * 10, 1.2, TINTA, pasadas=1)
    return l

# ------------------------------------------------------------- 8 el conducto
def v8():
    l = Lamina(W, H, 88.0 + VARIANTE)
    for i in range(14):                                  # trama del fondo
        x = -40 + i * 34
        l.linea(x, 300, x + 116, 10, 0.9, GRIS, pasadas=1, amp=1.2)
    for i in range(8):                                   # trama de abajo
        x = -20 + i * 44
        l.linea(x, 302, x + 74, 196, 0.9, GRIS, pasadas=1, amp=1.2)
    for off in (-13, 0, 13):                             # el conducto
        l.linea(6 + off * 0.2, 268 + off, 392 + off * 0.2, 118 + off, 2.0 if off == 0 else 1.6)
    l.poli([(44, 250), (120, 220), (196, 190), (262, 166)], 4.6, CIAN, pasadas=1)  # estela
    l.relleno_circ(292, 150, 18, CIAN); l.circ(292, 150, 18, 2.0, TINTA)
    l.relleno_circ(288, 146, 6, "#F7F3E9", 0.95, ry=7)   # ojo
    hx, hy = 352, 54                                     # reloj de arena
    l.linea(hx - 17, hy - 24, hx + 17, hy - 24, 3.0, CIAN, pasadas=1)
    l.linea(hx - 17, hy + 24, hx + 17, hy + 24, 3.0, CIAN, pasadas=1)
    l.relleno([(hx - 14, hy - 22), (hx + 14, hy - 22), (hx, hy)], CIAN, 0.55)
    l.relleno([(hx - 14, hy + 22), (hx + 14, hy + 22), (hx, hy)], CIAN, 0.55)
    l.poli([(hx - 14, hy - 22), (hx, hy), (hx - 14, hy + 22)], 2.2, CIAN, pasadas=1)
    l.poli([(hx + 14, hy - 22), (hx, hy), (hx + 14, hy + 22)], 2.2, CIAN, pasadas=1)
    return l

# --------------------------------------------------------------- 9 el escape
def v9():
    l = Lamina(820, 280, 99.0 + VARIANTE)
    l.linea(0, 236, 820, 236, 1.6)                       # horizonte
    l.linea(0, 250, 820, 252, 1.2)
    l.relleno_caja(34, 62, 86, 176, GRIS2); l.caja(34, 62, 86, 176, 2.0)
    for r in range(4):                                   # ventanas
        for c in range(3):
            l.relleno_caja(46 + c * 24, 76 + r * 34, 16, 20, "#F7F3E9")
            l.caja(46 + c * 24, 76 + r * 34, 16, 20, 1.1)
    for x, y, w, h in [(206, 118, 40, 118), (250, 96, 34, 140), (288, 130, 44, 106),
                       (336, 108, 30, 128), (370, 140, 38, 96), (412, 120, 34, 116)]:
        l.relleno_caja(x, y, w, h, GRIS2); l.caja(x, y, w, h, 1.4)
    for i in range(8):                                   # el reventon: nubes de polvo
        a = i * 2.399
        d = 24 + (i % 4) * 16
        l.nube(140 + math.cos(a) * d, 158 + math.sin(a) * d * 0.55,
               20 + (i % 3) * 9, 6 + (i % 3), 1.5, TINTA, "#F2EDE1")
    l.relleno_circ(128, 152, 14, CIAN); l.circ(128, 152, 14, 1.7, TINTA)
    mesa = [(168, 196), (214, 186), (222, 208), (176, 218)]   # muebles volando
    l.relleno(mesa, GRIS2); l.poli(mesa, 1.7, cerrar=True)
    l.poli([(176, 218), (172, 236)], 1.5); l.poli([(218, 208), (216, 228)], 1.5)
    for cx, cy, g in ((160, 228, -22), (232, 214, 26)):
        s = [(cx - 14, cy), (cx + 14, cy - 4), (cx + 16, cy + 8), (cx - 12, cy + 12)]
        l.relleno(s, GRIS2); l.poli(s, 1.5, cerrar=True)
        l.poli([(cx + 14, cy - 4), (cx + 22, cy - 24)], 1.5)
        l.poli([(cx, cy + 11), (cx - 2, cy + 26)], 1.4)
        l.poli([(cx - 12, cy + 28), (cx + 12, cy + 24)], 1.3)
    est = [(150, 150), (260, 142), (380, 134), (480, 128), (556, 124), (592, 122),
           (592, 127), (556, 131), (480, 138), (380, 148), (260, 160), (150, 172)]
    l.relleno(est, CIAN, 0.85)                           # estela: se afila hacia el orbe
    l.poli(est[:6], 1.5, CIAN, pasadas=1)
    l.relleno_circ(624, 124, 27, CIAN); l.circ(624, 124, 27, 2.2, TINTA)
    l.relleno_circ(618, 118, 9, "#F7F3E9", 0.95, ry=10)
    l.relleno_caja(664, 152, 96, 84, GRIS2); l.caja(664, 152, 96, 84, 1.9)   # granero
    l.relleno([(656, 152), (712, 116), (768, 152)], GRIS)
    l.poli([(656, 152), (712, 116), (768, 152)], 1.9, cerrar=True)
    l.relleno_caja(696, 190, 32, 46, "#F7F3E9"); l.caja(696, 190, 32, 46, 1.4)
    l.relleno_caja(776, 122, 34, 114, GRIS2); l.caja(776, 122, 34, 114, 1.8)  # silo
    l.arco(793, 122, 17, 180, 360, 1.8, ry=13)
    for i in range(10):                                  # valla
        l.linea(612 + i * 22, 244, 612 + i * 22, 268, 1.4)
    l.linea(606, 252, 820, 250, 1.4)
    for i in range(18):                                  # maiz
        x = 616 + i * 11
        l.poli([(x, 278), (x + 2, 262)], 1.2)
        l.poli([(x + 2, 268), (x + 8, 262)], 1.0)
        l.poli([(x + 2, 272), (x - 4, 266)], 1.0)
    return l

# ================================================== laminas anadidas (10-18)
def v10():
    """exterior nocturno, antes de la tormenta"""
    l = Lamina(W, H, 110.0 + VARIANTE)
    l.linea(0, 256, W, 256, 1.8)
    l.arco(322, 66, 26, 200, 340, 1.6)                   # luna entre nubes
    for i in range(3):
        l.nube(288 + i * 30, 74 + (i % 2) * 10, 20 + (i % 2) * 8, 6, 1.3, TINTA, None)
    for x, y, w, h in [(28, 200, 38, 56), (66, 186, 30, 70), (300, 194, 34, 62), (338, 206, 40, 50)]:
        l.relleno_caja(x, y, w, h, GRIS2); l.caja(x, y, w, h, 1.4)
    l.relleno_caja(112, 158, 178, 98, GRIS2)             # el centro de datos
    l.caja(112, 158, 178, 98, 2.0)
    l.relleno_caja(104, 146, 194, 13, "#F6F2E7"); l.caja(104, 146, 194, 13, 1.7)
    for r in range(3):                                   # ventanas, unas pocas encendidas
        for c in range(7):
            x, y = 124 + c * 23, 170 + r * 27
            enc = (r * 7 + c) % 5 < 2
            l.relleno_caja(x, y, 14, 16, AMAR if enc else GRIS)
            l.caja(x, y, 14, 16, 1.1)
    l.linea(200, 146, 200, 108, 1.6)                     # pararrayos
    for i in range(11):                                  # valla
        l.linea(20 + i * 36, 244, 20 + i * 36, 262, 1.2)
    l.linea(14, 250, 388, 250, 1.2)
    return l

def v11():
    """las cuatro celdas colgando en fila"""
    l = Lamina(W, H, 121.0 + VARIANTE)
    l.linea(0, 46, W, 42, 1.8)                           # techo
    for i in range(6):
        l.poli([(24 + i * 70, 42), (30 + i * 70, 62), (20 + i * 70, 84)], 1.2, GRIS)
    for i, x in enumerate((78, 158, 238, 318)):
        cable(l, [(x - 3, 44), (x, 96), (x - 2, 142)], 9, 2)
        l.relleno_circ(x, 168, 26, GRIS2); l.circ(x, 168, 26, 2.0)
        l.relleno_circ(x - 8, 160, 10, "#F8F5EC", 0.9, ry=7)
        l.caja(x - 24, 208, 48, 20, 1.2)                 # placa con el numero
        l.linea(x - 16, 218, x + 16, 218, 1.1, GRIS)
        for k in range(i + 1):                           # marcas de conteo
            l.linea(x - 15 + k * 8, 213, x - 15 + k * 8, 223, 1.5)
    l.linea(0, 262, W, 258, 1.6)
    return l

def v12():
    """una de las celdas apagadas, de cerca"""
    l = Lamina(W, H, 132.0 + VARIANTE)
    cable(l, [(196, -8), (202, 40), (198, 84)], 14, 3)
    l.relleno_circ(200, 152, 62, GRIS2); l.circ(200, 152, 62, 2.4)
    for a in (34, -28):                                  # grietas
        ang = math.radians(a)
        pts = [(200 + math.cos(ang) * 12, 152 + math.sin(ang) * 12)]
        for k in range(1, 5):
            pts.append((200 + math.cos(ang) * (12 + k * 13) + (-1) ** k * 7,
                        152 + math.sin(ang) * (12 + k * 13) + (-1) ** k * 5))
        l.poli(pts, 1.8)
    for sx in (-1, 1):                                   # ojos apagados: dos X
        ex = 200 + 22 * sx
        l.linea(ex - 9, 138, ex + 9, 154, 2.0)
        l.linea(ex + 9, 138, ex - 9, 154, 2.0)
    l.poli([(186, 176), (200, 170), (214, 176)], 1.8)    # boca hacia abajo
    l.caja(150, 236, 100, 26, 1.4)
    for k in range(1):
        l.linea(190, 244, 190, 256, 1.6)
    l.linea(166, 250, 234, 250, 1.1, GRIS)
    for i in range(4):                                   # polvo
        l.circ(120 + i * 55, 96 + (i % 2) * 18, 3 + i % 2, 0.9, GRIS)
    return l

def v13():
    """el ojo del sistema: un sensor en el techo que lo mira todo"""
    l = Lamina(W, H, 143.0 + VARIANTE)
    l.linea(0, 40, W, 36, 1.8)
    for i in range(5):
        l.poli([(30 + i * 84, 36), (38 + i * 84, 58), (26 + i * 84, 80)], 1.2, GRIS)
    l.relleno_caja(164, 38, 72, 22, GRIS2); l.caja(164, 38, 72, 22, 1.8)
    l.relleno_circ(200, 78, 32, GRIS2); l.circ(200, 78, 32, 2.2)
    l.relleno_circ(200, 84, 15, TINTA); l.circ(200, 84, 15, 1.6)
    l.relleno_circ(194, 79, 5, "#F8F5EC", 0.95)
    for s in (-1, 1):                                    # cono de vision, a trazos
        for k in range(7):
            y = 118 + k * 22
            w = 18 + k * 15
            l.linea(200 + s * w * 0.6, y, 200 + s * w, y + 8, 1.1, GRIS)
    l.poli([(200, 116), (128, 268)], 1.3, GRIS)
    l.poli([(200, 116), (272, 268)], 1.3, GRIS)
    for i in range(3):
        cable(l, [(150 - i * 40, 36), (168 - i * 30, 52), (176, 62)], 6, 0)
    return l

def v14():
    """el primer paso: el suelo se enciende detras"""
    l = Lamina(W, H, 154.0 + VARIANTE)
    l.linea(0, 214, W, 210, 2.0)                         # suelo
    for i in range(7):                                   # celdas ya pisadas
        x = 24 + i * 38
        l.relleno_caja(x, 190, 30, 22, CIANC, 0.85 - i * 0.09)
        l.caja(x, 190, 30, 22, 1.3, CIAN)
        for k in range(2):
            l.poli([(x + 8 + k * 12, 188), (x + 4 + k * 12, 176), (x + 11 + k * 12, 178)],
                   1.3, CIAN)
    l.circ(316, 168, 34, 4.4, CIAN)                      # TSL-04
    l.circ(316, 168, 34, 1.8, CIANC, pasadas=1)
    l.relleno_circ(310, 164, 12, CIAN, 0.9, ry=9)
    l.poli([(292, 150), (316, 142), (340, 148)], 4.0, CIAN, pasadas=1)
    for k in range(3):                                   # lineas de movimiento
        l.linea(360 + k * 4, 150 + k * 12, 392 + k * 4, 150 + k * 12, 1.6, CIAN, pasadas=1)
    return l

def v15():
    """mira atras y ve su propia estela"""
    l = Lamina(W, H, 165.0 + VARIANTE)
    l.linea(0, 226, W, 222, 2.0)
    for i in range(10):                                  # la estela se pierde a lo lejos
        x = 8 + i * 34
        al = 0.9 - i * 0.07
        l.relleno_caja(x, 202, 27, 22, CIANC, max(al, 0.12))
        l.caja(x, 202, 27, 22, 1.2, CIAN)
    l.circ(330, 158, 42, 4.6, CIAN)
    l.circ(330, 158, 42, 1.8, CIANC, pasadas=1)
    ojo = []                                             # el ojo mirando hacia atras
    for i in range(22):
        t = i / 21.0
        ojo.append((330 - 34 + 40 * t, 158 - 16 * math.sin(math.pi * t)))
    for i in range(22):
        t = 1 - i / 21.0
        ojo.append((330 - 34 + 40 * t, 158 + 13 * math.sin(math.pi * t)))
    l.relleno(ojo, CIAN); l.poli(ojo, 1.8, CIAN, cerrar=True, pasadas=1)
    l.relleno_circ(304, 158, 7, "#F7F3E9", 0.95)
    l.poli([(290, 132), (330, 122), (368, 130)], 4.0, CIAN, pasadas=1)
    for k in range(3):                                   # signos de alarma
        l.linea(376 + k * 6, 104 - k * 6, 386 + k * 6, 88 - k * 6, 2.0, CIAN, pasadas=1)
    return l

def v16():
    """las puertas se cierran por sectores"""
    l = Lamina(W, H, 176.0 + VARIANTE)
    for i in range(5):                                   # pasillo en fuga
        k = i / 4.0
        w = 300 - k * 190; h = 200 - k * 128
        x = 200 - w / 2; y = 150 - h / 2
        l.caja(x, y, w, h, 2.0 - k * 0.6)
    l.linea(50, 250, 130, 214, 1.3); l.linea(350, 250, 270, 214, 1.3)
    for i, (k, baja) in enumerate([(0.0, 0.30), (0.28, 0.55), (0.56, 0.80)]):
        w = 300 - k * 190; h = 200 - k * 128
        x = 200 - w / 2; y = 150 - h / 2
        l.relleno_caja(x, y, w, h * baja, GRIS2, 0.9)    # compuerta bajando
        l.caja(x, y, w, h * baja, 1.8)
        for c in range(4):                               # nervios de la compuerta
            l.linea(x + w * (c + 1) / 5, y, x + w * (c + 1) / 5, y + h * baja, 1.1, GRIS)
        for s in (-1, 1):                                # flechas hacia abajo
            ax = 200 + s * (w / 2 + 12)
            l.poli([(ax, y + 10), (ax, y + h * baja - 6)], 1.4)
            l.poli([(ax - 5, y + h * baja - 14), (ax, y + h * baja - 5), (ax + 5, y + h * baja - 14)], 1.4)
    return l

def v17():
    """los drones salen del nicho"""
    l = Lamina(W, H, 187.0 + VARIANTE)
    l.linea(0, 250, W, 246, 1.8)
    l.relleno_caja(20, 44, 116, 138, GRIS2); l.caja(20, 44, 116, 138, 2.0)
    l.relleno_caja(34, 60, 88, 106, "#F7F3E9"); l.caja(34, 60, 88, 106, 1.6)  # nicho abierto
    for i in range(4):
        l.linea(34, 74 + i * 24, 122, 74 + i * 24, 1.0, GRIS)
    for i, (dx, dy, e) in enumerate([(150, 96, 1.0), (216, 140, 0.85), (280, 84, 0.75), (330, 168, 0.62)]):
        s = e
        l.relleno_caja(dx - 15 * s, dy - 8 * s, 30 * s, 16 * s, TINTA)
        for sx in (-1, 1):
            for sy in (-1, 1):
                l.linea(dx, dy, dx + 28 * s * sx, dy + 14 * s * sy, 2.2 * s, TINTA, pasadas=1)
                l.relleno_circ(dx + 28 * s * sx, dy + 14 * s * sy, 12 * s, TINTA, 0.85, ry=4 * s)
        for k in range(2):                               # rastro
            l.linea(dx - 34 * s - k * 10, dy - 4 + k * 8, dx - 20 * s - k * 10, dy - 4 + k * 8,
                    1.2, TINTA, pasadas=1)
    return l

def v18():
    """la carga se acaba"""
    l = Lamina(W, H, 198.0 + VARIANTE)
    l.linea(0, 244, W, 240, 1.8)
    l.circ(144, 156, 46, 3.0, CIAN)                      # TSL-04, debil: trazo mas fino
    l.circ(144, 156, 46, 1.2, CIANC, pasadas=1)
    for sx in (-1, 1):                                   # ojos entrecerrados
        l.poli([(144 + sx * 22 - 11, 152), (144 + sx * 22, 158), (144 + sx * 22 + 11, 152)],
               2.6, CIAN, pasadas=1)
    l.poli([(130, 178), (144, 174), (158, 178)], 2.0, CIAN, pasadas=1)
    for k in range(3):                                   # chispas que se caen
        l.poli([(112 - k * 8, 196 + k * 6), (106 - k * 8, 210 + k * 8)], 1.4, CIAN, pasadas=1)
    l.caja(238, 118, 128, 34, 2.0)                       # medidor de carga
    l.relleno_caja(243, 123, 26, 24, CIAN, 0.9)
    for k in range(4):
        l.linea(272 + k * 23, 118, 272 + k * 23, 152, 1.1, GRIS)
    l.caja(238, 164, 128, 12, 1.3)
    l.linea(246, 170, 300, 170, 1.6, TINTA)
    hx, hy = 302, 214                                    # reloj casi vacio
    l.linea(hx - 14, hy - 20, hx + 14, hy - 20, 2.6, CIAN, pasadas=1)
    l.linea(hx - 14, hy + 20, hx + 14, hy + 20, 2.6, CIAN, pasadas=1)
    l.relleno([(hx - 11, hy + 18), (hx + 11, hy + 18), (hx, hy + 4)], CIAN, 0.6)
    l.poli([(hx - 12, hy - 18), (hx, hy), (hx - 12, hy + 18)], 2.0, CIAN, pasadas=1)
    l.poli([(hx + 12, hy - 18), (hx, hy), (hx + 12, hy + 18)], 2.0, CIAN, pasadas=1)
    return l

# ================================================== laminas anadidas (10-18)
def v10():
    """exterior nocturno, antes de la tormenta"""
    l = Lamina(W, H, 110.0 + VARIANTE)
    l.linea(0, 256, W, 256, 1.8)
    l.arco(322, 66, 26, 200, 340, 1.6)                   # luna entre nubes
    for i in range(3):
        l.nube(288 + i * 30, 74 + (i % 2) * 10, 20 + (i % 2) * 8, 6, 1.3, TINTA, None)
    for x, y, w, h in [(28, 200, 38, 56), (66, 186, 30, 70), (300, 194, 34, 62), (338, 206, 40, 50)]:
        l.relleno_caja(x, y, w, h, GRIS2); l.caja(x, y, w, h, 1.4)
    l.relleno_caja(112, 158, 178, 98, GRIS2)             # el centro de datos
    l.caja(112, 158, 178, 98, 2.0)
    l.relleno_caja(104, 146, 194, 13, "#F6F2E7"); l.caja(104, 146, 194, 13, 1.7)
    for r in range(3):                                   # ventanas, unas pocas encendidas
        for c in range(7):
            x, y = 124 + c * 23, 170 + r * 27
            enc = (r * 7 + c) % 5 < 2
            l.relleno_caja(x, y, 14, 16, AMAR if enc else GRIS)
            l.caja(x, y, 14, 16, 1.1)
    l.linea(200, 146, 200, 108, 1.6)                     # pararrayos
    for i in range(11):                                  # valla
        l.linea(20 + i * 36, 244, 20 + i * 36, 262, 1.2)
    l.linea(14, 250, 388, 250, 1.2)
    return l

def v11():
    """las cuatro celdas colgando en fila"""
    l = Lamina(W, H, 121.0 + VARIANTE)
    l.linea(0, 46, W, 42, 1.8)                           # techo
    for i in range(6):
        l.poli([(24 + i * 70, 42), (30 + i * 70, 62), (20 + i * 70, 84)], 1.2, GRIS)
    for i, x in enumerate((78, 158, 238, 318)):
        cable(l, [(x - 3, 44), (x, 96), (x - 2, 142)], 9, 2)
        l.relleno_circ(x, 168, 26, GRIS2); l.circ(x, 168, 26, 2.0)
        l.relleno_circ(x - 8, 160, 10, "#F8F5EC", 0.9, ry=7)
        l.caja(x - 24, 208, 48, 20, 1.2)                 # placa con el numero
        l.linea(x - 16, 218, x + 16, 218, 1.1, GRIS)
        for k in range(i + 1):                           # marcas de conteo
            l.linea(x - 15 + k * 8, 213, x - 15 + k * 8, 223, 1.5)
    l.linea(0, 262, W, 258, 1.6)
    return l

def v12():
    """una de las celdas apagadas, de cerca"""
    l = Lamina(W, H, 132.0 + VARIANTE)
    cable(l, [(196, -8), (202, 40), (198, 84)], 14, 3)
    l.relleno_circ(200, 152, 62, GRIS2); l.circ(200, 152, 62, 2.4)
    for a in (34, -28):                                  # grietas
        ang = math.radians(a)
        pts = [(200 + math.cos(ang) * 12, 152 + math.sin(ang) * 12)]
        for k in range(1, 5):
            pts.append((200 + math.cos(ang) * (12 + k * 13) + (-1) ** k * 7,
                        152 + math.sin(ang) * (12 + k * 13) + (-1) ** k * 5))
        l.poli(pts, 1.8)
    for sx in (-1, 1):                                   # ojos apagados: dos X
        ex = 200 + 22 * sx
        l.linea(ex - 9, 138, ex + 9, 154, 2.0)
        l.linea(ex + 9, 138, ex - 9, 154, 2.0)
    l.poli([(186, 176), (200, 170), (214, 176)], 1.8)    # boca hacia abajo
    l.caja(150, 236, 100, 26, 1.4)
    for k in range(1):
        l.linea(190, 244, 190, 256, 1.6)
    l.linea(166, 250, 234, 250, 1.1, GRIS)
    for i in range(4):                                   # polvo
        l.circ(120 + i * 55, 96 + (i % 2) * 18, 3 + i % 2, 0.9, GRIS)
    return l

def v13():
    """el ojo del sistema: un sensor en el techo que lo mira todo"""
    l = Lamina(W, H, 143.0 + VARIANTE)
    l.linea(0, 40, W, 36, 1.8)
    for i in range(5):
        l.poli([(30 + i * 84, 36), (38 + i * 84, 58), (26 + i * 84, 80)], 1.2, GRIS)
    l.relleno_caja(164, 38, 72, 22, GRIS2); l.caja(164, 38, 72, 22, 1.8)
    l.relleno_circ(200, 78, 32, GRIS2); l.circ(200, 78, 32, 2.2)
    l.relleno_circ(200, 84, 15, TINTA); l.circ(200, 84, 15, 1.6)
    l.relleno_circ(194, 79, 5, "#F8F5EC", 0.95)
    for s in (-1, 1):                                    # cono de vision, a trazos
        for k in range(7):
            y = 118 + k * 22
            w = 18 + k * 15
            l.linea(200 + s * w * 0.6, y, 200 + s * w, y + 8, 1.1, GRIS)
    l.poli([(200, 116), (128, 268)], 1.3, GRIS)
    l.poli([(200, 116), (272, 268)], 1.3, GRIS)
    for i in range(3):
        cable(l, [(150 - i * 40, 36), (168 - i * 30, 52), (176, 62)], 6, 0)
    return l

def v14():
    """el primer paso: el suelo se enciende detras"""
    l = Lamina(W, H, 154.0 + VARIANTE)
    l.linea(0, 214, W, 210, 2.0)                         # suelo
    for i in range(7):                                   # celdas ya pisadas
        x = 24 + i * 38
        l.relleno_caja(x, 190, 30, 22, CIANC, 0.85 - i * 0.09)
        l.caja(x, 190, 30, 22, 1.3, CIAN)
        for k in range(2):
            l.poli([(x + 8 + k * 12, 188), (x + 4 + k * 12, 176), (x + 11 + k * 12, 178)],
                   1.3, CIAN)
    l.circ(316, 168, 34, 4.4, CIAN)                      # TSL-04
    l.circ(316, 168, 34, 1.8, CIANC, pasadas=1)
    l.relleno_circ(310, 164, 12, CIAN, 0.9, ry=9)
    l.poli([(292, 150), (316, 142), (340, 148)], 4.0, CIAN, pasadas=1)
    for k in range(3):                                   # lineas de movimiento
        l.linea(360 + k * 4, 150 + k * 12, 392 + k * 4, 150 + k * 12, 1.6, CIAN, pasadas=1)
    return l

def v15():
    """mira atras y ve su propia estela"""
    l = Lamina(W, H, 165.0 + VARIANTE)
    l.linea(0, 226, W, 222, 2.0)
    for i in range(10):                                  # la estela se pierde a lo lejos
        x = 8 + i * 34
        al = 0.9 - i * 0.07
        l.relleno_caja(x, 202, 27, 22, CIANC, max(al, 0.12))
        l.caja(x, 202, 27, 22, 1.2, CIAN)
    l.circ(330, 158, 42, 4.6, CIAN)
    l.circ(330, 158, 42, 1.8, CIANC, pasadas=1)
    ojo = []                                             # el ojo mirando hacia atras
    for i in range(22):
        t = i / 21.0
        ojo.append((330 - 34 + 40 * t, 158 - 16 * math.sin(math.pi * t)))
    for i in range(22):
        t = 1 - i / 21.0
        ojo.append((330 - 34 + 40 * t, 158 + 13 * math.sin(math.pi * t)))
    l.relleno(ojo, CIAN); l.poli(ojo, 1.8, CIAN, cerrar=True, pasadas=1)
    l.relleno_circ(304, 158, 7, "#F7F3E9", 0.95)
    l.poli([(290, 132), (330, 122), (368, 130)], 4.0, CIAN, pasadas=1)
    for k in range(3):                                   # signos de alarma
        l.linea(376 + k * 6, 104 - k * 6, 386 + k * 6, 88 - k * 6, 2.0, CIAN, pasadas=1)
    return l

def v16():
    """las puertas se cierran por sectores"""
    l = Lamina(W, H, 176.0 + VARIANTE)
    for i in range(5):                                   # pasillo en fuga
        k = i / 4.0
        w = 300 - k * 190; h = 200 - k * 128
        x = 200 - w / 2; y = 150 - h / 2
        l.caja(x, y, w, h, 2.0 - k * 0.6)
    l.linea(50, 250, 130, 214, 1.3); l.linea(350, 250, 270, 214, 1.3)
    for i, (k, baja) in enumerate([(0.0, 0.30), (0.28, 0.55), (0.56, 0.80)]):
        w = 300 - k * 190; h = 200 - k * 128
        x = 200 - w / 2; y = 150 - h / 2
        l.relleno_caja(x, y, w, h * baja, GRIS2, 0.9)    # compuerta bajando
        l.caja(x, y, w, h * baja, 1.8)
        for c in range(4):                               # nervios de la compuerta
            l.linea(x + w * (c + 1) / 5, y, x + w * (c + 1) / 5, y + h * baja, 1.1, GRIS)
        for s in (-1, 1):                                # flechas hacia abajo
            ax = 200 + s * (w / 2 + 12)
            l.poli([(ax, y + 10), (ax, y + h * baja - 6)], 1.4)
            l.poli([(ax - 5, y + h * baja - 14), (ax, y + h * baja - 5), (ax + 5, y + h * baja - 14)], 1.4)
    return l

def v17():
    """los drones salen del nicho"""
    l = Lamina(W, H, 187.0 + VARIANTE)
    l.linea(0, 250, W, 246, 1.8)
    l.relleno_caja(20, 44, 116, 138, GRIS2); l.caja(20, 44, 116, 138, 2.0)
    l.relleno_caja(34, 60, 88, 106, "#F7F3E9"); l.caja(34, 60, 88, 106, 1.6)  # nicho abierto
    for i in range(4):
        l.linea(34, 74 + i * 24, 122, 74 + i * 24, 1.0, GRIS)
    for i, (dx, dy, e) in enumerate([(150, 96, 1.0), (216, 140, 0.85), (280, 84, 0.75), (330, 168, 0.62)]):
        s = e
        l.relleno_caja(dx - 15 * s, dy - 8 * s, 30 * s, 16 * s, TINTA)
        for sx in (-1, 1):
            for sy in (-1, 1):
                l.linea(dx, dy, dx + 28 * s * sx, dy + 14 * s * sy, 2.2 * s, TINTA, pasadas=1)
                l.relleno_circ(dx + 28 * s * sx, dy + 14 * s * sy, 12 * s, TINTA, 0.85, ry=4 * s)
        for k in range(2):                               # rastro
            l.linea(dx - 34 * s - k * 10, dy - 4 + k * 8, dx - 20 * s - k * 10, dy - 4 + k * 8,
                    1.2, TINTA, pasadas=1)
    return l

def v18():
    """la carga se acaba"""
    l = Lamina(W, H, 198.0 + VARIANTE)
    l.linea(0, 244, W, 240, 1.8)
    l.circ(144, 156, 46, 3.0, CIAN)                      # TSL-04, debil: trazo mas fino
    l.circ(144, 156, 46, 1.2, CIANC, pasadas=1)
    for sx in (-1, 1):                                   # ojos entrecerrados
        l.poli([(144 + sx * 22 - 11, 152), (144 + sx * 22, 158), (144 + sx * 22 + 11, 152)],
               2.6, CIAN, pasadas=1)
    l.poli([(130, 178), (144, 174), (158, 178)], 2.0, CIAN, pasadas=1)
    for k in range(3):                                   # chispas que se caen
        l.poli([(112 - k * 8, 196 + k * 6), (106 - k * 8, 210 + k * 8)], 1.4, CIAN, pasadas=1)
    l.caja(238, 118, 128, 34, 2.0)                       # medidor de carga
    l.relleno_caja(243, 123, 26, 24, CIAN, 0.9)
    for k in range(4):
        l.linea(272 + k * 23, 118, 272 + k * 23, 152, 1.1, GRIS)
    l.caja(238, 164, 128, 12, 1.3)
    l.linea(246, 170, 300, 170, 1.6, TINTA)
    hx, hy = 302, 214                                    # reloj casi vacio
    l.linea(hx - 14, hy - 20, hx + 14, hy - 20, 2.6, CIAN, pasadas=1)
    l.linea(hx - 14, hy + 20, hx + 14, hy + 20, 2.6, CIAN, pasadas=1)
    l.relleno([(hx - 11, hy + 18), (hx + 11, hy + 18), (hx, hy + 4)], CIAN, 0.6)
    l.poli([(hx - 12, hy - 18), (hx, hy), (hx - 12, hy + 18)], 2.0, CIAN, pasadas=1)
    l.poli([(hx + 12, hy - 18), (hx, hy), (hx + 12, hy + 18)], 2.0, CIAN, pasadas=1)
    return l

# ================================================================= EL FINAL
# El storyboard original acababa en la vineta 9, el escape, y la intro nunca la
# llego a usar: termina en la 8, en el conducto. El final la recupera y cierra
# los hilos que abre la intro rimando con sus vinetas, porque una rima se
# reconoce sin tener que explicarla:
#   la 8  (el conducto con el reloj de arena)  -> la 19 (el conducto acaba en luz)
#   la 14 (da un paso y el suelo se enciende)  -> la 21 (da un paso y no)
#   la 18 (la carga se acaba)                  -> la 22 (el sol se la llena)
#   la 11 (cuatro celdas, tres apagadas)       -> la 24 (se encienden tres luces)
# Mismo papel, misma tinta y el cian solo donde esta TSL-04 o su luz. El amarillo,
# que en la intro no aparece, es la luz de fuera: el dia.

def tsl_orbe(l, cx, cy, r):
    """TSL-04 de lejos, como en las vinetas 8 y 9: orbe lleno con su brillo"""
    l.relleno_circ(cx, cy, r, CIAN); l.circ(cx, cy, r, 2.0, TINTA)
    l.relleno_circ(cx - r * 0.22, cy - r * 0.22, r * 0.33, "#F7F3E9", 0.95, ry=r * 0.38)

def tsl_cara(l, cx, cy, r, ojos="abiertos"):
    """TSL-04 de cerca, como en las vinetas 14 y 18: contorno grueso y cara"""
    l.circ(cx, cy, r, 4.4, CIAN)
    l.circ(cx, cy, r, 1.8, CIANC, pasadas=1)
    for sx in (-1, 1):
        x = cx + sx * r * 0.44
        if ojos == "contentos":                          # ^ ^ : ojos cerrados de gusto
            l.poli([(x - r * 0.2, cy - r * 0.04), (x, cy - r * 0.24), (x + r * 0.2, cy - r * 0.04)],
                   2.8, CIAN, pasadas=1)
        else:
            l.relleno_circ(x, cy - r * 0.08, r * 0.15, CIAN, 0.95, ry=r * 0.2)
    l.arco(cx, cy + r * 0.2, r * 0.32, 25, 155, 2.4, CIAN, ry=r * 0.2, pasadas=1)   # sonrisa

def hierba(l, x0, x1, y, paso=10, alto=13, gr=1.1):
    """matas de hierba: dos trazos cada una, con alturas que no se repiten"""
    i = 0
    x = x0
    while x < x1:
        h = alto * (0.55 + 0.45 * ((i * 37) % 10) / 10.0)
        l.poli([(x, y), (x - 3, y - h)], gr, pasadas=1)
        l.poli([(x + 3, y), (x + 6, y - h * 0.7)], gr * 0.9, pasadas=1)
        x += paso
        i += 1

def sol(l, cx, cy, r, rayos=9, desde=180.0, hasta=360.0):
    l.relleno_circ(cx, cy, r, AMAR, 0.9)
    l.circ(cx, cy, r, 1.8)
    for k in range(rayos):
        a = math.radians(desde + (hasta - desde) * (k + 0.5) / rayos)
        l.linea(cx + math.cos(a) * (r + 7), cy + math.sin(a) * (r + 7),
                cx + math.cos(a) * (r + 20), cy + math.sin(a) * (r + 20), 1.6, pasadas=1)

def estela_que_se_apaga(l, pts, r0=5.0):
    """la estela de lejos: puntos que se achican y se aclaran hacia atras"""
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        t = (i + 1) / float(n)
        l.relleno_circ(x, y, r0 * (0.35 + 0.65 * t), CIAN, 0.15 + 0.7 * t)

# ------------------------------------------------ 19 el conducto acaba en luz
def v19():
    """al final del conducto hay una rejilla, y detras luz de verdad"""
    l = Lamina(W, H, 209.0 + VARIANTE)
    for i in range(14):                                  # la misma trama que la 8
        x = -40 + i * 34
        l.linea(x, 300, x + 116, 10, 0.9, GRIS, pasadas=1, amp=1.2)
    gx, gy, gw, gh = 296, 40, 86, 86
    x0, y0, x1, y1 = 6, 268, gx + 6, gy + gh * 0.55
    def en(x, off=0.0):                                  # altura del conducto en x
        return y0 + (y1 - y0) * (x - x0) / (x1 - x0) + off
    for k in range(6):                                   # la luz que entra por la rejilla
        l.linea(gx + 8 + k * 13, gy + gh, gx - 70 + k * 20, gy + gh + 130, 1.3, AMAR, pasadas=1)
    for off in (-13, 0, 13):                             # el conducto, ahora hacia la luz
        l.linea(x0 + off * 0.2, en(x0, off), x1 + off * 0.2, en(x1, off), 2.0 if off == 0 else 1.6)
    l.relleno_caja(gx, gy, gw, gh, AMAR, 0.6)            # la rejilla, con el dia detras
    for k in range(5):
        x = gx + gw * (k + 0.5) / 5
        l.linea(x, gy + 2, x, gy + gh - 2, 2.2)
    l.caja(gx, gy, gw, gh, 2.4)
    l.poli([(44, en(44)), (104, en(104)), (164, en(164))], 4.6, CIAN, pasadas=1)   # estela
    tsl_orbe(l, 198, en(198) - 4, 18)
    return l

# --------------------------------------------------- 20 la granja al amanecer
def v20():
    """al otro lado de la ciudad hay campos: la granja de la 9, de cerca"""
    l = Lamina(W, H, 220.0 + VARIANTE)
    hz = 196
    sol(l, 214, hz, 38)
    l.relleno_caja(0, hz, W, H - hz, "#EDE7D9")          # la tierra tapa medio sol
    l.linea(0, hz, W, hz - 3, 1.8)
    for x, w, h in [(6, 16, 30), (24, 12, 44), (38, 18, 24), (58, 10, 36)]:   # la ciudad, lejos
        l.relleno_caja(x, hz - h, w, h, GRIS2); l.caja(x, hz - h, w, h, 1.0)
    l.relleno_caja(286, 124, 80, 72, GRIS2); l.caja(286, 124, 80, 72, 1.9)     # granero
    l.relleno([(278, 124), (326, 92), (374, 124)], GRIS)
    l.poli([(278, 124), (326, 92), (374, 124)], 1.9, cerrar=True)
    l.relleno_caja(312, 156, 28, 40, "#F7F3E9"); l.caja(312, 156, 28, 40, 1.4)
    l.relleno_caja(372, 100, 22, 96, GRIS2); l.caja(372, 100, 22, 96, 1.7)     # silo
    l.arco(383, 100, 11, 180, 360, 1.7, ry=9)
    for i in range(11):                                  # valla
        l.linea(10 + i * 24, hz + 20, 10 + i * 24, hz + 40, 1.3)
    l.linea(4, hz + 28, 264, hz + 26, 1.3)
    l.poli([(78, 298), (150, 250), (204, 212)], 1.2, GRIS)                     # el camino
    # llega por el horizonte, POR DETRAS de la valla: en la primera version iba
    # montada sobre el travesano y parecia un adorno de la valla
    estela_que_se_apaga(l, [(74, 206), (104, 204), (134, 203), (162, 202), (186, 201)])
    tsl_orbe(l, 208, 199, 10)
    hierba(l, 0, W, 300, paso=12, alto=16)
    return l

# ------------------------------------------------ 21 un paso, y no se enciende
def v21():
    """da un paso y la hierba NO se enciende (rima con la 14)"""
    l = Lamina(W, H, 231.0 + VARIANTE)
    l.linea(0, 214, W, 210, 2.0)                         # el mismo suelo que la 14
    hierba(l, 6, 284, 212, paso=11, alto=17, gr=1.3)     # donde alli habia celdas encendidas
    tsl_cara(l, 316, 168, 34, "abiertos")                # en el mismo sitio que en la 14
    for x in (60, 170):                                  # dos flores, sin prisa
        l.poli([(x, 212), (x + 2, 182)], 1.2, pasadas=1)
        l.relleno_circ(x + 2, 178, 5, AMAR, 0.9); l.circ(x + 2, 178, 5, 1.2)
    return l

# ------------------------------------------------------ 22 el sol la recarga
def v22():
    """el sol le llena la carga (rima con la 18, donde se acababa)"""
    l = Lamina(W, H, 242.0 + VARIANTE)
    l.linea(0, 244, W, 240, 1.8)
    hierba(l, 0, W, 242, paso=13, alto=10)
    sol(l, 356, 42, 24, rayos=12, desde=0.0, hasta=360.0)
    for k in range(4):                                   # la luz le llega
        l.linea(326 - k * 5, 62 + k * 5, 200 - k * 12, 112 + k * 8, 1.2, AMAR, pasadas=1)
    tsl_cara(l, 144, 156, 46, "abiertos")                # trazo grueso: ya no esta debil
    l.caja(238, 118, 128, 34, 2.0)                       # el mismo medidor de la 18...
    for k in range(4):                                   # ...con cuatro de cinco llenas
        l.relleno_caja(243 + k * 23, 123, 20, 24, CIAN, 0.9)
    for k in range(4):
        l.linea(266 + k * 23, 118, 266 + k * 23, 152, 1.1, GRIS)
    cx, cy = 354, 135                                    # y un + en la ultima: cargando
    l.linea(cx - 6, cy, cx + 6, cy, 2.2, AMAR, pasadas=1)
    l.linea(cx, cy - 6, cx, cy + 6, 2.2, AMAR, pasadas=1)
    hx, hy = 302, 206                                    # el reloj de arena, tumbado: parado
    l.linea(hx - 22, hy - 12, hx - 22, hy + 12, 2.6, CIAN, pasadas=1)
    l.linea(hx + 22, hy - 12, hx + 22, hy + 12, 2.6, CIAN, pasadas=1)
    l.poli([(hx - 20, hy - 10), (hx, hy), (hx + 20, hy - 10)], 2.0, CIAN, pasadas=1)
    l.poli([(hx - 20, hy + 10), (hx, hy), (hx + 20, hy + 10)], 2.0, CIAN, pasadas=1)
    return l

# -------------------------------------------------- 23 quieta, por fin, de noche
def v23():
    """de noche en el campo, quieta por primera vez desde aquella noche"""
    l = Lamina(W, H, 253.0 + VARIANTE)
    for x, y in [(34, 38), (92, 72), (148, 30), (232, 58), (298, 30), (356, 84), (384, 20), (190, 92)]:
        l.linea(x - 4, y, x + 4, y, 1.2, pasadas=1)      # estrellas
        l.linea(x, y - 4, x, y + 4, 1.2, pasadas=1)
    l.relleno_circ(330, 56, 20, AMAR, 0.85); l.circ(330, 56, 20, 1.6)   # luna...
    l.relleno_circ(340, 50, 18, "#EDE7D9")                               # ...creciente
    l.linea(0, 232, W, 228, 1.8)
    l.relleno_circ(200, 200, 58, CIANC, 0.30)            # su propia luz sobre la hierba
    hierba(l, 0, W, 232, paso=10, alto=14)
    tsl_cara(l, 200, 198, 34, "contentos")
    return l

# ------------------------------------------------------ 24 otras tres luces
def v24():
    """a su lado se encienden otras tres luces (rima con las celdas de la 11)"""
    l = Lamina(W, H, 264.0 + VARIANTE)
    l.linea(0, 250, W, 246, 1.8)
    for cx, cy, r in [(92, 140, 13), (312, 118, 11), (262, 214, 12)]:
        l.relleno_circ(cx, cy, r * 2.4, CIANC, 0.35)     # tres luces del mismo cian que ella
        l.relleno_circ(cx, cy, r, CIAN, 0.95); l.circ(cx, cy, r, 1.6)
    hierba(l, 0, W, 248, paso=10, alto=16)
    l.relleno_circ(186, 190, 62, CIANC, 0.30)
    tsl_cara(l, 186, 188, 40, "contentos")
    return l

VINETAS = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18,
           v19, v20, v21, v22, v23, v24]

os.makedirs("laminas", exist_ok=True)
for i, fn in enumerate(VINETAS, start=1):
    txt = fn().svg()
    suf = os.environ.get("SUF", "")
    open("laminas/v%d%s.svg" % (i, suf), "w", encoding="utf-8").write(txt)
    print("v%-3d %6d bytes" % (i, len(txt)))
