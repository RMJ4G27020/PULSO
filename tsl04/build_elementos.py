# -*- coding: utf-8 -*-
"""
Elementos de nivel y obstaculos de PULSO, construidos en Blender.
Estetica: interior de una maquina. Metal oscuro, tiras luminosas, rejillas.
REGLA: todo lo ROJO hace dano. Nada inofensivo usa rojo.

blender -b --factory-startup --python build_elementos.py -- --render
blender -b --factory-startup --python build_elementos.py -- --render --solo dron_purga
"""
import bpy, math, os, sys
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
SOLO = ARGS[ARGS.index("--solo") + 1] if "--solo" in ARGS else None
OUT = os.path.dirname(os.path.abspath(__file__))
SS = 2
COLS = 6

# --------------------------------------------------------------------- paleta
ROJO   = (1.00, 0.20, 0.16)   # PELIGRO. exclusivo de lo que mata
CIAN   = (0.21, 0.85, 1.00)   # energia amiga
VOLT   = (0.78, 0.95, 0.31)   # objetivos: terminal, salida, anclaje
AMBAR  = (1.00, 0.72, 0.24)   # puertas
METAL  = (0.15, 0.17, 0.19)
# Con la transformada Standard, color x fuerza por encima de 1.0 se recorta a blanco
# y se pierde el tono. Este factor mantiene el rojo rojo y el verde verde.
EMIS   = 0.30
OSCURO = (0.07, 0.08, 0.09)

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
              bpy.data.lights, bpy.data.cameras, bpy.data.objects):
        for b in list(c):
            try: c.remove(b)
            except Exception: pass

def mat(nombre, base, emis=(0, 0, 0), fuerza=0.0, rug=0.5, metalico=0.0):
    m = bpy.data.materials.new(nombre); m.use_nodes = True
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (*base, 1)
    n.inputs["Roughness"].default_value = rug
    n.inputs["Metallic"].default_value = metalico
    n.inputs["Emission Color"].default_value = (*emis, 1)
    n.inputs["Emission Strength"].default_value = fuerza * EMIS
    return m

def cubo(nombre, loc, esc, material=None, rot=(0, 0, 0), bisel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object; o.name = nombre; o.scale = esc
    if material: o.data.materials.append(material)
    if bisel:
        bpy.ops.object.modifier_add(type='BEVEL')
        o.modifiers[-1].width = bisel; o.modifiers[-1].segments = 2
    return o

def cil(nombre, loc, r, h, material=None, rot=(0, 0, 0), verts=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object; o.name = nombre
    bpy.ops.object.shade_auto_smooth()
    if material: o.data.materials.append(material)
    return o

def esfera(nombre, loc, r, material=None, esc=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=loc)
    o = bpy.context.object; o.name = nombre; o.scale = esc
    bpy.ops.object.shade_smooth()
    if material: o.data.materials.append(material)
    return o

def cono(nombre, loc, r, h, material=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=r, radius2=0.0, depth=h, location=loc, rotation=rot)
    o = bpy.context.object; o.name = nombre
    if material: o.data.materials.append(material)
    return o

def toro(nombre, loc, R, r, material=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot,
                                     major_segments=32, minor_segments=10)
    o = bpy.context.object; o.name = nombre
    bpy.ops.object.shade_smooth()
    if material: o.data.materials.append(material)
    return o

def arco_electrico(nombre, p0, p1, semilla, grosor=0.012, nudos=7, amplitud=0.09, material=None):
    """rayo quebrado entre dos puntos, con desvio determinista"""
    cu = bpy.data.curves.new(nombre, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = grosor; cu.resolution_u = 3; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(nudos - 1)
    a, b = Vector(p0), Vector(p1)
    d = (b - a)
    perp = Vector((-d.z, 0.0, d.x))
    if perp.length < 1e-5: perp = Vector((1, 0, 0))
    perp.normalize()
    for i in range(nudos):
        t = i / (nudos - 1)
        base = a.lerp(b, t)
        ancho = math.sin(math.pi * t)          # 0 en los extremos
        off = math.sin(semilla * 12.9898 + i * 4.1414) * amplitud * ancho
        off2 = math.cos(semilla * 7.233 + i * 2.71) * amplitud * 0.5 * ancho
        p = base + perp * off + Vector((0, off2 * 0.4, 0))
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    o = bpy.data.objects.new(nombre, cu)
    if material: o.data.materials.append(material)
    bpy.context.collection.objects.link(o)
    return o

def kf(o, f, loc=None, rot=None, scl=None):
    if loc is not None: o.location = loc; o.keyframe_insert('location', frame=f)
    if rot is not None: o.rotation_euler = [math.radians(a) for a in rot]; o.keyframe_insert('rotation_euler', frame=f)
    if scl is not None: o.scale = scl; o.keyframe_insert('scale', frame=f)

def ver(o, f, visible):
    o.hide_render = not visible; o.hide_viewport = not visible
    o.keyframe_insert('hide_render', frame=f); o.keyframe_insert('hide_viewport', frame=f)

def brillo(m, f, v):
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Emission Strength"].default_value = v * EMIS
    n.inputs["Emission Strength"].keyframe_insert('default_value', frame=f)

def escena(ortho, res, azimut=-12.0, elev=7.0, dist=6.0, clave=280, borde=(0.6, 0.8, 1.0)):
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'PERSP'
    cam_d.sensor_width = 36.0; cam_d.lens = 36.0 * dist / ortho
    cam = bpy.data.objects.new("cam", cam_d)
    az, el = math.radians(azimut), math.radians(elev)
    cam.location = (dist * math.sin(az) * math.cos(el), -dist * math.cos(az) * math.cos(el), dist * math.sin(el))
    cam.rotation_euler = (Vector((0, 0, 0)) - Vector(cam.location)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(cam)

    def luz(nombre, loc, energia, color, tam):
        d = bpy.data.lights.new(nombre, 'AREA'); d.energy = energia; d.color = color; d.size = tam
        o = bpy.data.objects.new(nombre, d); o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.collection.objects.link(o)
    k = ortho
    luz("clave",   (-0.9 * k, -1.0 * k,  1.0 * k), clave * k * k * 0.11, (1.0, 0.97, 0.92), 0.8 * k)
    luz("relleno", ( 1.0 * k, -0.8 * k, -0.4 * k),  34 * k * k * 0.11, (0.62, 0.82, 1.0), 1.1 * k)
    luz("borde",   ( 0.5 * k,  0.9 * k,  0.7 * k), 420 * k * k * 0.11, borde, 0.6 * k)

    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = sc.render.resolution_y = res * SS
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    try: sc.eevee.taa_render_samples = 64
    except Exception: pass
    sc.view_settings.view_transform = 'Standard'
    try: sc.view_settings.look = 'None'
    except Exception: pass
    w = bpy.data.worlds.new("m"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    return sc

# ============================================================ PIEZAS DE NIVEL
# Cada funcion construye, anima y devuelve (animaciones, ortho, res, color_borde)

def p_pared():
    """Pared vertical del pozo. NO es el bloque de suelo girado: ese lleva la
    tira cian en el canto de arriba, y esa tira significa "aqui se pisa".
    Repetida en vertical le esta diciendo al jugador que puede pisar en sitios
    donde no puede. Aqui la tira va en los DOS lados, que es de donde si se
    agarra, y las pistas corren en vertical como corresponde a una placa
    montada de canto."""
    M_SUS = mat("sustrato", (0.042, 0.075, 0.070), rug=0.85, metalico=0.10)
    M_COB = mat("cobre",    (0.58, 0.33, 0.13),    rug=0.26, metalico=0.95)
    M_EST = mat("estano",   (0.62, 0.64, 0.66),    rug=0.22, metalico=1.00)
    M_OSC = mat("osc", OSCURO, rug=0.75, metalico=0.5)
    M_BOR = mat("bor", (0.06, 0.18, 0.22), CIAN, 0.9, 0.3)

    cubo("cuerpo", (0, 0, 0), (0.98, 0.9, 0.98), M_SUS, bisel=0.045)

    CARA = -0.462
    def pista(n, x0, z0, w, h):
        cubo(n, (x0 + w * 0.5, CARA, z0 + h * 0.5), (w, 0.028, h), M_COB, bisel=0)

    # bus vertical con derivaciones: la placa va de canto
    pista("bus",   -0.03, -0.44, 0.055, 0.88)
    pista("der_a", -0.03, -0.26, 0.30,  0.055)
    pista("der_b", -0.30,  0.06, 0.28,  0.055)
    pista("der_c", -0.03,  0.30, 0.26,  0.055)

    for i, (x, z) in enumerate([(0.27, -0.26), (-0.30, 0.06), (0.23, 0.30)]):
        cil("pad_%d" % i, (x, CARA - 0.014, z), 0.068, 0.030, M_EST,
            rot=(math.radians(90), 0, 0), verts=12)
        cil("via_%d" % i, (x, CARA - 0.032, z), 0.019, 0.030, M_OSC,
            rot=(math.radians(90), 0, 0), verts=8)

    # los cantos LATERALES son lo agarrable, asi que ahi va la luz
    for sx in (-1, 1):
        cubo("canto_%d" % sx, (0.478 * sx, -0.34, 0), (0.036, 0.24, 0.99), M_BOR, bisel=0)
    A = [("pared", 1, 1, False)]
    brillo(M_BOR, 1, 0.9)
    return A, 1.0, 96, CIAN

def p_pinchos():
    M_MET = mat("met", METAL, rug=0.5, metalico=0.75)
    M_REJ = mat("rej", OSCURO, rug=0.8, metalico=0.4)
    M_ROJ = mat("rojo", (0.25, 0.03, 0.02), ROJO, 3.0, 0.3)
    cubo("base", (0, 0, -0.42), (1.02, 0.52, 0.14), M_REJ)
    for i in range(5):                                    # rejilla de la base
        cubo("ranura_%d" % i, (-0.4 + i * 0.2, -0.27, -0.42), (0.06, 0.03, 0.10), M_ROJ, bisel=0)
    puas = []
    for i, x in enumerate((-0.30, 0.0, 0.30)):
        cono("pua_%d" % i, (x, 0, -0.10), 0.13, 0.52, M_MET)
        p = bpy.context.object
        cono("filo_%d" % i, (x, -0.09, -0.09), 0.055, 0.50, M_ROJ)
        puas.append((p, bpy.context.object))
    A = [("pinchos", 6, 8, True)]
    f = 1
    for i in range(6):
        v = 2.2 + 1.6 * math.sin(i * math.pi / 3.0)
        brillo(M_ROJ, f + i, v)
        for p, fi in puas:
            kf(p, f + i, loc=(p.location.x, 0, -0.10 + 0.006 * math.sin(i * math.pi / 3.0)))
    return A, 1.5, 144, ROJO


def p_bloque_pulsante():
    M_MET = mat("met", METAL, rug=0.45, metalico=0.8)
    M_ROJ = mat("rojo", (0.22, 0.03, 0.02), ROJO, 0.2, 0.3)
    cubo("carcasa", (0, 0, 0), (0.94, 0.62, 0.94), M_MET, bisel=0.05)
    nucleo = cubo("nucleo", (0, -0.02, 0), (0.62, 0.62, 0.62), M_ROJ, bisel=0.06)
    for i in range(3):                                    # rendijas
        cubo("rendija_%d" % i, (0, -0.33, -0.26 + i * 0.26), (0.66, 0.06, 0.07), M_ROJ, bisel=0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cil("perno_%d%d" % (sx, sz), (0.38 * sx, -0.32, 0.38 * sz), 0.05, 0.06, M_MET,
                rot=(math.radians(90), 0, 0), verts=8)
    A = [("apagado", 4, 8, True), ("aviso", 4, 12, True), ("encendido", 6, 12, True)]
    R = {}; cur = 1
    for n, c, _fps, _b in A:
        R[n] = cur; cur += c + 3
    f = R["apagado"]
    for i in range(4):
        brillo(M_ROJ, f + i, 0.55 + 0.15 * math.sin(i * math.pi / 2))
        kf(nucleo, f + i, scl=(0.62, 0.62, 0.62))
    f = R["aviso"]
    for i in range(4):
        brillo(M_ROJ, f + i, 0.6 + 1.4 * (i % 2))
        kf(nucleo, f + i, scl=(0.62 + 0.02 * (i % 2),) * 3)
    f = R["encendido"]
    for i in range(6):
        brillo(M_ROJ, f + i, 4.2 + 1.1 * math.sin(i * math.pi / 3))
        s = 0.66 + 0.03 * math.sin(i * math.pi / 3)
        kf(nucleo, f + i, scl=(s, 0.62, s))
    return A, 1.5, 144, ROJO


def p_laser_emisor():
    M_MET = mat("met", METAL, rug=0.42, metalico=0.85)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.5)
    M_ROJ = mat("rojo", (0.25, 0.03, 0.02), ROJO, 0.4, 0.25)
    cubo("anclaje", (0, 0, 0.40), (0.86, 0.55, 0.22), M_OSC, bisel=0.04)
    cil("cuerpo", (0, 0, 0.10), 0.30, 0.42, M_MET, rot=(math.radians(90), 0, 0))
    cil("collar", (0, 0, -0.13), 0.34, 0.10, M_OSC, rot=(math.radians(90), 0, 0))
    lente = cil("lente", (0, -0.02, -0.22), 0.20, 0.08, M_ROJ, rot=(math.radians(90), 0, 0))
    for i in range(3):
        cubo("tira_%d" % i, (-0.24 + i * 0.24, -0.29, 0.12), (0.05, 0.03, 0.22), M_ROJ, bisel=0)
    arcos = [arco_electrico("arc_%d" % i, (-0.18, -0.16, -0.16), (0.18, -0.16, -0.16),
                            i * 2.3 + 0.7, 0.010, 6, 0.07, M_ROJ) for i in range(3)]
    A = [("reposo", 4, 8, True), ("carga", 5, 16, False), ("dispara", 6, 14, True)]
    R = {}; cur = 1
    for n, c, _f, _b in A:
        R[n] = cur; cur += c + 3
    f = R["reposo"]
    for i in range(4):
        brillo(M_ROJ, f + i, 0.35 + 0.12 * math.sin(i * math.pi / 2))
        kf(lente, f + i, scl=(1, 1, 1))
        for a in arcos: ver(a, f + i, False)
    f = R["carga"]
    for i in range(5):
        brillo(M_ROJ, f + i, 0.6 + i * 0.9)
        kf(lente, f + i, scl=(1 + i * 0.06, 1, 1 + i * 0.06))
        for j, a in enumerate(arcos): ver(a, f + i, i >= 2 and (i + j) % 2 == 0)
    f = R["dispara"]
    for i in range(6):
        brillo(M_ROJ, f + i, 5.0 + 1.6 * math.sin(i * math.pi / 3))
        kf(lente, f + i, scl=(1.22, 1, 1.22))
        for j, a in enumerate(arcos): ver(a, f + i, (i + j) % 3 != 0)
    return A, 1.5, 144, ROJO


def p_laser_haz():
    """segmento de haz, se repite en vertical para formar el rayo entero"""
    M_ROJ = mat("rojo", ROJO, ROJO, 3.4, 0.2)
    M_NUC = mat("nucleo", (1, 0.85, 0.82), (1, 0.9, 0.88), 6.5, 0.1)
    ext = cil("externo", (0, 0, 0), 0.13, 1.02, M_ROJ, rot=(0, 0, 0), verts=16)
    nuc = cil("nucleo", (0, -0.02, 0), 0.05, 1.02, M_NUC, rot=(0, 0, 0), verts=12)
    arcos = [arco_electrico("h_%d" % i, (0, -0.05, -0.5), (0, -0.05, 0.5),
                            i * 3.1 + 1.3, 0.008, 8, 0.06, M_ROJ) for i in range(4)]
    A = [("haz", 6, 20, True)]
    f = 1
    for i in range(6):
        s = 1.0 + 0.13 * math.sin(i * math.pi / 3)
        kf(ext, f + i, scl=(s, s, 1))
        kf(nuc, f + i, scl=(1.0 + 0.3 * math.sin(i * 1.7), 1.0 + 0.3 * math.sin(i * 1.7), 1))
        brillo(M_ROJ, f + i, 3.0 + 0.9 * math.sin(i * math.pi / 3))
        for j, a in enumerate(arcos): ver(a, f + i, (i + j) % 2 == 0)
    return A, 1.0, 96, ROJO


def p_bloque():
    """Pieza de suelo/pared. Ya no es metal a secas: es un trozo de placa de
    circuito, que es de lo que esta hecho el sitio donde pasa el juego.
    Sustrato oscuro, pistas de cobre enrutadas SIEMPRE en angulo recto (asi
    se enrutan de verdad), pads con su via, y aletas de disipador en el canto
    de arriba. El cobre no emite: el codigo de color del GDD manda, y lo que
    brilla en ambar son las puertas.
    Se repite en rejilla para construir la geometria del nivel."""
    M_SUS = mat("sustrato", (0.042, 0.075, 0.070), rug=0.85, metalico=0.10)
    M_COB = mat("cobre",    (0.58, 0.33, 0.13),    rug=0.26, metalico=0.95)
    M_EST = mat("estano",   (0.62, 0.64, 0.66),    rug=0.22, metalico=1.00)
    M_OSC = mat("osc", OSCURO, rug=0.75, metalico=0.5)
    M_BOR = mat("bor", (0.06, 0.18, 0.22), CIAN, 0.9, 0.3)

    cubo("cuerpo", (0, 0, 0), (0.98, 0.9, 0.98), M_SUS, bisel=0.045)

    CARA = -0.462          # justo delante de la cara frontal
    def pista(n, x0, z0, w, h):
        cubo(n, (x0 + w * 0.5, CARA, z0 + h * 0.5), (w, 0.028, h), M_COB, bisel=0)

    # un bus horizontal y ramas que suben en angulo recto
    pista("bus",   -0.44, -0.32, 0.88, 0.055)
    pista("ram_a", -0.24, -0.32, 0.055, 0.36)
    pista("ram_b", -0.24,  0.00, 0.40,  0.055)
    pista("ram_c",  0.22, -0.32, 0.055, 0.52)
    pista("ram_d", -0.44,  0.14, 0.24,  0.055)

    # pads: corona de estano con la via oscura en el centro
    for i, (x, z) in enumerate([(-0.24, 0.00), (0.16, 0.00), (0.22, 0.20),
                                (-0.20, 0.14), (0.38, -0.32)]):
        cil("pad_%d" % i, (x, CARA - 0.014, z), 0.068, 0.030, M_EST,
            rot=(math.radians(90), 0, 0), verts=12)
        # la via es el agujero: pequena, o el pad se lee como un disco negro
        cil("via_%d" % i, (x, CARA - 0.032, z), 0.019, 0.030, M_OSC,
            rot=(math.radians(90), 0, 0), verts=8)

    # aletas de disipador en el canto: se ven porque la camara mira 7 grados
    # desde arriba, y son lo que dice "esto disipa calor", no "esto es una caja"
    for i in range(7):
        cubo("aleta_%d" % i, (-0.39 + i * 0.13, 0.02, 0.455),
             (0.050, 0.74, 0.16), M_OSC, bisel=0.008)

    # la tira va delante: las aletas asoman por detras de ella
    cubo("tira", (0, -0.34, 0.472), (0.99, 0.24, 0.036), M_BOR, bisel=0)
    A = [("bloque", 1, 1, False)]
    brillo(M_BOR, 1, 0.9)
    return A, 1.0, 96, CIAN

def p_dron_purga():
    M_MET = mat("met", METAL, rug=0.4, metalico=0.85)
    M_OSC = mat("osc", OSCURO, rug=0.65, metalico=0.6)
    M_ROJ = mat("rojo", (0.28, 0.03, 0.02), ROJO, 2.6, 0.25)
    cuerpo = bpy.data.objects.new("dron", None); bpy.context.collection.objects.link(cuerpo)
    def hijo(o): o.parent = cuerpo
    c = cubo("casco", (0, 0, 0), (1.05, 0.55, 0.38), M_MET, bisel=0.09); hijo(c)
    t = cubo("torreta", (0.05, 0, 0.26), (0.55, 0.42, 0.18), M_OSC, bisel=0.05); hijo(t)
    for sx in (-1, 1):                                    # aletas
        a = cubo("aleta_%d" % sx, (0.52 * sx, 0, -0.06), (0.22, 0.36, 0.30), M_OSC,
                 rot=(0, math.radians(18 * sx), 0), bisel=0.03); hijo(a)
    ojo = esfera("ojo", (-0.26, -0.29, 0.02), 0.15, M_ROJ, esc=(1, 0.55, 1)); hijo(ojo)
    aro = toro("aro", (-0.26, -0.26, 0.02), 0.20, 0.035, M_OSC, rot=(math.radians(90), 0, 0)); hijo(aro)
    prop = cil("propulsor", (0.05, 0, -0.26), 0.22, 0.10, M_ROJ, rot=(0, 0, 0), verts=14); hijo(prop)
    for i in range(3):
        v = cubo("vent_%d" % i, (0.30 - i * 0.16, -0.29, 0.20), (0.05, 0.03, 0.10), M_ROJ, bisel=0); hijo(v)
    A = [("patrulla", 8, 10, True), ("alerta", 6, 14, True), ("impacto", 5, 16, False)]
    R = {}; cur = 1
    for n, cn, _f, _b in A:
        R[n] = cur; cur += cn + 3
    f = R["patrulla"]
    for i in range(8):
        z = 0.07 * math.sin(i * math.pi / 4)
        kf(cuerpo, f + i, loc=(0, 0, z), rot=(0, 0, 4.5 * math.sin(i * math.pi / 4)))
        kf(ojo, f + i, loc=(-0.26 + 0.05 * math.sin(i * math.pi / 4), -0.29, 0.02))
        brillo(M_ROJ, f + i, 1.5 + 0.5 * math.sin(i * math.pi / 4))
    f = R["alerta"]
    for i in range(6):
        z = 0.11 * math.sin(i * math.pi / 1.5)
        kf(cuerpo, f + i, loc=(0, 0, z), rot=(0, 0, -6 + 3 * (i % 2)))
        kf(ojo, f + i, loc=(-0.26, -0.31, 0.02), scl=(1.18, 1, 1.18))
        brillo(M_ROJ, f + i, 4.6 + 1.4 * (i % 2))
    f = R["impacto"]
    for i, (dx, rz, s) in enumerate([(0.10, -14, 1.0), (0.16, 10, 1.08), (0.06, -6, 0.94),
                                     (0.02, 3, 1.02), (0.0, 0, 1.0)]):
        kf(cuerpo, f + i, loc=(dx, 0, -0.05), rot=(0, 0, rz), scl=(s, 1, 2.0 - s))
        brillo(M_ROJ, f + i, 6.0 - i * 1.0)
    return A, 3.0, 288, ROJO


def p_dron_zapador():
    M_MET = mat("met", METAL, rug=0.4, metalico=0.85)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.55)
    M_ROJ = mat("rojo", (0.28, 0.03, 0.02), ROJO, 1.2, 0.25)
    cubo("placa", (0, 0, 0.66), (1.0, 0.6, 0.16), M_OSC, bisel=0.04)
    for sx in (-1, 1):
        cil("tornillo_%d" % sx, (0.36 * sx, -0.34, 0.66), 0.06, 0.06, M_MET,
            rot=(math.radians(90), 0, 0), verts=8)
    esfera("rotula", (0, 0, 0.42), 0.26, M_MET, esc=(1, 0.9, 1))
    canon = bpy.data.objects.new("canon", None); bpy.context.collection.objects.link(canon)
    canon.location = (0, 0, 0.42)
    c1 = cil("tubo", (0, 0, -0.30), 0.15, 0.62, M_MET, rot=(0, 0, 0)); c1.parent = canon
    c1.location = (0, 0, -0.30)
    c2 = cil("boca", (0, 0, -0.60), 0.19, 0.12, M_OSC, rot=(0, 0, 0)); c2.parent = canon
    c2.location = (0, 0, -0.60)
    lente = cil("lente", (0, 0, -0.66), 0.13, 0.05, M_ROJ, rot=(0, 0, 0), verts=14)
    lente.parent = canon; lente.location = (0, 0, -0.66)
    A = [("reposo", 6, 8, True), ("apunta", 5, 14, False), ("dispara", 4, 18, False)]
    R = {}; cur = 1
    for n, cn, _f, _b in A:
        R[n] = cur; cur += cn + 3
    f = R["reposo"]
    for i in range(6):
        kf(canon, f + i, rot=(0, 22 * math.sin(i * math.pi / 3), 0))
        brillo(M_ROJ, f + i, 0.9 + 0.3 * math.sin(i * math.pi / 3))
    f = R["apunta"]
    for i, r in enumerate([18, 4, -12, -20, -18]):
        kf(canon, f + i, rot=(0, r, 0))
        brillo(M_ROJ, f + i, 1.2 + i * 1.1)
    f = R["dispara"]
    for i, (r, dz, b) in enumerate([(-18, 0.0, 9.0), (-16, 0.09, 6.0), (-18, 0.03, 3.0), (-18, 0.0, 1.4)]):
        kf(canon, f + i, rot=(0, r, 0), loc=(0, 0, 0.42 + dz))
        brillo(M_ROJ, f + i, b)
    return A, 2.5, 240, ROJO


def p_interruptor():
    """La terminal que abre la puerta. Ambar cuando esta bloqueada, volt al activarse.
    Nunca roja: el rojo esta reservado para lo que mata."""
    M_MET = mat("met", METAL, rug=0.45, metalico=0.8)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.5)
    M_PAN = mat("pan", (0.20, 0.15, 0.05), AMBAR, 0.9, 0.25)
    M_LUZ = mat("luz", (0.14, 0.20, 0.06), VOLT, 0.5, 0.25)
    cubo("zocalo", (0, 0, -1.02), (1.24, 0.80, 0.34), M_OSC, bisel=0.05)
    cubo("columna", (0, 0, -0.36), (0.86, 0.64, 1.02), M_MET, bisel=0.06)
    for i in range(3):
        cubo("rej_%d" % i, (0, -0.34, -0.66 + i * 0.22), (0.56, 0.05, 0.07), M_OSC, bisel=0)
    # la cabeza va agrupada: si roto cada pieza por separado, el panel se mete dentro
    cab_g = bpy.data.objects.new("cabeza_g", None); bpy.context.collection.objects.link(cab_g)
    cab_g.location = (0, -0.10, 0.36); cab_g.rotation_euler = (math.radians(-22), 0, 0)
    cb = cubo("cabeza", (0, 0, 0), (1.24, 0.72, 0.62), M_MET, bisel=0.06)
    cb.parent = cab_g; cb.location = (0, 0, 0)
    panel = cubo("panel", (0, 0, 0), (0.94, 0.06, 0.42), M_PAN, bisel=0.02)
    panel.parent = cab_g; panel.location = (0, -0.375, 0.02)
    vs = cubo("visera", (0, 0, 0), (1.32, 0.70, 0.10), M_OSC, bisel=0.03)
    vs.parent = cab_g; vs.location = (0, -0.06, 0.36)
    panel_v = cubo("panel_activo", (0, 0, 0), (0.94, 0.06, 0.42), M_LUZ, bisel=0.02)
    panel_v.parent = cab_g; panel_v.location = (0, -0.385, 0.02)
    mrc = cubo("marco", (0, 0, 0), (1.04, 0.05, 0.52), M_OSC, bisel=0.02)
    mrc.parent = cab_g; mrc.location = (0, -0.350, 0.02)
    palanca = bpy.data.objects.new("palanca", None); bpy.context.collection.objects.link(palanca)
    palanca.location = (0.74, -0.16, 0.02)
    br = cil("brazo", (0, 0, 0.26), 0.055, 0.52, M_MET, rot=(0, 0, 0), verts=10); br.parent = palanca
    br.location = (0, 0, 0.26)
    bo = esfera("bola", (0, 0, 0.54), 0.13, M_PAN); bo.parent = palanca; bo.location = (0, 0, 0.54)
    cil("eje", (0.74, -0.16, 0.02), 0.10, 0.22, M_OSC, rot=(0, math.radians(90), 0), verts=10)
    arcos = []
    for i in range(3):
        a = arco_electrico("ia_%d" % i, (-0.40, -0.40, 0.02), (0.40, -0.40, 0.02),
                           i * 3.3 + 0.8, 0.011, 6, 0.09, M_LUZ)
        a.parent = cab_g
        arcos.append(a)
    A = [("apagado", 6, 8, True), ("activar", 6, 16, False), ("activo", 8, 10, True)]
    R = {}; cur = 1
    for n, c, _f, _b in A:
        R[n] = cur; cur += c + 3
    f = R["apagado"]
    for i in range(6):
        brillo(M_PAN, f + i, 0.75 + 0.2 * math.sin(i * math.pi / 3))
        brillo(M_LUZ, f + i, 0.0)
        kf(palanca, f + i, rot=(0, -26, 0))
        ver(panel_v, f + i, False)
        for a in arcos: ver(a, f + i, False)
    f = R["activar"]
    for i, (rot, pa, lu) in enumerate([(-26, 0.9, 0.0), (-6, 1.6, 0.6), (18, 0.5, 2.6),
                                       (30, 0.2, 3.4), (26, 0.1, 2.2), (28, 0.05, 1.6)]):
        kf(palanca, f + i, rot=(0, rot, 0))
        brillo(M_PAN, f + i, pa); brillo(M_LUZ, f + i, max(lu, 0.9))
        ver(panel_v, f + i, i >= 2)          # la pantalla cambia de ambar a volt
        for j, a in enumerate(arcos): ver(a, f + i, i >= 2 and (i + j) % 2 == 0)
    f = R["activo"]
    for i in range(8):
        t = i / 8.0
        brillo(M_PAN, f + i, 0.05); brillo(M_LUZ, f + i, 1.3 + 0.4 * math.sin(t * math.tau))
        ver(panel_v, f + i, True)
        kf(palanca, f + i, rot=(0, 28, 0))
        for j, a in enumerate(arcos): ver(a, f + i, (i + j) % 3 == 0)
    return A, 3.0, 288, VOLT

def p_puerta():
    """Compuerta de sector. Cerrada bloquea; al abrirse sube y se mete en el marco."""
    M_MET = mat("met", METAL, rug=0.45, metalico=0.85)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.5)
    M_AMB = mat("amb", (0.24, 0.16, 0.04), AMBAR, 0.9, 0.3)
    cubo("dintel", (0, 0, 1.28), (1.34, 0.86, 0.42), M_OSC, bisel=0.05)
    cubo("umbral", (0, 0, -1.28), (1.34, 0.86, 0.42), M_OSC, bisel=0.05)
    for sx in (-1, 1):
        cubo("jamba_%d" % sx, (0.60 * sx, 0, 0), (0.20, 0.78, 2.20), M_OSC, bisel=0.04)
        for i in range(3):
            cubo("perno_%d%d" % (sx, i), (0.60 * sx, -0.40, -0.7 + i * 0.7),
                 (0.07, 0.05, 0.07), M_MET, bisel=0)
    hoja = bpy.data.objects.new("hoja", None); bpy.context.collection.objects.link(hoja)
    h1 = cubo("chapa", (0, 0, 0), (0.98, 0.52, 2.02), M_MET, bisel=0.05); h1.parent = hoja
    for i in range(4):                                   # franjas de peligro
        fr = cubo("franja_%d" % i, (0, -0.28, -0.72 + i * 0.48), (1.02, 0.04, 0.15), M_AMB,
                  rot=(0, math.radians(24), 0), bisel=0)
        fr.parent = hoja
    A = [("cerrada", 4, 6, True), ("abriendo", 8, 14, False), ("abierta", 4, 6, True)]
    R = {}; cur = 1
    for n, c, _f, _b in A:
        R[n] = cur; cur += c + 3
    f = R["cerrada"]
    for i in range(4):
        kf(hoja, f + i, loc=(0, 0, 0))
        ver(h1, f + i, True)
        brillo(M_AMB, f + i, 0.9 + 0.25 * math.sin(i * math.pi / 2))
    f = R["abriendo"]
    for i, z in enumerate([0.0, -0.08, 0.22, 0.70, 1.20, 1.66, 1.98, 2.10]):
        kf(hoja, f + i, loc=(0, 0, z))
        brillo(M_AMB, f + i, 1.6 if i < 3 else max(1.6 - i * 0.2, 0.25))
    f = R["abierta"]
    for i in range(4):
        kf(hoja, f + i, loc=(0, 0, 2.10))
        brillo(M_AMB, f + i, 0.30)
    return A, 3.4, 288, AMBAR

def p_portal():
    M_MET = mat("met", METAL, rug=0.35, metalico=0.9)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.5)
    M_VOL = mat("volt", (0.16, 0.22, 0.06), VOLT, 3.2, 0.2)
    toro("marco", (0, 0, 0), 0.80, 0.10, M_MET, rot=(math.radians(90), 0, 0))
    for i in range(8):                                     # anclajes del marco
        a = math.radians(i * 45)
        cubo("garra_%d" % i, (math.cos(a) * 0.80, 0, math.sin(a) * 0.80),
             (0.13, 0.30, 0.09), M_OSC, rot=(0, -a, 0), bisel=0.02)
    disco = cil("disco", (0, 0.06, 0), 0.72, 0.05, M_VOL, rot=(math.radians(90), 0, 0), verts=32)
    aro_int = toro("aro_int", (0, 0.02, 0), 0.55, 0.035, M_VOL, rot=(math.radians(90), 0, 0))
    remolinos = [arco_electrico("rem_%d" % i,
                                (math.cos(math.radians(i * 120)) * 0.62, -0.02, math.sin(math.radians(i * 120)) * 0.62),
                                (0, -0.02, 0), i * 4.7 + 0.9, 0.020, 8, 0.16, M_VOL) for i in range(3)]
    A = [("portal", 12, 12, True)]
    f = 1
    for i in range(12):
        t = i / 12.0
        kf(disco, f + i, scl=(1 - 0.05 * math.sin(t * math.tau), 1, 1 - 0.05 * math.sin(t * math.tau)))
        kf(aro_int, f + i, rot=(90, 0, 360 * t), scl=(0.9 + 0.14 * math.sin(t * math.tau),) * 3)
        brillo(M_VOL, f + i, 2.6 + 0.9 * math.sin(t * math.tau * 2))
        for j, r in enumerate(remolinos):
            kf(r, f + i, rot=(0, -(360 * t + j * 120), 0))
            ver(r, f + i, (i + j) % 4 != 0)
    return A, 2.4, 240, VOLT


def p_anclaje():
    """punto de aparicion. En PULSO no guarda partida: marca donde reapareces."""
    M_MET = mat("met", METAL, rug=0.45, metalico=0.8)
    M_OSC = mat("osc", OSCURO, rug=0.7, metalico=0.5)
    M_CIA = mat("cian", (0.05, 0.16, 0.20), CIAN, 2.0, 0.2)
    cubo("placa", (0, 0, -0.62), (1.30, 0.70, 0.16), M_OSC, bisel=0.04)
    cubo("borde", (0, 0, -0.52), (1.05, 0.58, 0.06), M_MET, bisel=0.02)
    aro = toro("aro", (0, 0, -0.48), 0.42, 0.05, M_CIA, rot=(math.radians(90), 0, 0))
    col = cil("columna", (0, 0, 0.10), 0.28, 1.10, M_CIA, verts=20)
    for sx in (-1, 1):
        cubo("poste_%d" % sx, (0.56 * sx, 0, -0.34), (0.12, 0.24, 0.34), M_MET, bisel=0.02)
    chispas = [arco_electrico("ch_%d" % i, (0, -0.02, -0.45), (0, -0.02, 0.62),
                              i * 2.9 + 0.4, 0.014, 7, 0.13, M_CIA) for i in range(4)]
    A = [("apagado", 4, 6, True), ("activa", 6, 16, False), ("activo", 8, 10, True)]
    R = {}; cur = 1
    for n, cn, _f, _b in A:
        R[n] = cur; cur += cn + 3
    f = R["apagado"]
    for i in range(4):
        brillo(M_CIA, f + i, 0.9)
        kf(col, f + i, scl=(1, 1, 0.02), loc=(0, 0, -0.45))
        kf(aro, f + i, scl=(0.9, 0.9, 0.9))
        for c in chispas: ver(c, f + i, False)
    f = R["activa"]
    for i, (h, b) in enumerate([(0.05, 0.6), (0.55, 3.4), (1.25, 5.0), (1.05, 3.2), (1.12, 2.6), (1.10, 2.2)]):
        brillo(M_CIA, f + i, b)
        kf(col, f + i, scl=(1 + 0.10 * (i == 2), 1, h), loc=(0, 0, -0.45 + h * 0.55))
        kf(aro, f + i, scl=(0.9 + 0.25 * (i in (1, 2)),) * 3)
        for j, c in enumerate(chispas): ver(c, f + i, i >= 1 and (i + j) % 2 == 0)
    f = R["activo"]
    for i in range(8):
        t = i / 8.0
        brillo(M_CIA, f + i, 2.0 + 0.6 * math.sin(t * math.tau))
        kf(col, f + i, scl=(1 + 0.05 * math.sin(t * math.tau), 1, 1.10), loc=(0, 0, 0.155))
        kf(aro, f + i, scl=(1.0 + 0.06 * math.sin(t * math.tau),) * 3)
        for j, c in enumerate(chispas): ver(c, f + i, (i + j) % 3 != 0)
    return A, 2.4, 240, CIAN


# ================================================================ render comun
PIEZAS = [("bloque", p_bloque), ("pared", p_pared), ("pinchos", p_pinchos), ("bloque_pulsante", p_bloque_pulsante),
          ("laser_emisor", p_laser_emisor), ("laser_haz", p_laser_haz),
          ("dron_purga", p_dron_purga), ("dron_zapador", p_dron_zapador),
          ("portal", p_portal), ("anclaje", p_anclaje),
          ("interruptor", p_interruptor), ("puerta", p_puerta)]

def rangos(A):
    R = {}; cur = 1
    for n, c, _f, _b in A:
        R[n] = (cur, cur + c - 1); cur += c + 3
    return R, cur

if DO_RENDER:
    import numpy as np

    def cargar(ruta):
        img = bpy.data.images.load(ruta); img.colorspace_settings.name = 'Non-Color'
        w, h = img.size
        buf = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(buf)
        a = buf.reshape(h, w, 4)[::-1].copy(); bpy.data.images.remove(img); return a

    def reducir(a, s):
        h, w, _ = a.shape
        rgb, al = a[..., :3], a[..., 3:4]
        pre = np.concatenate([rgb * al, al], axis=2)
        blo = pre.reshape(h // s, s, w // s, s, 4).mean(axis=(1, 3))
        na = blo[..., 3:4]
        return np.clip(np.concatenate([np.divide(blo[..., :3], np.maximum(na, 1e-6)), na], axis=2), 0, 1)

    def guardar(arr, ruta):
        h, w, _ = arr.shape
        img = bpy.data.images.new("h", w, h, alpha=True)
        img.colorspace_settings.name = 'Non-Color'; img.alpha_mode = 'STRAIGHT'
        img.pixels.foreach_set(arr[::-1].reshape(-1).astype(np.float32))
        img.filepath_raw = ruta; img.file_format = 'PNG'; img.save()
        bpy.data.images.remove(img)

DIR_H = os.path.join(OUT, "hojas_elementos")
os.makedirs(DIR_H, exist_ok=True)
resumen = []

for nombre, constructor in PIEZAS:
    if SOLO and SOLO != nombre:
        continue
    limpiar()
    A, ortho, res, borde = constructor()
    sc = escena(ortho, res, borde=borde)
    R, fin = rangos(A)
    for n, (a, b) in R.items():
        sc.timeline_markers.new("%s_%s" % (nombre, n), frame=a)
    sc.frame_start, sc.frame_end = 1, fin
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "elem_%s.blend" % nombre))
    print("BLEND %-18s %d animaciones  %d px" % (nombre, len(A), res))
    if not DO_RENDER:
        continue
    hojas = []
    for n, cuad, fps, bucle in A:
        a, b = R[n]
        dest = os.path.join(OUT, "cuadros_elem", nombre, n) + os.sep
        os.makedirs(dest, exist_ok=True)
        sc.frame_start, sc.frame_end = a, b
        sc.render.filepath = dest
        bpy.ops.render.render(animation=True)
        marcos = [reducir(cargar(os.path.join(dest, "%04d.png" % i)), SS) for i in range(a, b + 1)]
        cols = min(COLS, cuad)
        filas = []
        for r0 in range(0, cuad, cols):
            tira = marcos[r0:r0 + cols]
            while len(tira) < cols: tira.append(np.zeros_like(marcos[0]))
            filas.append(np.concatenate(tira, axis=1))
        hoja = np.concatenate(filas, axis=0)
        ruta = os.path.join(DIR_H, "%s_%s.png" % (nombre, n))
        guardar(hoja, ruta)
        hojas.append((n, cuad, fps, bucle, cols))
        print("HOJA %-18s %-10s %2d cuadros -> %dx%d" % (nombre, n, cuad, hoja.shape[1], hoja.shape[0]))
    # SpriteFrames de Godot con todas las animaciones de la pieza
    ext, sub, anim = [], [], []
    for idx, (n, cuad, fps, bucle, cols) in enumerate(hojas, start=1):
        eid = "%d_%s" % (idx, n)
        ext.append('[ext_resource type="Texture2D" path="res://arte/elementos/%s_%s.png" id="%s"]' % (nombre, n, eid))
        refs = []
        for i in range(cuad):
            sid = "%s_%02d" % (n, i)
            sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)'
                       % (sid, eid, (i % cols) * res, (i // cols) * res, res, res))
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                    % (", ".join(refs), "true" if bucle else "false", n, float(fps)))
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n\n[resource]\nanimations = [%s]\n'
            % (len(ext) + len(sub) + 1, "\n".join(ext), "\n\n".join(sub), ", ".join(anim)))
    open(os.path.join(DIR_H, "%s_spriteframes.tres" % nombre), "w", encoding="utf-8").write(tres)
    resumen.append((nombre, res, len(A), sum(x[1] for x in hojas)))

for r in resumen:
    print("PIEZA %-18s %3d px  %d animaciones  %2d cuadros" % r)
print("LISTO")
