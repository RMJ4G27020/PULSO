# -*- coding: utf-8 -*-
"""Diseno de los tres niveles jugables de PULSO -> escenas de Godot.
Todo en CELDAS de 16 px. Cada nivel tiene un inicio y un final inequivocos:
se aparece sobre el ANCLAJE y se sale por el PORTAL, que la PUERTA bloquea
hasta que tocas el INTERRUPTOR."""
import os

C = 16.0
PROY = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "pulso-godot")

NIVELES = [
# Archipielagos abiertos: sin marco, sin techos, vacio por todas partes.
# El personaje mide 28 px, asi que el hueco minimo entre plataformas es de
# 7 celdas (112 px = 4 veces su tamano). Con salto de 115 px y 220 px/s,
# subir 4 celdas deja 178 px de alcance: 66 px de holgura sobre ese hueco.
{
 "id": "n1_ida_y_vuelta", "titulo": "Nivel 1  \u00b7  Ida y vuelta", "gdd": 3, "par": 40.0,
 "paleta": "cian", "ancho": 94, "alto": 40,
 "bloques": [
   (0, 32, 20, 3),      # base: aparicion, puerta y portal
   (27, 28, 10, 2),     # la ida: hueco 7, subida 4
   (44, 24, 10, 2),
   (61, 20, 10, 2),
   (78, 16, 12, 2),     # meseta de la terminal
   (61, 12, 10, 2),     # la vuelta, 8 celdas por encima de la ida
   (44, 8, 10, 2),
   (27, 4, 10, 2),
   (9, 4, 11, 2),       # repisa de salida: de aqui se cae en picado a la base
 ],
 "anclaje": (16, 31), "portal": (2, 30), "interruptor": (83, 15),
 "exentas": [], "trepadas": [],
 "puerta": (5, 29),
 "fragmentos": [(32, 27), (66, 19), (14, 3)],
 "obstaculos": [],
},
{
 "id": "n2_el_corredor", "titulo": "Nivel 2  \u00b7  El corredor", "gdd": 15, "par": 52.0,
 "paleta": "rojo", "ancho": 94, "alto": 46,
 "bloques": [
   (0, 38, 20, 3),      # base
   (27, 34, 10, 2),
   (44, 30, 10, 2),
   (61, 26, 10, 2),
   (78, 22, 12, 2),     # meseta de la terminal
   (61, 18, 10, 2),     # la vuelta
   (44, 14, 10, 2),
   (27, 10, 10, 2),
   (9, 10, 11, 2),      # repisa de salida
   (56, 10, 3, 2),      # montante del laser: cuelga solo sobre el hueco
 ],
 "anclaje": (16, 37), "portal": (2, 36), "interruptor": (83, 21),
 "exentas": [(56, 10)], "trepadas": [],
 "puerta": (5, 35),
 "fragmentos": [(36, 33), (66, 25), (14, 9)],
 "obstaculos": [
   ("pulsante", 31, 33, "desfase = 0.0"),
   ("pinchos", 49, 29),
   ("dron", 63, 24, "recorrido = Vector2(120, 0)"),
   ("pulsante", 49, 13, "desfase = 0.6"),
   ("laser", 57, 12, "largo_celdas = 4\ndesfase = 0.0"),
 ],
},
{
 "id": "n3_el_nudo", "titulo": "Nivel 3  \u00b7  El nudo", "gdd": 26, "par": 66.0,
 "paleta": "verde", "ancho": 92, "alto": 56,
 "bloques": [
   (0, 48, 20, 3),      # base
   (27, 44, 10, 2),     # primera subida
   (44, 40, 10, 2),
   (61, 36, 10, 2),
   (78, 32, 10, 2),
   (61, 28, 10, 2),     # vuelve sobre si mismo, 8 celdas mas arriba
   (44, 24, 10, 2),
   (61, 20, 12, 2),     # meseta de la terminal
   (44, 16, 10, 2),
   (27, 12, 10, 2),
   (9, 8, 11, 2),       # repisa de salida, arriba del todo
   (39, 8, 3, 2),       # montante del laser
   (56, 16, 3, 2),      # montante del zapador
 ],
 "anclaje": (16, 47), "portal": (11, 6), "interruptor": (66, 19),
 "exentas": [(39, 8), (56, 16)], "trepadas": [],
 "puerta": (15, 5),
 "fragmentos": [(36, 43), (83, 31), (32, 11)],
 "obstaculos": [
   ("pulsante", 31, 43, "desfase = 0.0"),
   ("dron", 46, 38, "recorrido = Vector2(120, 0)"),
   ("pinchos", 66, 35),
   ("pulsante", 49, 23, "desfase = 0.5"),
   ("zapador", 57, 18),
   ("laser", 40, 10, "largo_celdas = 4\ndesfase = 0.2"),
 ],
},
{
 # Rescata la adherencia a la pared: estaba programada, animada y con coste de
 # carga, pero al abrir los niveles se quedo sin una sola pared y no se
 # disparaba nunca. Aqui el pozo SOLO se sube saltando de pared a pared.
 "id": "n4_la_chimenea", "titulo": "Nivel 4  \u00b7  La chimenea", "gdd": 21, "par": 58.0,
 "paleta": "cian", "ancho": 74, "alto": 50,
 "bloques": [
   (0, 42, 22, 3),      # base: aparicion, puerta y portal
   (29, 38, 12, 2),     # antesala del pozo
   # el pozo: dos paredes enfrentadas con 5 celdas de hueco. Cada salto de
   # pared sube 103 px, asi que 22 celdas se hacen en cuatro saltos.
   (32, 16, 1, 22),
   (38, 16, 1, 22),
   (30, 15, 3, 2),      # labio izquierdo de la boca del pozo
   (38, 15, 12, 2),     # se sale por la derecha, arriba
   (54, 11, 12, 2),     # meseta de la terminal
   (38, 7, 12, 2),      # la vuelta, por encima
   (20, 7, 14, 2),
   (4, 10, 12, 2),      # repisa de salida: de aqui se cae en picado a la base
 ],
 "anclaje": (18, 41), "portal": (2, 40), "interruptor": (59, 10),
 "exentas": [], "trepadas": [(33, 38, 38, 15)],
 "puerta": (5, 39),
 "fragmentos": [(34, 30), (60, 10), (10, 9)],
 "obstaculos": [
   ("dron", 44, 13, 'recorrido = Vector2(96, 0)'),
   ("laser", 25, 8, ''),
 ],
},
]
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grandes
NIVELES += [grandes.lasermania(), grandes.runthedrun()]

import math
G, ALT, VEL = 980.0, 115.0, 220.0
MARGEN = 56.0        # px de holgura exigidos a cada salto de subida
VS = math.sqrt(2 * G * ALT)

def alcance_horizontal(dh_px):
    """cuanto avanza en horizontal mientras esta a dh_px por encima del punto de salida"""
    if dh_px > ALT:
        return None
    return VEL * (VS + math.sqrt(max(VS * VS - 2 * G * dh_px, 0.0))) / G

def superficies(nv):
    """superficie pisable de cada bloque: (x0, x1, y) en celdas.
    Se descartan las paredes (mas altas que anchas) y el marco superior."""
    out = []
    exentas = set(nv.get("exentas", []))
    for k, (bx, by, bw, bh) in enumerate(nv["bloques"]):
        if (bx, by) in exentas:           # montantes de obstaculos: no son ruta
            continue
        if bh > bw:                       # pared vertical: no se pisa
            continue
        out.append((bx, bx + bw, by, k))
    return out

def alcance_caida(df_px):
    """al caer df px, cuanto avanza en horizontal (la gravedad de caida es x1.6)"""
    t_sub = VS / G
    t_baj = math.sqrt(2 * max(df_px, 0.0) / (G * 1.6)) if df_px > 0 else 0.0
    return VEL * (t_sub + t_baj + 0.30)

def salto_pared(hueco_px):
    """cuanto sube cada salto de pared cruzando un hueco de ese ancho"""
    vx = VEL * 1.1
    t = hueco_px / vx
    return VS * t - 0.5 * G * t * t

def verifica(nv):
    """recorrido desde el anclaje: que superficies NO se alcanzan de ninguna manera"""
    sup = superficies(nv)
    ax, ay = nv["anclaje"]
    # superficie de partida: la que esta justo debajo del anclaje
    inicio = None
    for idx, (x0, x1, y, _) in enumerate(sup):
        if x0 <= ax <= x1 and y >= ay:
            if inicio is None or y < sup[inicio][2]:
                inicio = idx
    if inicio is None:
        return [("sin suelo bajo el anclaje", ax, ay)]

    def conecta(a, b):
        x0, x1, y, _ = sup[a]
        a0, a1, ay2, _ = sup[b]
        hueco = max(a0 - x1, x0 - a1, 0) * C
        if ay2 < y:                                   # hay que subir
            r = alcance_horizontal((y - ay2) * C)
            # MARGEN: nadie salta desde el pixel exacto del borde ni aterriza
            # en el primer pixel de la repisa. Sin esta holgura salen niveles
            # que el papel dice que pasan y las manos dicen que no.
            return r is not None and hueco + MARGEN <= r
        return hueco <= alcance_caida((ay2 - y) * C)  # mismo nivel o caida

    # chimeneas: si el hueco entre paredes deja subir, conectan abajo con arriba
    extra = []
    for (cx0, cx1, y_bajo, y_alto) in nv.get("trepadas", []):
        sube = salto_pared((cx1 - cx0) * C)
        if sube <= 8.0:
            extra.append(("chimenea de %d celdas: cada salto sube %.0f px, no basta"
                          % (cx1 - cx0, sube), cx0, y_bajo))
            continue
        bajos = [i for i, (x0, x1, y, _) in enumerate(sup) if y >= y_bajo - 1 and x1 >= cx0 - 1 and x0 <= cx1 + 1]
        altos = [i for i, (x0, x1, y, _) in enumerate(sup) if abs(y - y_alto) <= 2 and x1 >= cx0 - 3 and x0 <= cx1 + 3]
        for a in bajos:
            for b in altos:
                extra.append((a, b))

    vistos = {inicio}
    pila = [inicio]
    while pila:
        a = pila.pop()
        for b in range(len(sup)):
            if b in vistos:
                continue
            if conecta(a, b) or (a, b) in extra:
                vistos.add(b); pila.append(b)
    return [(sup[i][0], sup[i][2]) for i in range(len(sup)) if i not in vistos]

def holguras(nv):
    """El jugador ocupa 28 px = 1.75 celdas, o sea necesita 2 celdas libres.
    Marca los pasillos y huecos por los que no cabe."""
    W, H = nv["ancho"], nv["alto"]
    solido = [[False] * H for _ in range(W)]
    for bx, by, bw, bh in nv["bloques"]:
        for x in range(max(bx, 0), min(bx + bw, W)):
            for y in range(max(by, 0), min(by + bh, H)):
                solido[x][y] = True
    def libre(x, y):
        # ya no hay marco: fuera del mapa es aire (y mas abajo, el vacio)
        if not (0 <= x < W and 0 <= y < H):
            return True
        return not solido[x][y]
    def cabe(x, y):
        return libre(x, y) and libre(x + 1, y) and libre(x, y + 1) and libre(x + 1, y + 1)

    estrechos = []
    for x in range(W - 1):
        for y in range(H - 1):
            if not libre(x, y):
                continue
            # hueco vertical de 1 celda entre dos bloques (pasillo estrecho)
            if libre(x, y) and not libre(x - 1, y) and not libre(x + 1, y):
                if libre(x, y + 1) or libre(x, y - 1):
                    estrechos.append(("paso vertical de 1 celda", x, y))
            # techo bajo: suelo debajo y techo a 1 celda
            if not libre(x, y + 1) and not libre(x, y - 1):
                estrechos.append(("techo a 1 celda del suelo", x, y))
    # quitar repetidos por columnas contiguas
    vistos, out = set(), []
    for tipo, x, y in estrechos:
        k = (tipo, x // 3, y // 3)
        if k not in vistos:
            vistos.add(k); out.append((tipo, x, y))
    return out[:6]

def es_pared(bw, bh):
    """Un bloque mucho mas alto que ancho es una pared, no una plataforma."""
    return bh >= 4 and bh > bw * 3

def techos_bajos(nv, margen=5):
    """Avisa de tramos apretados: menos de `margen` celdas de aire encima.
    El liston son 80 px, casi 3 veces el personaje (28 px), que sobra para
    andar y para los saltos que pide la ruta. NO se exige que quepa un salto
    a maxima altura (7.19 celdas) en todas partes: eso no lo cumple ningun
    nivel que tenga una vuelta pasando por encima de la ida."""
    W, H = nv["ancho"], nv["alto"]
    solido = [[False] * H for _ in range(W)]
    for bx, by, bw, bh in nv["bloques"]:
        # Las PAREDES no cuentan como techo: contra una pared no te golpeas la
        # cabeza, te topas de lado, y ese es justo el sitio donde el juego
        # quiere que te pegues para trepar. Sin esta excepcion, cualquier
        # chimenea sale marcada como tramo apretado.
        if es_pared(bw, bh):
            continue
        for x in range(max(bx, 0), min(bx + bw, W)):
            for y in range(max(by, 0), min(by + bh, H)):
                solido[x][y] = True
    out = []
    for x0, x1, y, _ in superficies(nv):
        for x in range(max(x0, 0), min(x1, W)):
            for dy in range(1, margen + 1):
                yy = y - dy
                if 0 <= yy < H and solido[x][yy]:
                    out.append((x, y, dy)); break
    vistos, res = set(), []
    for x, y, dy in out:
        k = (x // 4, y)
        if k not in vistos:
            vistos.add(k); res.append((x, y, dy))
    return res[:6]

REC = {"laser": "7_laser", "dron": "8_dron", "zapador": "9_zap",
       "pinchos": "10_pinchos", "pulsante": "11_pulsante"}

def genera(nv):
    ext = [
     '[ext_resource type="Script" path="res://scripts/nivel.gd" id="1_nivel"]',
     '[ext_resource type="Script" path="res://scripts/rejilla_estela.gd" id="2_estela"]',
     '[ext_resource type="PackedScene" path="res://escenas/Jugador.tscn" id="3_jugador"]',
     '[ext_resource type="Texture2D" path="res://arte/elementos/bloque_bloque.png" id="4_bloque"]',
     '[ext_resource type="Texture2D" path="res://arte/elementos/pared_pared.png" id="15_pared"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/Portal.tscn" id="5_portal"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/Anclaje.tscn" id="6_anclaje"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/LaserEmisor.tscn" id="7_laser"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/DronPurga.tscn" id="8_dron"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/DronZapador.tscn" id="9_zap"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/Pinchos.tscn" id="10_pinchos"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/BloquePulsante.tscn" id="11_pulsante"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/Interruptor.tscn" id="12_inter"]',
     '[ext_resource type="PackedScene" path="res://escenas/obstaculos/Puerta.tscn" id="13_puerta"]',
     '[ext_resource type="SpriteFrames" path="res://arte/fondo/fondo_spriteframes.tres" id="14_fondo"]',
    ]
    if nv.get("balizas"):
        ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/Baliza.tscn" id="16_baliza"]')
    sub, nodos, formas = [], [], {}
    def forma(w, h):
        k = (round(w,1), round(h,1))
        if k not in formas:
            sid = "s%d" % len(formas); formas[k] = sid
            sub.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)' % (sid, w, h))
        return formas[k]

    nodos.append('[node name="Nivel" type="Node2D"]\nscript = ExtResource("1_nivel")\n'
                 'titulo = "%s"\npar = %g\nlimite_caida = %g'
                 % (nv["titulo"], nv["par"], (max(b[1] + b[3] for b in nv["bloques"]) + 8) * C))
    # el fondo va primero y en una capa por debajo: es el interior de la
    # maquina visto de lejos, y se mueve a un cuarto de la camara para dar
    # profundidad sin robarle atencion a las plataformas
    # Parallax2D y no ParallaxBackground: con estiramiento "expand" el viewport
    # se ensancha a 780 px y el motion_mirroring del nodo viejo dejaba de
    # repetir, asi que salia media pantalla en negro. repeat_times cubre de
    # sobra en los dos ejes.
    nodos.append('[node name="Fondo" type="CanvasLayer" parent="."]\nlayer = -10')
    nodos.append('[node name="Capa" type="Parallax2D" parent="Fondo"]\n'
                 'follow_viewport = false\n'
                 'scroll_scale = Vector2(0.25, 0.12)\n'
                 'repeat_size = Vector2(640, 358)\nrepeat_times = 4')
    nodos.append('[node name="Placa" type="AnimatedSprite2D" parent="Fondo/Capa"]\n'
                 'sprite_frames = ExtResource("14_fondo")\nanimation = &"placa"\n'
                 'autoplay = "placa"\ncentered = false\n'
                 'position = Vector2(0, %g)' % (-160.0))
    nodos.append('[node name="Geometria" type="StaticBody2D" parent="."]')
    for i, (cx, cy, cw, ch) in enumerate(nv["bloques"]):
        x, y, w, h = cx * C, cy * C, cw * C, ch * C
        nodos.append('[node name="C%02d" type="CollisionShape2D" parent="Geometria"]\n'
                     'position = Vector2(%g, %g)\nshape = SubResource("%s")'
                     % (i, x + w / 2, y + h / 2, forma(w, h)))
        # una pared lleva su propia textura: la del suelo tiene la tira cian
        # en el canto de arriba, y esa tira significa "aqui se pisa"
        tex = "15_pared" if es_pared(cw, ch) else "4_bloque"
        nodos.append('[node name="V%02d" type="Sprite2D" parent="Geometria"]\n'
                     'texture = ExtResource("%s")\ncentered = false\n'
                     'position = Vector2(%g, %g)\nscale = Vector2(0.3333, 0.3333)\n'
                     'texture_repeat = 2\nregion_enabled = true\nregion_rect = Rect2(0, 0, %g, %g)'
                     % (i, tex, x, y, w * 3.0, h * 3.0))
    nodos.append('[node name="Estela" type="Node2D" parent="." groups=["estela"]]\nscript = ExtResource("2_estela")')
    ax, ay = nv["anclaje"]
    nodos.append('[node name="Aparicion" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (ax * C, ay * C))
    nodos.append('[node name="Anclaje" parent="." instance=ExtResource("6_anclaje")]\nposition = Vector2(%g, %g)' % (ax * C, ay * C + 14))
    for i, (bx, by) in enumerate(nv.get("balizas", [])):
        nodos.append('[node name="Baliza%d" parent="." instance=ExtResource("16_baliza")]\nposition = Vector2(%g, %g)'
                     % (i, bx * C, by * C + 14))
    px, py = nv["portal"]
    nodos.append('[node name="Salida" parent="." instance=ExtResource("5_portal")]\nposition = Vector2(%g, %g)' % (px * C, py * C))
    ix, iy = nv["interruptor"]
    nodos.append('[node name="Interruptor" parent="." instance=ExtResource("12_inter")]\nposition = Vector2(%g, %g)' % (ix * C, iy * C))
    dx, dy = nv["puerta"]
    nodos.append('[node name="Puerta" parent="." instance=ExtResource("13_puerta")]\nposition = Vector2(%g, %g)' % (dx * C, dy * C))
    if nv["fragmentos"]:
        nodos.append('[node name="Fragmentos" type="Node2D" parent="."]')
        sid = "sf"
        sub.append('[sub_resource type="CircleShape2D" id="sf"]\nradius = 10.0')
        for i, (fx, fy) in enumerate(nv["fragmentos"]):
            nodos.append('[node name="F%d" type="Area2D" parent="Fragmentos"]\nposition = Vector2(%g, %g)' % (i, fx * C, fy * C))
            nodos.append('[node name="Col" type="CollisionShape2D" parent="Fragmentos/F%d"]\nshape = SubResource("sf")' % i)
            nodos.append('[node name="Vis" type="Polygon2D" parent="Fragmentos/F%d"]\n'
                         'color = Color(0.78, 0.95, 0.31, 1)\n'
                         'polygon = PackedVector2Array(0, -11, 9, 0, 0, 11, -9, 0)' % i)
    nodos.append('[node name="Peligros" type="Node2D" parent="."]')
    for i, o in enumerate(nv["obstaculos"]):
        clase, ox, oy = o[0], o[1] * C, o[2] * C
        extra = o[3] if len(o) > 3 else ""
        nodos.append('[node name="%s%d" parent="Peligros" instance=ExtResource("%s")]\n'
                     'position = Vector2(%g, %g)%s'
                     % (clase.capitalize(), i, REC[clase], ox, oy, ("\n" + extra) if extra else ""))
    nodos.append('[node name="Jugador" parent="." instance=ExtResource("3_jugador")]')
    # El HUD ya no vive en la escena: nivel.gd monta escenas/Hud.tscn (scripts/hud.gd,
    # de una pieza). Se deja la capa vacia, que es como estan los cuatro primeros.
    nodos.append('[node name="HUD" type="CanvasLayer" parent="."]')
    return ('[gd_scene load_steps=%d format=3]\n\n%s\n\n%s\n\n%s\n'
            % (len(ext) + len(sub) + 1, "\n".join(ext), "\n\n".join(sub), "\n\n".join(nodos)))

D = os.path.join(PROY, "escenas", "niveles")
# `--solo n5_lasermania` escribe solo esa escena (y comprueba solo esa)
SOLO = sys.argv[sys.argv.index("--solo") + 1] if "--solo" in sys.argv else ""
for nv in NIVELES:
    if SOLO and nv["id"] != SOLO:
        continue
    open(os.path.join(D, nv["id"] + ".tscn"), "w", encoding="utf-8").write(genera(nv))
    h = verifica(nv)
    g = holguras(nv)
    t = techos_bajos(nv)
    print("%-18s %2d bloques  %d obstaculos  vacio en y=%.0f  alcance: %s"
          % (nv["id"], len(nv["bloques"]), len(nv["obstaculos"]),
             (max(b[1] + b[3] for b in nv["bloques"]) + 8) * C,
             "OK" if not h else "FALLA %s" % h))
    for tipo, x, y in g:
        print("        ESTRECHO en (%2d,%2d): %s" % (x, y, tipo))
    for x, y, dy in t:
        print("        APRETADO en (%2d,%2d): solo %d px de aire (%.1f veces el personaje)"
              % (x, y, (dy - 1) * 16, (dy - 1) * 16 / 28.0))
