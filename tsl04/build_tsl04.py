# -*- coding: utf-8 -*-
"""
TSL-04 - Generador de personaje y animaciones para PULSO
Blender 5.x  |  uso:
    blender -b --factory-startup --python build_tsl04.py -- --render
    blender -b --factory-startup --python build_tsl04.py -- --render --color ambar
    blender -b --factory-startup --python build_tsl04.py -- --render --solo correr
"""
import bpy, math, os, sys
from mathutils import Vector

# ----------------------------------------------------------------- parametros
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
RETRATO   = "--retrato" in ARGS
# `--glb` saca el modelo a arte/tsl04/tsl04.glb para el menu principal, que
# ensena a TSL-04 en 3D vivo. Tiene que salir de AQUI y no reconstruirse con
# primitivas en Godot: una copia a mano se separa del personaje de los sprites
# en cuanto se toque cualquier proporcion de este archivo.
GLB       = "--glb" in ARGS
VARIANTE = ARGS[ARGS.index("--color") + 1] if "--color" in ARGS else "cian"
# `--solo <animacion>` renderiza una sola y reaprovecha los cuadros ya escritos
# de las demas para montar las hojas. Doce animaciones son ~100 cuadros a 10 s
# cada uno, o sea un cuarto de hora sin poder ver nada; y cualquier ajuste de
# luz hay que juzgarlo mirando, no esperando.
SOLO = ARGS[ARGS.index("--solo") + 1] if "--solo" in ARGS else ""
OUT = os.path.dirname(os.path.abspath(__file__))

PALETAS = {
    #            cuerpo             emision          borde            rubor
    "cian":  {"cuerpo": (0.13, 0.72, 1.00), "emis": (0.21, 0.88, 1.00), "borde": (0.55, 0.98, 1.00), "rubor": (1.00, 0.42, 0.45)},
    "ambar": {"cuerpo": (1.00, 0.66, 0.16), "emis": (1.00, 0.78, 0.28), "borde": (1.00, 0.92, 0.55), "rubor": (1.00, 0.36, 0.30)},
    "violeta": {"cuerpo": (0.62, 0.40, 1.00), "emis": (0.72, 0.54, 1.00), "borde": (0.88, 0.78, 1.00), "rubor": (1.00, 0.38, 0.62)},
    # la plata no puede ser blanca: por encima de 1.0 la emision se recorta y se
    # pierde el tono, y seria un cuerpo sin color. Un gris frio, claro pero no blanco.
    "plata": {"cuerpo": (0.70, 0.78, 0.86), "emis": (0.80, 0.88, 0.95), "borde": (0.96, 0.98, 1.00), "rubor": (1.00, 0.50, 0.44)},
}
P = PALETAS[VARIANTE]

RES = 288         # px por cuadro. El cuerpo ocupa RES/3, o sea 96 px de personaje
SS = 2            # supermuestreo
COLS = 6          # cuadros por fila: en una sola fila la hoja pasaria de 2048 px
ORTHO = 3.0       # 1 unidad Blender = 32 px  -> cuerpo de 32 px en cuadro de 96

# nombre, cuadros, fps, bucle
ANIMS = [
    ("reposo",      12, 10, True),
    ("correr",      12, 16, True),
    ("giro",         4, 20, False),
    ("salto",        6, 14, False),
    ("caida",        4, 12, True),
    ("aterrizaje",   3, 18, False),
    ("impulso",      5, 20, False),
    ("adherencia",   6, 10, True),
    ("muerte",       6, 14, False),
    ("aparicion",    5, 20, False),
    ("carga_baja",   6,  8, True),
    ("victoria",     8, 12, False),
]

# ------------------------------------------------------------------ utilidades
def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights, bpy.data.cameras):
        for b in list(c):
            c.remove(b)

def mat(nombre, base, emis=(0,0,0), fuerza=0.0, rug=0.35, alpha=1.0, mezcla=False):
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (*base, 1.0)
    n.inputs["Roughness"].default_value = rug
    n.inputs["Emission Color"].default_value = (*emis, 1.0)
    n.inputs["Emission Strength"].default_value = fuerza
    n.inputs["Alpha"].default_value = alpha
    if mezcla:
        try: m.surface_render_method = 'BLENDED'
        except Exception:
            try: m.blend_method = 'BLEND'
            except Exception: pass
    return m

def esfera(nombre, radio, loc, escala=(1,1,1), material=None, segs=32, anillos=16, suave=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=anillos, radius=radio, location=loc)
    o = bpy.context.object
    o.name = nombre
    o.scale = escala
    if suave: bpy.ops.object.shade_smooth()
    if material: o.data.materials.append(material)
    return o

def cubo(nombre, escala, loc, rot=(0,0,0), material=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object; o.name = nombre; o.scale = escala
    if material: o.data.materials.append(material)
    return o

def empty(nombre, loc=(0,0,0)):
    o = bpy.data.objects.new(nombre, None)
    o.empty_display_size = 0.25
    o.location = loc
    bpy.context.collection.objects.link(o)
    return o

def emparentar(hijo, padre):
    """el hijo ya esta colocado en coordenadas de mundo: se cancela el padre"""
    hijo.parent = padre
    hijo.matrix_parent_inverse = padre.matrix_world.inverted()

def emparentar_local(hijo, padre):
    """el hijo esta colocado en coordenadas LOCALES del padre: no se cancela nada"""
    hijo.parent = padre

def sobre_esfera(x, z, R=0.5, fuera=0.0):
    """devuelve la Y sobre la superficie frontal de la esfera de radio R"""
    d = max(R*R - x*x - z*z, 0.0)
    return -(math.sqrt(d) + fuera)

# ------------------------------------------------------------------ materiales
limpiar()
# Emision 0.07 y no 0.32. La emision se suma IGUAL en todos los pixeles sin
# mirar la normal, asi que resta contraste directamente: 0.32 lineal en el canal
# azul son 153 niveles sRGB de color completamente plano pintados encima del
# degradado. Medido aislando la variable, bajarla sube el rango util de la
# corona de 4 a 17 niveles. No se quita del todo porque TSL-04 es una IA dentro
# de una computadora y el brillo propio es parte del personaje.
M_CUERPO = mat("tsl_cuerpo", P["cuerpo"], P["emis"], 0.07, 0.26)
M_OJO    = mat("tsl_ojo",    (0.96, 0.99, 1.00), (0.6, 0.9, 1.0), 0.25, 0.12)
M_IRIS   = mat("tsl_iris",   (0.02, 0.09, 0.12), (0.0, 0.05, 0.08), 0.15, 0.08)
M_BRILLO = mat("tsl_brillo", (1, 1, 1), (1, 1, 1), 3.0, 0.05)
M_RUBOR  = mat("tsl_rubor",  P["rubor"], P["rubor"], 0.8, 0.6, alpha=0.55, mezcla=True)
M_BOCA   = mat("tsl_boca",   (0.02, 0.08, 0.11), (0, 0, 0), 0.0, 0.3)
M_CHISPA = mat("tsl_chispa", P["emis"], P["emis"], 1.15, 0.1)

# ---------------------------------------------------------------------- modelo
RAIZ = empty("TSL04")
CTRL = empty("ctrl_cuerpo")          # aplasta y estira
emparentar(CTRL, RAIZ)
CARA = empty("ctrl_cara")            # desplaza la mirada
emparentar(CARA, CTRL)

cuerpo = esfera("cuerpo", 0.5, (0, 0, 0), material=M_CUERPO, segs=48, anillos=24)
bpy.ops.object.modifier_add(type='SUBSURF'); cuerpo.modifiers[-1].levels = 1; cuerpo.modifiers[-1].render_levels = 2
emparentar(cuerpo, CTRL)

OJOS = []
for lado, sx in (("L", -1), ("R", 1)):
    ex, ez = 0.185 * sx, 0.035
    ey = sobre_esfera(ex, ez, fuera=-0.055)
    g = empty("ojo_%s" % lado, (ex, ey, ez)); emparentar(g, CARA)
    e = esfera("esclera_%s" % lado, 0.185, (0, 0, 0), (1.0, 0.52, 1.16), M_OJO, 28, 14); emparentar_local(e, g)
    i = esfera("iris_%s" % lado, 0.132, (0, -0.075, -0.012), (1.0, 0.45, 1.10), M_IRIS, 24, 12); emparentar_local(i, g)
    b1 = esfera("brillo1_%s" % lado, 0.058, (-0.055 * sx, -0.150, 0.062), (1, 0.55, 1), M_BRILLO, 16, 8); emparentar_local(b1, g)
    b2 = esfera("brillo2_%s" % lado, 0.030, (0.062 * sx, -0.148, -0.058), (1, 0.55, 1), M_BRILLO, 14, 7); emparentar_local(b2, g)
    OJOS.append(g)

for lado, sx in (("L", -1), ("R", 1)):
    rx, rz = 0.315 * sx, -0.105
    ry = sobre_esfera(rx, rz, fuera=-0.015)
    r = esfera("rubor_%s" % lado, 0.105, (rx, ry, rz), (1.25, 0.30, 0.70), M_RUBOR, 20, 10)
    emparentar(r, CARA)

# boca: arco de curva sobre la superficie
cu = bpy.data.curves.new("boca_curva", 'CURVE'); cu.dimensions = '3D'
cu.bevel_depth = 0.016; cu.resolution_u = 6; cu.bevel_resolution = 3
sp = cu.splines.new('POLY'); N = 11; sp.points.add(N - 1)
for i in range(N):
    t = i / (N - 1)
    x = -0.105 + 0.210 * t
    z = -0.150 - 0.045 * math.sin(math.pi * t)
    sp.points[i].co = (x, sobre_esfera(x, z, fuera=-0.005), z, 1.0)
boca = bpy.data.objects.new("boca", cu); boca.data.materials.append(M_BOCA)
bpy.context.collection.objects.link(boca); emparentar(boca, CARA)

# ojos en X (solo para la muerte)
EQUIS = []
for lado, sx in (("L", -1), ("R", 1)):
    ex, ez = 0.185 * sx, 0.035
    ey = sobre_esfera(ex, ez, fuera=0.10)
    g = empty("equis_%s" % lado, (ex, ey, ez)); emparentar(g, CARA)
    for ang in (math.radians(45), math.radians(-45)):
        c = cubo("equis_%s_%d" % (lado, int(math.degrees(ang))), (0.30, 0.05, 0.055), (0, 0, 0), (0, ang, 0), M_BOCA)
        emparentar_local(c, g)
        EQUIS.append(c)

# chispas de la muerte
CHISPAS = []
NCH = 11
for i in range(NCH):
    # angulo con desvio y largo desigual: un estallido no es un anillo regular
    a = 2 * math.pi * i / NCH + (0.34 if i % 2 else -0.19) * (2 * math.pi / NCH)
    largo = (0.62, 1.35, 0.88, 1.10, 0.74, 1.28, 0.95, 0.68, 1.18, 0.82, 1.05)[i]
    bx, bt = 0.20 * largo, 0.075          # tira fina y alargada, legible a 96 px
    c = cubo("chispa_%02d" % i, (bx, bt, bt), (0, 0, 0), (0, 0, 0), M_CHISPA)
    c["ang"] = a; c["largo"] = largo; c["bx"] = bx; c["bt"] = bt
    emparentar_local(c, CTRL); CHISPAS.append(c)

OCULTOS = EQUIS + CHISPAS

PIEZAS = [o for o in bpy.data.objects
          if o.type in ('MESH', 'CURVE') and o not in CHISPAS and not o.name.startswith("equis_")]

# --------------------------------------------------------------- luces/camara
def luz(nombre, tipo, loc, energia, color, tam=2.0):
    d = bpy.data.lights.new(nombre, tipo)
    d.energy = energia; d.color = color
    if tipo == 'AREA': d.size = tam
    o = bpy.data.objects.new(nombre, d); o.location = loc
    o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(o)
    return o

# El personaje no se veia plano por la curva de tono sino por EXPOSICION. Con
# las luces de antes el canal azul estaba clavado en 255 en el 56% del cuerpo y
# el verde en el 51%: en mas de la mitad del personaje solo quedaba vivo el
# rojo, que en la paleta cian vale 0.13 de 1.00, asi que toda la forma se
# contaba con un tercio de la informacion. Tres correcciones:
#
# LA CLAVE, DE FRONTAL A LATERAL. Estaba casi delante (Y=-2.8, y la camara esta
# en Y=-5.6): luz frontal aplana por definicion, porque el terminador queda
# detras de la silueta y no llega a cruzar la cara visible. Al llevarla al lado
# el terminador cruza el cuerpo y aparece el degradado. Medido: la meseta lisa
# mas ancha cae de 48 px a 21 px y los niveles distintos suben de 109 a 137.
#
# LOS BORDES, QUE ERAN EL CULPABLE PRINCIPAL. Sumaban 820 W contra una clave de
# 340: el borde era 2,4 veces la clave, que es justo al reves de como funciona.
# El borde describe la SILUETA, que ya se lee sola contra el fondo oscuro; la
# clave describe la FORMA, que es lo que faltaba. Solo el borde ya pasaba de 1.0
# antes de sumar nada mas. Bajarlo de 560 a 120 sube el rango de la corona de 4
# a 34 niveles.
#
# EL RELLENO, PARA SOSTENER LA SOMBRA. Al bajar la clave y quitar la emision el
# lado oscuro se hundia: los pixeles por debajo de 90 pasaban del 10,5% al
# 19,8%. A 34 W el relleno era testimonial, un 10% de la clave.
luz("clave",  'AREA', (-3.9, -0.9,  2.6), 190, (1.00, 0.97, 0.92), 1.2)
luz("relleno",'AREA', ( 2.8, -2.2, -1.1),  90, (0.62, 0.82, 1.00), 3.0)
luz("borde",  'AREA', ( 1.5,  2.6,  1.9), 120, P["borde"], 0.8)
luz("borde2", 'AREA', (-1.4,  2.4, -1.2),  75, P["emis"],  1.2)

# camara EN PERSPECTIVA y en tres cuartos: es lo que hace que el sprite lea como 3D
AZIMUT = math.radians(-20.0)    # giro lateral
ELEV   = math.radians(9.0)     # ligera picada
DIST   = 6.0
cam_d = bpy.data.cameras.new("camara")
cam_d.type = 'PERSP'
cam_d.sensor_width = 36.0
cam_d.lens = 36.0 * DIST / ORTHO      # encuadra igual que la ortografica anterior
cam = bpy.data.objects.new("camara", cam_d)
cam.location = (DIST * math.sin(AZIMUT) * math.cos(ELEV),
                -DIST * math.cos(AZIMUT) * math.cos(ELEV),
                DIST * math.sin(ELEV))
cam.rotation_euler = (Vector((0, 0, 0)) - Vector(cam.location)).to_track_quat('-Z', 'Y').to_euler()
bpy.context.collection.objects.link(cam)

sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = RES * SS
sc.render.resolution_y = RES * SS
sc.render.resolution_percentage = 100
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.render.fps = 24
try: sc.eevee.taa_render_samples = 64
except Exception: pass
# Sin tonemapping, y es una decision ACTIVA, no un olvido. Se probaron AgX,
# Filmic y Khronos PBR Neutral renderizando de verdad, y con las luces ya
# corregidas los tres salen peor que 'Standard': AgX deja la saturacion en 0.200
# frente a 0.526 (el cian se vuelve gris lechoso), Filmic levanta los negros de
# 35 a 51 y sobre el fondo del juego eso deja un halo gris alrededor del alfa, y
# Khronos desvia 20,3 niveles de media incluso con todo por debajo de 1.0, donde
# no hay nada que comprimir. Un tonemapper quita el recorte pero NO devuelve el
# volumen: solo cambia un corte duro por un hombro blando en el mismo sitio
sc.view_settings.view_transform = 'Standard'
try: sc.view_settings.look = 'None'
except Exception: pass
# Con el ambiente a 0.0 no habia nada que rellenara el lado opuesto a las luces:
# el terminador era un corte y la sombra se hundia a negro sin informacion. El
# azul esta elegido para ser del mismo tono que el FONDO del juego
# (0.031, 0.055, 0.086) pero mas claro, porque la luz de entorno cuenta que el
# personaje esta DENTRO de la computadora. Y 0.55 es el techo util, medido:
# a 1.0 el recorte vuelve a subir del 6,7% al 11,5% y a 1.6 al 22,8%.
world = bpy.data.worlds.new("mundo"); sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.16, 0.24, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55

# ----------------------------------------------------------------- animacion
# Ritmo por cuadro. El patron que funciona en animacion de accion es
# arranque lento, accion rapida, asentamiento lento: los cuadros de
# preparacion se sostienen, el del golpe es el mas corto, y la recuperacion
# se relaja. En Godot cada cuadro lleva su propia duracion.
RITMO = {
    "aterrizaje": [0.55, 1.15, 1.30],
    "salto":      [0.55, 0.60, 1.05, 1.20, 1.30, 1.30],
    "impulso":    [0.65, 0.50, 0.60, 1.25, 2.00],
    "giro":       [0.60, 0.55, 1.05, 1.80],
    "muerte":     [0.45, 0.55, 0.95, 1.25, 1.40, 1.40],
    "victoria":   [1.25, 0.65, 0.65, 0.95, 1.05, 1.15, 1.15, 1.15],
    "aparicion":  [1.40, 0.70, 0.60, 1.10, 1.20],
}

def ritmo(nombre, n):
    """Se normaliza para que la animacion dure EXACTAMENTE lo mismo que con
    cuadros iguales. Si no, cambiaria el tiempo que el juego tiene bloqueado
    al jugador esperando el animation_finished."""
    d = RITMO.get(nombre)
    if not d or len(d) != n:
        return [1.0] * n
    k = n / float(sum(d))
    return [v * k for v in d]

def volumen(sz, ancho=1.0):
    """Aplastado y estirado CON VOLUMEN CONSTANTE. Si algo se achata a sz en
    vertical tiene que ensancharse 1/raiz(sz) en las dos horizontales, o el
    personaje gana y pierde masa al moverse. `ancho` reparte ese
    ensanchamiento entre X e Y sin romper la cuenta: (k*a)*(k/a)*sz = 1."""
    k = 1.0 / math.sqrt(sz)
    return (k * ancho, k / ancho, sz)

def cara_en(f, *claves):
    """Arrastre y continuacion: la cabeza va por detras del cuerpo cuando
    este acelera y se pasa de largo cuando frena. Cada clave es
    (cuadro, adelanto, altura). Sin esto la cara va clavada y no pesa."""
    for df, x, z in claves:
        kf(CARA, f + df, loc=(x, -abs(x) * 0.25, z))

def kf(o, f, loc=None, rot=None, scl=None):
    if loc is not None: o.location = loc; o.keyframe_insert('location', frame=f)
    if rot is not None: o.rotation_euler = [math.radians(a) for a in rot]; o.keyframe_insert('rotation_euler', frame=f)
    if scl is not None: o.scale = scl; o.keyframe_insert('scale', frame=f)

def ver(o, f, visible):
    o.hide_render = not visible; o.hide_viewport = not visible
    o.keyframe_insert('hide_render', frame=f); o.keyframe_insert('hide_viewport', frame=f)

def emision(f, fuerza, tinte=1.0):
    n = M_CUERPO.node_tree.nodes["Principled BSDF"]
    n.inputs["Emission Strength"].default_value = fuerza
    n.inputs["Emission Strength"].keyframe_insert('default_value', frame=f)
    c = P["cuerpo"]
    n.inputs["Base Color"].default_value = (c[0]*tinte, c[1]*tinte, c[2]*tinte, 1.0)
    n.inputs["Base Color"].keyframe_insert('default_value', frame=f)

def reposo_base(f, cuerpo_visible=True):
    kf(RAIZ, f, loc=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1))
    kf(CTRL, f, loc=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1))
    kf(CARA, f, loc=(0, 0, 0))
    for g in OJOS: kf(g, f, scl=(1, 1, 1))
    for o in PIEZAS: ver(o, f, cuerpo_visible)
    for o in EQUIS + CHISPAS: ver(o, f, False)
    for c in CHISPAS: kf(c, f, loc=(0, 0, 0), scl=(1, 1, 1))
    emision(f, 0.07)

def chispas_en(f, radio, escala, visible=True):
    for c in CHISPAS:
        a, L = c["ang"], c["largo"]
        r = radio * (0.55 + 0.72 * L)      # cada chispa vuela a su propia distancia
        bx, bt = c["bx"], c["bt"]
        ver(c, f, visible)
        kf(c, f, loc=(math.cos(a) * r, 0, math.sin(a) * r),
           rot=(0, -math.degrees(a), 0), scl=(bx * escala, bt * escala, bt * escala))

# ---- construccion de cada animacion sobre una linea de tiempo unica
RANGOS = {}
cursor = 1
for nombre, n, fps, bucle in ANIMS:
    RANGOS[nombre] = (cursor, cursor + n - 1)
    cursor += n + 3          # 3 cuadros de separacion para que no se contaminen

def R(nombre): return RANGOS[nombre][0]

# reposo: respiracion + parpadeo
f = R("reposo"); reposo_base(f)
kf(CTRL, f + 0,  scl=volumen(1.000), loc=(0, 0, 0.00))
kf(CTRL, f + 6,  scl=volumen(1.035), loc=(0, 0, 0.02))
kf(CTRL, f + 11, scl=volumen(1.000), loc=(0, 0, 0.00))
cara_en(f, (0, 0, 0.0), (7, 0, 0.012), (11, 0, 0.0))   # la cabeza sube un cuadro tarde
for g in OJOS:
    kf(g, f + 7, scl=(1, 1, 1)); kf(g, f + 8, scl=(1, 1, 0.10)); kf(g, f + 9, scl=(1, 1, 1))

# correr: inclinacion, estirado horizontal y dos rebotes
f = R("correr"); reposo_base(f)
for i, (sz, dz) in enumerate([(0.90, 0.00), (1.04, 0.07), (0.90, 0.00),
                              (1.04, 0.07), (0.90, 0.00), (1.04, 0.07)]):
    kf(CTRL, f + i * 2, rot=(0, -13, 0), scl=volumen(sz, 1.04), loc=(0, 0, dz))
kf(CTRL, f + 11, rot=(0, -13, 0), scl=volumen(0.90, 1.04), loc=(0, 0, 0))
# la cabeza rebota un cuadro por detras del cuerpo: eso es el arrastre
cara_en(f, (0, 0.030, 0.000), (3, 0.030, 0.020), (5, 0.030, 0.000),
           (7, 0.030, 0.020), (9, 0.030, 0.000), (11, 0.030, 0.014))

# giro: pivota de mirar a la izquierda a mirar a la derecha (espejado sirve al reves)
f = R("giro"); reposo_base(f)
for i, (rz, sz) in enumerate([(-50, 0.94), (-22, 1.10), (12, 0.96), (0, 1.00)]):
    kf(RAIZ, f + i, rot=(0, 0, rz))
    kf(CTRL, f + i, scl=volumen(sz, 0.98))
# la cara se queda atras al girar y se pasa de largo antes de centrarse
cara_en(f, (0, -0.030, 0), (1, -0.018, 0), (2, 0.026, 0), (3, 0, 0))

# salto: 2 cuadros de anticipacion y estirado
f = R("salto"); reposo_base(f)
for i, (sz, dz) in enumerate([(1.00, 0.00), (0.80, -0.06), (1.30, 0.12),
                              (1.24, 0.24), (1.12, 0.32), (1.06, 0.36)]):
    kf(CTRL, f + i, scl=volumen(sz), loc=(0, 0, dz))
# el cuerpo sale disparado y la cabeza tarda dos cuadros en seguirle
cara_en(f, (0, 0, 0.000), (1, 0, -0.030), (2, 0, -0.038),
           (3, 0, -0.012), (4, 0, 0.018), (5, 0, 0.000))
for g in OJOS:
    kf(g, f + 1, scl=(1, 1, 1)); kf(g, f + 2, scl=(1.14, 1, 1.14))

# caida
f = R("caida"); reposo_base(f)
for i, sz in enumerate([1.18, 1.23, 1.18, 1.23]):
    kf(CTRL, f + i, scl=volumen(sz), loc=(0, 0, 0.10))
for g in OJOS: kf(g, f, scl=(1.12, 1, 1.12))

# aterrizaje: aplastamiento y rebote
f = R("aterrizaje"); reposo_base(f)
for i, (sz, dz) in enumerate([(0.68, -0.15), (1.12, 0.03), (1.00, 0.00)]):
    kf(CTRL, f + i, scl=volumen(sz), loc=(0, 0, dz))
# al golpear el suelo la cabeza sigue bajando un cuadro mas y luego rebota
cara_en(f, (0, 0, -0.045), (1, 0, 0.026), (2, 0, 0.000))

# impulso: estirado horizontal fuerte
f = R("impulso"); reposo_base(f)
for i, (sz, ancho, ry) in enumerate([(0.94, 1.06, -10), (0.78, 1.30, -22),
                                     (0.80, 1.28, -20), (0.94, 1.09, -12),
                                     (1.00, 1.00, 0)]):
    kf(CTRL, f + i, scl=volumen(sz, ancho), rot=(0, ry, 0))
for g in OJOS:
    kf(g, f + 1, scl=(1, 1, 0.72)); kf(g, f + 4, scl=(1, 1, 1))
# inercia pura: al acelerar la cabeza se queda ATRAS, y al frenar se va
# hacia delante. Antes iba hacia delante desde el primer cuadro, al reves.
cara_en(f, (0, 0.000, 0), (1, -0.045, 0), (2, -0.020, 0),
           (3, 0.050, 0), (4, 0.000, 0))

# adherencia: pegado a una pared a su derecha, resbalando hacia abajo
f = R("adherencia"); reposo_base(f)
kf(CARA, f, loc=(0.055, -0.010, -0.030))          # mira hacia la pared y algo abajo
for g in OJOS: kf(g, f, scl=(1.0, 1.0, 0.86))     # ojos algo entrecerrados por el esfuerzo
for i, (sx, sz, dz, rz) in enumerate([
        (0.80, 1.16,  0.030, -6.0),
        (0.78, 1.19,  0.000, -6.5),
        (0.81, 1.14, -0.028, -5.5),
        (0.79, 1.17, -0.056, -6.5),
        (0.82, 1.13, -0.030, -5.0),
        (0.80, 1.16,  0.030, -6.0)]):
    # aplastado contra la pared (X) y estirado por la gravedad (Z)
    kf(CTRL, f + i, scl=(sx, 0.96, sz), loc=(0.115, 0, dz), rot=(0, 0, rz))
# chispas de roce: suben por el borde de contacto mientras el cuerpo baja
for i in range(6):
    for j, c in enumerate(CHISPAS[:3]):
        t = ((i + j * 2) % 6) / 5.0
        ver(c, f + i, True)
        bx, bt = c["bx"], c["bt"]
        kf(c, f + i, loc=(0.50, 0, -0.30 + 0.58 * t), rot=(0, 90, 0),
           scl=(bx * (1.7 * (1.0 - t) + 0.35), bt * 0.8, bt * 0.8))

# muerte: deformacion, ojos en X, estallido y chispas
f = R("muerte"); reposo_base(f)
kf(CTRL, f + 0, scl=(1.00, 1.00, 1.00))
kf(CTRL, f + 1, scl=(1.22, 1.22, 0.82))
kf(CTRL, f + 2, scl=(1.16, 0.94, 1.14), rot=(0, 0, 9))
for g in EQUIS:
    ver(g, f + 1, False); ver(g, f + 2, True)
for o in PIEZAS:
    ver(o, f + 2, True); ver(o, f + 3, False)
for g in EQUIS: ver(g, f + 3, False)
chispas_en(f + 2, 0.05, 0.6, False)
chispas_en(f + 3, 0.34, 1.30, True)
chispas_en(f + 4, 0.62, 0.85, True)
chispas_en(f + 5, 0.86, 0.40, True)

# aparicion: las chispas se juntan y el cuerpo entra con rebote
f = R("aparicion"); reposo_base(f, cuerpo_visible=False)
chispas_en(f + 0, 0.86, 0.45, True)
chispas_en(f + 1, 0.42, 1.00, True)
chispas_en(f + 2, 0.05, 0.40, False)
for o in PIEZAS:
    ver(o, f + 1, False); ver(o, f + 2, True)
for i, s in enumerate([0.0, 0.0, 0.55, 1.22, 1.00]):
    if i >= 2: kf(CTRL, f + i, scl=(s, s, s))

# carga baja: ojos a medio cerrar, brillo bajo y temblor
f = R("carga_baja"); reposo_base(f)
emision(f, 0.03, tinte=0.42)
for g in OJOS: kf(g, f, scl=(1, 1, 0.52))
for i, dx in enumerate([0.000, 0.014, -0.012, 0.010, -0.014, 0.000]):
    kf(CTRL, f + i, loc=(dx, 0, 0), scl=(1.0 + abs(dx), 1.0, 0.99))
emision(f + 5, 0.03, tinte=0.42)

# victoria: giro completo y crecida
f = R("victoria"); reposo_base(f)
for i, (rz, s, dz) in enumerate([(0, 1.00, 0.00), (0, 1.18, 0.06), (140, 1.10, 0.14),
                                 (280, 1.06, 0.18), (360, 1.14, 0.14), (360, 1.00, 0.06),
                                 (360, 1.08, 0.02), (360, 1.00, 0.00)]):
    kf(RAIZ, f + i, rot=(0, 0, rz), scl=(s, s, s), loc=(0, 0, dz))
for g in OJOS: kf(g, f + 1, scl=(1.15, 1, 1.15))

# marcadores en la linea de tiempo
for nombre, (a, b) in RANGOS.items():
    mk = sc.timeline_markers.new(nombre, frame=a)
sc.frame_start, sc.frame_end = 1, cursor

if RETRATO:
    sc.render.resolution_x = sc.render.resolution_y = 512
    cam_d.lens = 36.0 * 6.0 / 1.5
    sc.frame_set(RANGOS["reposo"][0])
    # retrato.png es el de TSL-04: de el salen el icono y la ficha de la tienda.
    # Las otras paletas escriben el suyo aparte, o lo pisarian.
    sc.render.filepath = os.path.join(OUT, "retrato.png" if VARIANTE == "cian" else "retrato_%s.png" % VARIANTE)
    bpy.ops.render.render(write_still=True)
    print("RETRATO listo")
    sc.render.resolution_x = sc.render.resolution_y = RES * SS
    cam_d.lens = 36.0 * 6.0 / ORTHO

# --------------------------------------------------------------- guardar .blend
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tsl04.blend"))
print("BLEND guardado")

# ----------------------------------------------------------------- modelo .glb
# La pose de reposo y nada mas: la animacion del menu se hace por codigo, porque
# alli el personaje tiene que MIRAR a la camara y responder a la opcion elegida,
# y eso no cabe en un ciclo grabado. Se van las piezas que solo salen al morir
# (los ojos en X y las chispas) y las luces y la camara, que en Godot son otras.
if GLB:
    sc.frame_set(RANGOS["reposo"][0])
    bpy.context.view_layer.update()
    for o in list(OCULTOS):
        bpy.data.objects.remove(o, do_unlink=True)
    for o in [x for x in bpy.data.objects if x.name.startswith("equis_")]:
        bpy.data.objects.remove(o, do_unlink=True)
    # la boca es una curva y el exportador de glTF solo saca mallas
    bpy.ops.object.select_all(action='DESELECT')
    boca.select_set(True)
    bpy.context.view_layer.objects.active = boca
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.data.objects:
        if o.type in ('MESH', 'EMPTY'):
            o.select_set(True)
    ruta_glb = os.path.join(OUT, "tsl04.glb")
    # export_apply=False deja fuera el Subdivision del cuerpo: la esfera base ya
    # es de 48x24 y en una pantalla de menu no se distingue, pero el modelo pasa
    # de ~19.000 triangulos a ~2.300, que es lo que se va a cargar un movil.
    bpy.ops.export_scene.gltf(filepath=ruta_glb, export_format='GLB',
                              use_selection=True, export_apply=False,
                              export_animations=False, export_yup=True)
    print("GLB listo: %s" % ruta_glb)

# ------------------------------------------------------- render + hojas + .tres
if DO_RENDER:
    import numpy as np

    def cargar(ruta):
        img = bpy.data.images.load(ruta)
        img.colorspace_settings.name = 'Non-Color'      # sin conversion de gama
        w, h = img.size
        buf = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(buf)
        a = buf.reshape(h, w, 4)[::-1].copy()           # de abajo-arriba a arriba-abajo
        bpy.data.images.remove(img)
        return a

    def reducir(a, s):
        """media por bloques con alfa premultiplicado: bordes limpios"""
        h, w, _ = a.shape
        rgb, al = a[..., :3], a[..., 3:4]
        pre = np.concatenate([rgb * al, al], axis=2)
        blo = pre.reshape(h // s, s, w // s, s, 4).mean(axis=(1, 3))
        na = blo[..., 3:4]
        rgb2 = np.divide(blo[..., :3], np.maximum(na, 1e-6))
        return np.clip(np.concatenate([rgb2, na], axis=2), 0.0, 1.0)

    def guardar(arr, ruta):
        h, w, _ = arr.shape
        img = bpy.data.images.new("hoja", w, h, alpha=True)
        img.colorspace_settings.name = 'Non-Color'
        img.alpha_mode = 'STRAIGHT'
        img.pixels.foreach_set(arr[::-1].reshape(-1).astype(np.float32))
        img.filepath_raw = ruta
        img.file_format = 'PNG'
        img.save()
        bpy.data.images.remove(img)

    dir_cuadros = os.path.join(OUT, "cuadros_%s" % VARIANTE)
    dir_hojas = os.path.join(OUT, "hojas_%s" % VARIANTE)
    os.makedirs(dir_hojas, exist_ok=True)

    hojas = []
    for nombre, n, fps, bucle in ANIMS:
        a, b = RANGOS[nombre]
        destino = os.path.join(dir_cuadros, nombre) + os.sep
        os.makedirs(destino, exist_ok=True)
        if SOLO == "" or SOLO == nombre:
            sc.frame_start, sc.frame_end = a, b
            sc.render.filepath = destino
            bpy.ops.render.render(animation=True)
        else:
            print("SALTA %s (ya renderizada)" % nombre)

        cuadros = []
        for i in range(a, b + 1):
            cuadros.append(reducir(cargar(os.path.join(destino, "%04d.png" % i)), SS))
        cols = min(COLS, n)
        filas = []
        for r in range(0, n, cols):
            tira = cuadros[r:r + cols]
            while len(tira) < cols:
                tira.append(np.zeros_like(cuadros[0]))
            filas.append(np.concatenate(tira, axis=1))
        hoja = np.concatenate(filas, axis=0)
        ruta = os.path.join(dir_hojas, "tsl04_%s.png" % nombre)
        guardar(hoja, ruta)
        hojas.append((nombre, n, fps, bucle, ruta, cols))
        print("HOJA %-12s %2d cuadros -> %dx%d (%d col)" % (nombre, n, hoja.shape[1], hoja.shape[0], cols))

    # ------------------------------------------------ recurso SpriteFrames Godot
    ext, sub, anim = [], [], []
    for idx, (nombre, n, fps, bucle, ruta, cols) in enumerate(hojas, start=1):
        eid = "%d_%s" % (idx, nombre)
        # La cian es TSL-04 y se queda donde estuvo siempre. Las demas paletas son
        # las otras celdas (TSL-01, 02, 03) y van cada una en su carpeta, para
        # que sus hojas no pisen las de TSL-04 al copiarlas al proyecto.
        carpeta = "res://arte/tsl04/" if VARIANTE == "cian" else "res://arte/tsl04/%s/" % VARIANTE
        ext.append('[ext_resource type="Texture2D" path="%stsl04_%s.png" id="%s"]' % (carpeta, nombre, eid))
        refs = []
        dur = ritmo(nombre, n)
        for i in range(n):
            sid = "%s_%02d" % (nombre, i)
            sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)'
                       % (sid, eid, (i % cols) * RES, (i // cols) * RES, RES, RES))
            refs.append('{\n"duration": %.3f,\n"texture": SubResource("%s")\n}' % (dur[i], sid))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                % (", ".join(refs), "true" if bucle else "false", nombre, float(fps)))
    total = len(ext) + len(sub) + 1
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n\n[resource]\nanimations = [%s]\n'
            % (total, "\n".join(ext), "\n\n".join(sub), ", ".join(anim)))
    with open(os.path.join(dir_hojas, "tsl04_spriteframes.tres"), "w", encoding="utf-8") as fh:
        fh.write(tres)
    print("TRES generado con %d animaciones" % len(hojas))

print("LISTO")
