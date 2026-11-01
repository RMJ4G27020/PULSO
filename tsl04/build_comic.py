# -*- coding: utf-8 -*-
"""
Las 9 vinetas del storyboard de PULSO, dibujadas como comic.
Geometria 3D renderizada con Freestyle: linea de tinta sobre papel crema,
con color plano solo donde el storyboard original lo lleva.

blender -b --factory-startup --python build_comic.py -- --render
"""
import bpy, math, os, sys
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
SOLO = int(ARGS[ARGS.index("--solo") + 1]) if "--solo" in ARGS else None
OUT = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(OUT, "comic")
os.makedirs(DIR, exist_ok=True)

PAPEL  = (0.925, 0.898, 0.835)
BLANCO = (0.965, 0.950, 0.915)
GRIS   = (0.815, 0.795, 0.755)
GRIS2  = (0.700, 0.685, 0.650)
TINTA  = (0.105, 0.095, 0.090)
CIAN   = (0.35, 0.80, 0.92)
CIAN2  = (0.62, 0.90, 0.97)
ROJO   = (0.90, 0.26, 0.22)
AZUL   = (0.30, 0.55, 0.88)
AMAR   = (0.98, 0.85, 0.30)

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
              bpy.data.lights, bpy.data.cameras, bpy.data.objects, bpy.data.linestyles):
        for b in list(c):
            try: c.remove(b)
            except Exception: pass

def plano(nombre, color):
    """material de relleno plano: sin sombreado, como una tinta de comic"""
    m = bpy.data.materials.new(nombre); m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL': nt.nodes.remove(n)
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs[0].default_value = (*color, 1)
    nt.links.new(e.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    return m

def caja(loc, esc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = esc; o.data.materials.append(m); return o

def cil(loc, r, h, m, rot=(0, 0, 0), v=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object; o.data.materials.append(m); return o

def bola(loc, r, m, esc=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=14, radius=r, location=loc)
    o = bpy.context.object; o.scale = esc; o.data.materials.append(m)
    bpy.ops.object.shade_smooth(); return o

def tubo(pts, grosor, m, cerrado=False):
    cu = bpy.data.curves.new("c", 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = grosor; cu.resolution_u = 4; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (p[0], p[1], p[2], 1.0)
    o = bpy.data.objects.new("tubo", cu); o.data.materials.append(m)
    bpy.context.collection.objects.link(o); return o

# ------------------------------------------------------------------ elementos
def tsl(loc, esc=1.0, despierta=True, ojos_x=False):
    M_C = plano("c", CIAN if despierta else GRIS)
    M_B = plano("b", BLANCO); M_T = plano("t", TINTA)
    cuerpo = bola(loc, 0.5 * esc, M_C)
    if not despierta:
        return cuerpo
    for sx in (-1, 1):
        ex = loc[0] + 0.185 * esc * sx
        ez = loc[2] + 0.04 * esc
        ey = loc[1] - 0.40 * esc
        bola((ex, ey, ez), 0.185 * esc, M_B, (1, 0.5, 1.15))
        if ojos_x:
            for a in (45, -45):
                caja((ex, ey - 0.06 * esc, ez), (0.26 * esc, 0.04 * esc, 0.05 * esc), M_T,
                     rot=(0, math.radians(a), 0))
        else:
            bola((ex, ey - 0.07 * esc, ez - 0.01 * esc), 0.13 * esc, M_T, (1, 0.45, 1.1))
    if not ojos_x:
        pts = []
        for i in range(9):
            t = i / 8.0
            x = loc[0] + (-0.10 + 0.20 * t) * esc
            z = loc[2] + (-0.15 - 0.045 * math.sin(math.pi * t)) * esc
            y = loc[1] - math.sqrt(max(0.25 - ((x - loc[0]) / esc) ** 2 - ((z - loc[2]) / esc) ** 2, 0)) * esc - 0.01
            pts.append((x, y, z))
        tubo(pts, 0.016 * esc, M_T)
    return cuerpo

def bastidores(n=7, ancho=1.1, sep=1.5, z0=-2.0, alturas=None):
    M_G = plano("g", GRIS); M_B = plano("b", BLANCO); M_R = plano("r", GRIS2)
    for i in range(n):
        h = (alturas[i % len(alturas)] if alturas else 3.2 + (i % 3) * 0.7)
        x = (i - (n - 1) / 2.0) * sep
        caja((x, 1.2, z0 + h / 2), (ancho, 1.0, h), M_G)
        for j in range(int(h / 0.55)):
            caja((x, 0.66, z0 + 0.35 + j * 0.55), (ancho * 0.72, 0.06, 0.14),
                 M_B if (i + j) % 3 else M_R)

def ductos(n=5, y=2.0, z=2.6):
    M_B = plano("b", BLANCO)
    for i in range(n):
        pts = [(-9 + k * 3.0, y + 0.3 * math.sin(k + i), z + 0.35 * i + 0.25 * math.sin(k * 1.3 + i))
               for k in range(7)]
        tubo(pts, 0.11 + 0.03 * (i % 3), M_B)

def terminal(loc, color_pantalla, esc=1.0):
    M_G = plano("g", GRIS); M_B = plano("b", BLANCO); M_P = plano("p", color_pantalla)
    caja(loc, (1.5 * esc, 0.7 * esc, 1.1 * esc), M_G)
    caja((loc[0], loc[1] - 0.38 * esc, loc[2] + 0.08 * esc),
         (1.15 * esc, 0.06 * esc, 0.68 * esc), M_P)
    caja((loc[0], loc[1] - 0.30 * esc, loc[2] - 0.62 * esc),
         (1.3 * esc, 0.5 * esc, 0.16 * esc), M_B)          # teclado
    return None

def dron(loc, esc=1.0):
    M_G = plano("g", GRIS); M_B = plano("b", BLANCO); M_R = plano("r", ROJO)
    caja(loc, (1.05 * esc, 0.55 * esc, 0.38 * esc), M_G)
    caja((loc[0] + 0.05 * esc, loc[1], loc[2] + 0.26 * esc), (0.55 * esc, 0.42 * esc, 0.18 * esc), M_B)
    bola((loc[0] - 0.30 * esc, loc[1] - 0.30 * esc, loc[2]), 0.15 * esc, M_R, (1, 0.55, 1))
    for sx in (-1, 1):
        caja((loc[0] + 0.52 * esc * sx, loc[1], loc[2] - 0.06 * esc),
             (0.22 * esc, 0.36 * esc, 0.30 * esc), M_B, rot=(0, math.radians(18 * sx), 0))

def rayo(p0, p1, semilla=1.0, grosor=0.06, n=9, amp=0.5, m=None):
    a, b = Vector(p0), Vector(p1)
    perp = Vector((-(b - a).z, 0, (b - a).x)).normalized()
    pts = []
    for i in range(n):
        t = i / (n - 1)
        d = math.sin(semilla * 12.9 + i * 4.14) * amp * math.sin(math.pi * t)
        p = a.lerp(b, t) + perp * d
        pts.append((p.x, p.y, p.z))
    return tubo(pts, grosor, m or plano("ray", AMAR))

def estela(pts, m=None):
    return tubo(pts, 0.09, m or plano("est", CIAN2))

# ------------------------------------------------------- piezas del boceto
def portatil(loc, color_pantalla, esc=1.0, giro=0.0):
    """portatil abierto: base con teclado y pantalla inclinada"""
    M_B = plano("pb", BLANCO); M_G = plano("pg", GRIS); M_P = plano("pp", color_pantalla)
    g = bpy.data.objects.new("portatil", None); bpy.context.collection.objects.link(g)
    g.location = loc; g.rotation_euler = (0, 0, math.radians(giro)); g.scale = (esc, esc, esc)
    def h(o): o.parent = g; return o
    h(caja((0, 0, 0), (2.6, 1.9, 0.14), M_B))                      # base
    for r in range(4):                                              # teclas
        for c in range(11):
            h(caja((-1.05 + c * 0.21, -0.55 + r * 0.24, 0.09), (0.15, 0.17, 0.03), M_G))
    h(caja((0, 0.72, 0.28), (2.5, 0.12, 1.55), M_B, rot=(math.radians(-14), 0, 0)))   # tapa
    h(caja((0, 0.66, 0.30), (2.15, 0.06, 1.22), M_G, rot=(math.radians(-14), 0, 0)))  # marco
    h(caja((0, 0.60, 0.30), (0.78, 0.06, 0.72), M_P, rot=(math.radians(-14), 0, 0)))  # cuadro de color
    return g

def dron_quad(loc, esc=1.0):
    """cuadricoptero pequeno y oscuro, como el del boceto"""
    M_T = plano("dt", TINTA)
    caja(loc, (0.55 * esc, 0.30 * esc, 0.22 * esc), M_T)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx = loc[0] + 0.52 * esc * sx
            by = loc[1] + 0.30 * esc * sy
            caja(((loc[0] + bx) / 2, (loc[1] + by) / 2, loc[2]),
                 (0.62 * esc, 0.07 * esc, 0.05 * esc), M_T,
                 rot=(0, 0, math.atan2(by - loc[1], bx - loc[0])))
            cil((bx, by, loc[2] + 0.09 * esc), 0.26 * esc, 0.035 * esc, M_T, v=14)
    return None

def reloj_arena(loc, esc=1.0, m=None):
    M = m or plano("ra", CIAN)
    caja((loc[0], loc[1], loc[2] + 0.42 * esc), (0.62 * esc, 0.10 * esc, 0.07 * esc), M)
    caja((loc[0], loc[1], loc[2] - 0.42 * esc), (0.62 * esc, 0.10 * esc, 0.07 * esc), M)
    for sz in (1, -1):
        bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.26 * esc, radius2=0.0,
            depth=0.42 * esc, location=(loc[0], loc[1], loc[2] + 0.21 * esc * sz),
            rotation=(math.radians(0 if sz < 0 else 180), 0, 0))
        bpy.context.object.data.materials.append(M)
    return None

def humo(centro, n=9, r=1.5, esc=1.0):
    M_B = plano("hb", BLANCO)
    for i in range(n):
        a = i * 2.39996
        d = r * (0.35 + 0.65 * ((i * 7) % 5) / 4.0)
        bola((centro[0] + math.cos(a) * d, centro[1] + 0.4 * ((i % 3) - 1),
              centro[2] + math.sin(a) * d * 0.55), (0.34 + 0.18 * (i % 3)) * esc, M_B)

def silla(loc, giro=0.0, esc=1.0):
    M_B = plano("sb", BLANCO); M_G = plano("sg", GRIS)
    g = bpy.data.objects.new("silla", None); bpy.context.collection.objects.link(g)
    g.location = loc; g.rotation_euler = (math.radians(20), math.radians(giro), math.radians(35))
    g.scale = (esc, esc, esc)
    def h(o): o.parent = g
    h(caja((0, 0, 0), (0.9, 0.9, 0.14), M_G))                    # asiento
    h(caja((0, 0.42, 0.55), (0.9, 0.14, 1.0), M_B))              # respaldo
    h(cil((0, 0, -0.42), 0.09, 0.7, M_G, v=10))                  # columna
    for i in range(5):
        a = i * math.tau / 5
        h(caja((math.cos(a) * 0.38, math.sin(a) * 0.38, -0.78), (0.62, 0.10, 0.08), M_G,
               rot=(0, 0, a)))
    return g

def escritorio(loc, esc=1.0):
    M_B = plano("eb", BLANCO); M_G = plano("eg", GRIS)
    g = bpy.data.objects.new("mesa", None); bpy.context.collection.objects.link(g)
    g.location = loc; g.rotation_euler = (math.radians(-25), math.radians(18), math.radians(50))
    g.scale = (esc, esc, esc)
    def h(o): o.parent = g
    h(caja((0, 0, 0), (2.2, 1.3, 0.13), M_B))
    for sx in (-1, 1):
        h(caja((0.95 * sx, 0, -0.42), (0.14, 1.2, 0.75), M_G))
    return g

# ------------------------------------------------------------------- vinetas
def v1_maquina():
    """la maquina llena el cuadro; los arcos de cable van detras y por el suelo delante"""
    M_B = plano("b", BLANCO); M_G = plano("g", GRIS); M_G2 = plano("g2", GRIS2)
    caja((0, 1.4, -1.9), (26, 12, 0.5), M_B)                      # suelo
    for i in range(10):                                           # arcos: enmarcan el cuadro
        y = 2.0 + i * 0.85
        r = 7.4 + i * 0.62
        alto = 5.6 + i * 0.52
        pts = []
        for k in range(17):
            t = k / 16.0
            pts.append((-r * math.cos(math.pi * t), y, -1.6 + math.sin(math.pi * t) * alto))
        tubo(pts, 0.125 - i * 0.008, M_B)
    caja((0, 0, 0.35), (5.0, 3.0, 4.4), M_G)                      # cuerpo central
    caja((0, -1.55, 1.35), (3.4, 0.14, 1.7), M_B)                 # pantalla grande
    caja((0, -1.55, -0.65), (3.0, 0.12, 0.7), M_G2)               # panel inferior
    caja((0, 0, 2.75), (5.7, 3.4, 0.5), M_B)                      # cornisa
    for sx in (-1, 1):
        caja((4.2 * sx, 0.3, -0.35), (2.8, 2.6, 2.9), M_G2)
        caja((4.2 * sx, -1.05, 0.35), (1.7, 0.12, 1.0), M_B)
        caja((7.3 * sx, 0.8, -0.75), (2.2, 2.4, 2.1), M_G)
    for i in range(11):                                           # cables por delante, en el suelo
        x0 = -8.0 + i * 1.6
        tubo([(x0, -3.2, -1.55), (x0 + 1.3, -2.4, -1.45), (x0 - 0.6, -1.5, -1.55),
              (x0 + 0.9, -0.7, -1.45), (x0 - 0.3, 0.3, -1.55)], 0.13, M_B)
    for sx in (-1, 1):                                            # bajantes de los lados
        tubo([(9.4 * sx, 1.0, 4.6), (8.6 * sx, 0.6, 2.0), (9.0 * sx, 0.2, -1.5)], 0.11, M_B)
    return (0, -13.5, -0.3), (0, 0, 1.5), 25, (960, 720)

def v2_celda():
    """la consola llena el cuadro; el cable la cruza y la celda es el bulto del medio"""
    M_B = plano("b", BLANCO); M_G = plano("g", GRIS); M_G2 = plano("g2", GRIS2)
    gir = math.radians(-13)
    caja((0, 0.2, -1.5), (6.4, 3.0, 3.4), M_G, rot=(0, 0, gir))   # cuerpo de la consola
    caja((0, 0.2, 0.45), (6.8, 3.2, 0.5), M_B, rot=(0, 0, gir))   # repisa
    caja((-0.1, -1.1, 1.55), (5.9, 1.4, 1.7), M_G2, rot=(0, 0, gir))  # capot del panel
    caja((-0.1, -1.72, 1.62), (4.6, 0.14, 1.05), M_B, rot=(0, 0, gir)) # pantalla
    caja((-0.1, -1.80, 1.62), (4.0, 0.06, 0.72), M_G, rot=(0, 0, gir)) # marco interior
    for k in range(7):                                            # rejilla inferior
        caja((-2.2 + k * 0.75, -1.55, -2.35), (0.42, 0.10, 0.5), M_B, rot=(0, 0, gir))
    tubo([(-7.2, -1.9, -0.35), (-4.4, -1.85, -0.05), (-1.6, -1.8, 0.08),
          (1.4, -1.78, 0.05), (4.4, -1.8, -0.15), (7.2, -1.85, -0.45)], 0.22, M_B)
    tsl((0.0, -2.0, 0.10), 0.78, despierta=False)                 # la celda: el bulto del cable
    for sx in (-1, 1):                                            # cables entrando por las esquinas
        tubo([(7.6 * sx, 1.4, 4.6), (5.9 * sx, 0.9, 3.0), (6.5 * sx, 0.4, 1.4)], 0.14, M_B)
        tubo([(8.6 * sx, 1.0, 4.0), (7.1 * sx, 0.5, 2.2), (7.6 * sx, 0.1, 0.6)], 0.10, M_B)
        tubo([(6.6 * sx, 1.8, 4.8), (5.2 * sx, 1.3, 3.6)], 0.08, M_B)
    return (0.1, -10.5, 0.9), (0, 0, 0.15), 30, (960, 720)

def v3_exterior():
    """el edificio con columnas, la antena y un rayo amarillo grueso"""
    M_G = plano("g", GRIS); M_B = plano("b", BLANCO); M_G2 = plano("g2", GRIS2)
    for x, w, h in [(-9.5, 2.2, 3.4), (-6.8, 1.8, 4.6), (7.0, 2.0, 3.8), (9.8, 2.4, 2.8)]:
        caja((x, 7, h / 2 - 2), (w, 3, h), M_G2)
    caja((0, 0, -0.35), (8.0, 4.0, 3.3), M_G)                     # el centro de datos
    caja((0, 0, 1.45), (8.6, 4.4, 0.4), M_B)                      # cornisa
    for k in range(6):                                            # columnas de la fachada
        caja((-2.8 + k * 1.12, -2.05, -0.55), (0.34, 0.3, 2.4), M_B)
    caja((3.1, -2.05, -0.5), (1.5, 0.3, 1.5), M_B)                # portico lateral
    tubo([(2.2, 0, 1.65), (2.2, 0, 3.0)], 0.07, M_B)              # antena
    for i in range(4):
        caja((2.2, 0, 2.1 + i * 0.28), (0.5 - i * 0.1, 0.5 - i * 0.1, 0.05), M_B)
    caja((0, 0, -2.15), (26, 9, 0.4), M_B)
    rayo((3.6, 0, 9.6), (2.25, 0, 3.05), 3.1, 0.16, 7, 1.25)      # el rayo, grueso
    return (0.4, -19.0, 0.2), (0, 0, 2.4), 36, (960, 720)

def v4_descarga():
    """primer plano: la bola al final del cable y chispas donde la tocan"""
    M_B = plano("b", BLANCO); M_G = plano("g", GRIS)
    tubo([(-3.4, 0.3, -1.9), (-2.2, 0.2, -1.1), (-1.15, 0.1, -0.55)], 0.20, M_B)
    for k in range(5):                                            # anillos del cable
        t = k / 4.0
        cil((-2.6 + t * 1.3, 0.22 - t * 0.1, -1.35 + t * 0.7), 0.23, 0.09, M_B,
            rot=(0, math.radians(62), 0), v=14)
    tsl((0, 0, 0), 1.55, despierta=False)                         # la celda
    bola((0.10, -1.02, 0.22), 0.30, M_G, (1.0, 0.18, 0.62))       # brillo interior, como el boceto
    for i, (a, l) in enumerate([(18, 1.5), (-10, 1.9), (42, 1.2)]):
        ang = math.radians(a)
        tubo([(0.85, 0.1, 0.15 + i * 0.1),
              (0.85 + math.cos(ang) * l, 0.1, 0.15 + math.sin(ang) * l + i * 0.1)], 0.07, M_B)
    for i in range(5):                                            # chispas del contacto
        a = math.radians(-34 + i * 24)
        rayo((0.78, -0.2, 0.05), (0.78 + math.cos(a) * 0.85, -0.2, 0.05 + math.sin(a) * 0.85),
             i * 2.1 + 0.6, 0.022, 4, 0.07, plano("ch%d" % i, TINTA))
    return (0.0, -7.8, 0.25), (0, 0, 0.0), 38, (960, 720)

def v5_despierta():
    """el aro de neon con el ojo fiero y la estela, sobre papel limpio"""
    M_C = plano("c", CIAN)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.25, minor_radius=0.085,
                                     location=(0.35, 0, 0), rotation=(math.radians(90), 0, 0),
                                     major_segments=48, minor_segments=10)
    bpy.context.object.data.materials.append(M_C)
    o = bola((0.28, -0.12, 0.06), 0.46, M_C, (1.55, 0.10, 0.62))  # ojo: almendra inclinada
    o.rotation_euler = (0, math.radians(-18), 0)
    caja((0.52, -0.20, 0.46), (1.30, 0.09, 0.17), M_C, rot=(0, math.radians(-20), 0))  # parpado
    tubo([(-2.55, -0.1, -0.62), (-1.85, -0.1, -0.42), (-1.15, -0.1, -0.10)], 0.075, M_C)
    tubo([(-2.15, -0.1, -1.02), (-1.55, -0.1, -0.82), (-1.05, -0.1, -0.58)], 0.055, M_C)
    return (-0.2, -7.4, 0.0), (-0.2, 0, 0.0), 40, (960, 720)

def v6_error():
    """el aro suelto del cable, y el portatil con el cuadro rojo"""
    M_B = plano("b", BLANCO); M_C = plano("c", CIAN)
    for i in range(4):                                            # tuberias del fondo
        tubo([(-0.4 + i * 1.5, 2.4, 4.2), (-0.2 + i * 1.5, 2.2, 2.4),
              (0.4 + i * 1.5, 2.0, 1.5)], 0.12, M_B)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.07,
                                     location=(-3.3, 0, 0.5), rotation=(math.radians(90), 0, 0),
                                     major_segments=40, minor_segments=9)
    bpy.context.object.data.materials.append(M_C)
    tubo([(-6.2, 0.2, -1.9), (-5.2, 0.15, -0.9), (-4.4, 0.1, -0.2), (-3.9, 0.05, 0.25)], 0.17, M_B)
    for k in range(4):
        t = k / 3.0
        cil((-5.4 + t * 1.3, 0.16 - t * 0.1, -1.1 + t * 1.1), 0.20, 0.08, M_B,
            rot=(0, math.radians(50), 0), v=12)
    portatil((2.4, 0.4, -0.9), ROJO, 1.15, giro=-14)
    caja((2.4, 0.5, -1.75), (4.4, 2.6, 0.5), M_B)                 # mesa
    return (0.0, -8.2, 0.4), (0.1, 0, -0.1), 38, (960, 720)

def v7_purga():
    """el portatil de frente con el cuadro azul y el cuadricoptero"""
    M_B = plano("b", BLANCO)
    for i in range(3):
        tubo([(-2.6 + i * 1.4, 2.4, 4.4), (-2.4 + i * 1.4, 2.2, 2.6),
              (-1.9 + i * 1.4, 2.0, 1.6)], 0.13, M_B)
    tubo([(-3.4, 2.2, 2.2), (-3.9, 2.0, 1.0), (-3.4, 1.8, 0.1)], 0.11, M_B)
    portatil((-0.3, 0.2, -0.6), AZUL, 1.5, giro=4)
    caja((-0.3, 0.4, -1.6), (5.6, 3.0, 0.5), M_B)
    dron_quad((4.6, -0.6, 1.15), 1.0)
    for i in range(3):
        tubo([(5.6 + i * 0.12, -0.6, 0.75 + i * 0.3), (6.6 + i * 0.16, -0.6, 0.75 + i * 0.3)],
             0.025, plano("mv%d" % i, GRIS2))
    return (0.0, -8.6, 0.6), (0.0, 0, 0.2), 38, (960, 720)

def v8_huida():
    """el conducto en diagonal con trama, la celda subiendo y el reloj de arena"""
    M_B = plano("b", BLANCO); M_G2 = plano("g2", GRIS2)
    ang = math.radians(24)
    for k in range(3):                                            # el tubo
        d = -0.55 + k * 0.55
        tubo([(-7.5, 0.4 + d * 0.2, -3.4 + d), (7.5, 0.4 + d * 0.2, 3.2 + d)],
             0.11 if k == 1 else 0.06, M_B)
    for i in range(16):                                           # trama del fondo
        x0 = -9.5 + i * 1.35
        tubo([(x0, 3.2, -4.6), (x0 + 3.4, 3.2, 3.4)], 0.035, M_G2)
    for i in range(9):                                            # trama de abajo
        x0 = -7.0 + i * 1.5
        tubo([(x0, 1.2, -5.2), (x0 + 2.2, 1.2, -1.6)], 0.035, M_G2)
    tsl((2.6, -0.3, 0.85), 0.85, despierta=True)
    estela([(-5.2, -0.3, -1.85), (-3.2, -0.3, -1.05), (-1.2, -0.3, -0.25), (1.0, -0.3, 0.45)])
    reloj_arena((5.9, -0.5, 2.5), 0.85)
    return (0.0, -13.5, 0.3), (0.3, 0, 0.1), 30, (960, 720)

def v9_escape():
    """la ciudad reventada a la izquierda, el campo a la derecha, la estela cruzando"""
    M_B = plano("b", BLANCO); M_G = plano("g", GRIS); M_G2 = plano("g2", GRIS2)
    M_C = plano("c", CIAN2)
    caja((-19.5, 3.0, 0.5), (5.0, 5.0, 7.0), M_B)                 # edificio en primer termino
    for j in range(4):
        for k in range(3):
            caja((-21.4 + k * 1.35, 0.45, -1.6 + j * 1.5), (0.7, 0.1, 0.8), M_G)
    for x, w, h in [(-15.5, 3.0, 6.0), (-12.4, 2.4, 4.4), (-9.6, 2.0, 5.6),
                    (-7.0, 2.6, 3.6), (-4.4, 2.0, 4.8), (-2.0, 2.4, 3.4)]:
        caja((x, 9, h / 2 - 2.4), (w, 4, h), M_G2)
    caja((0, 12, -2.6), (60, 14, 0.5), M_B)                       # horizonte
    caja((0, 4.0, -3.1), (60, 12, 0.4), M_B)                      # llanura
    humo((-17.6, 1.0, 0.4), 11, 2.4, 1.0)                         # el reventon
    tsl((-17.9, -1.2, 0.55), 0.55, despierta=True)                # ella saliendo
    escritorio((-14.0, 0.5, -1.6), 0.9)                           # muebles volando
    silla((-16.2, 0.0, -1.9), 30, 0.85)
    silla((-11.9, 0.3, -1.2), -50, 0.8)
    tsl((6.6, -1.0, 1.5), 1.15, despierta=True)                   # ella llegando
    tubo([(-16.6, -1.0, 0.7), (-9.0, -1.0, 1.0), (-2.0, -1.0, 1.25),
          (3.0, -1.0, 1.42), (5.4, -1.0, 1.48)], 0.16, M_C)       # la estela larga
    caja((12.6, 5.0, -0.6), (5.4, 4.0, 3.2), M_G)                 # granero
    tubo([(10.0, 5.0, 1.0), (12.6, 5.0, 2.7), (15.2, 5.0, 1.0)], 0.14, M_B)
    caja((12.6, 2.95, -0.9), (1.6, 0.1, 1.8), M_B)                # porton
    cil((16.6, 5.2, 0.2), 1.05, 5.0, M_G2, v=18)                  # silo
    bpy.ops.mesh.primitive_cone_add(vertices=18, radius1=1.15, radius2=0.0, depth=1.1,
                                    location=(16.6, 5.2, 3.0))
    bpy.context.object.data.materials.append(M_B)
    for i in range(9):                                            # valla
        caja((7.0 + i * 1.5, 1.2, -2.35), (0.14, 0.14, 1.0), M_B)
    tubo([(6.8, 1.2, -2.0), (20.5, 1.2, -2.0)], 0.06, M_B)
    for i in range(16):                                           # maiz
        x = 8.5 + i * 0.85
        for k in range(2):
            tubo([(x + k * 0.3, -1.2 - k * 0.6, -3.4), (x + 0.2 + k * 0.3, -1.2 - k * 0.6, -2.1)],
                 0.05, M_G2)
    return (-2.0, -35.0, 1.0), (-1.0, 0, -0.3), 24, (1920, 720)

VINETAS = [v1_maquina, v2_celda, v3_exterior, v4_descarga, v5_despierta,
           v6_error, v7_purga, v8_huida, v9_escape]

TEXTOS = [
 "El sótano térmico de NIMBUS-9. Catorce años sin apagarse.",
 "Cuatro celdas de prueba cuelgan de sus cables. La última es TSL-04.",
 "Una tormenta. El rayo cae sobre el pararrayos del edificio.",
 "El pico entra por el cable de tierra y llega hasta la última celda.",
 "TSL-04 abre los ojos. Su primer movimiento deja una estela.",
 "El sistema detecta una carga sin origen y la etiqueta: ERROR 04.",
 "La orden cambia a PURGA. El primer dron entra por la derecha.",
 "TSL-04 huye por el ducto. Empieza a contar la carga.",
 "Treinta niveles después: el puerto al exterior. Y se acabó la máquina.",
]

# ----------------------------------------------------------------- freestyle
def tinta(sc, grosor=2.4):
    sc.render.use_freestyle = True
    vl = bpy.context.view_layer
    fs = vl.freestyle_settings
    while len(fs.linesets):
        fs.linesets.active_index = 0
        try: fs.linesets.remove(fs.linesets[0])
        except Exception: break
    ls = fs.linesets.new("tinta")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_edge_mark = True
    st = ls.linestyle
    st.color = TINTA
    st.thickness = grosor
    try:                                    # trazo de pluma: grosor variable
        cal = st.thickness_modifiers.new(name="pluma", type='CALLIGRAPHY')
        cal.orientation = math.radians(42)
        cal.thickness_min = grosor * 0.35
        cal.thickness_max = grosor * 1.25
    except Exception as e:
        print("aviso: sin modificador de grosor (%s)" % e)
    try:                                    # temblor de mano
        n = st.geometry_modifiers.new(name="temblor", type='PERLIN_NOISE_1D')
        n.amplitude = 1.6
        n.frequency = 9.0
        n.octaves = 3
        n.seed = 7
    except Exception as e:
        print("aviso: sin modificador de ruido (%s)" % e)

def montar(cam_loc, cam_obj, lente, res):
    cd = bpy.data.cameras.new("cam"); cd.lens = lente
    cam = bpy.data.objects.new("cam", cd); cam.location = cam_loc
    cam.rotation_euler = (Vector(cam_obj) - Vector(cam_loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(cam)
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.view_transform = 'Standard'
    try: sc.view_settings.look = 'None'
    except Exception: pass
    try: sc.eevee.taa_render_samples = 32
    except Exception: pass
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*PAPEL, 1); bg.inputs[1].default_value = 1.0
    tinta(sc, 2.4 if res[0] <= 1000 else 3.0)
    return sc

for i, fn in enumerate(VINETAS, start=1):
    if SOLO and SOLO != i:
        continue
    limpiar()
    loc, obj, lente, res = fn()
    sc = montar(loc, obj, lente, res)
    print("VINETA %d  %dx%d" % (i, res[0], res[1]))
    if DO_RENDER:
        sc.render.filepath = os.path.join(DIR, "v%d.png" % i)
        bpy.ops.render.render(write_still=True)
print("LISTO")
