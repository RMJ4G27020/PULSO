# -*- coding: utf-8 -*-
"""Fondo de PULSO: el interior de la maquina, visto de lejos.
Blender 5.x | blender -b --factory-startup --python build_fondo.py -- --render

Lamina que se repite en horizontal detras del nivel. Todo mas oscuro y mas
apagado que el primer plano: si compite con las plataformas, el jugador deja
de leer por donde puede pasar. Nada de rojo aqui, que el rojo mata.
"""
import bpy, math, os, sys, random

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
OUT = os.path.dirname(os.path.abspath(__file__))
ANCHO, ALTO = 640, 360          # el mosaico mide justo una pantalla de ancho
SS = 2
N = 16                          # cuadros del bucle
FPS = 8                         # 2 segundos de ciclo
COLS = 4                        # rejilla de la hoja

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.curves):
        for b in list(c): c.remove(b)

def mat(n, base, emis=(0,0,0), fuerza=0.0, rug=0.6, metalico=0.0):
    m = bpy.data.materials.new(n); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Emission Color"].default_value = (*emis, 1)
    b.inputs["Emission Strength"].default_value = fuerza
    b.inputs["Roughness"].default_value = rug
    b.inputs["Metallic"].default_value = metalico
    return m

def cubo(n, loc, esc, m, rot=(0,0,0), bisel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object; o.name = n; o.scale = esc
    o.data.materials.append(m)
    if bisel:
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = bisel
    return o

def cil(n, loc, r, h, m, rot=(0,0,0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object; o.name = n; o.data.materials.append(m); return o

limpiar()
rnd = random.Random(20260906)

SUS = mat("sustrato", (0.020, 0.036, 0.034), rug=0.9)
CHIP = mat("chip",    (0.030, 0.033, 0.036), rug=0.85, metalico=0.2)
PATA = mat("pata",    (0.075, 0.080, 0.085), rug=0.4, metalico=0.9)
COND = mat("cond",    (0.045, 0.055, 0.070), rug=0.5, metalico=0.4)
PIS  = mat("pista",   (0.030, 0.075, 0.085), (0.21, 0.85, 1.00), 0.055, rug=0.6)
# apagado a proposito: si un paquete brilla como el borde de una plataforma,
# el ojo va al fondo y dejas de leer por donde puedes pasar
PAQ  = mat("paquete", (0.06, 0.18, 0.21),    (0.30, 0.82, 0.95), 0.42, rug=0.35)

def kf(o, f, loc=None):
    if loc is not None:
        o.location = loc; o.keyframe_insert('location', frame=f)

def brillo(m, f, v):
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Emission Strength"].default_value = v
    n.inputs["Emission Strength"].keyframe_insert('default_value', frame=f)

W, H = 10.0, 5.6                       # unidades de mundo que cubre la lamina
cubo("placa", (0, 0.9, 0), (W * 1.3, 0.5, H * 1.3), SUS)

# --- buses: lineas largas en angulo recto, muy tenues
BUSES = []
for i in range(9):
    z = -H/2 + 0.35 + i * (H - 0.7) / 8.0
    cubo("bus_%d" % i, (0, 0.62, z), (W * 1.25, 0.03, 0.030), PIS)
    x = -W/2 + rnd.uniform(0.4, 1.2) + i * (W / 9.0)
    cubo("sube_%d" % i, (x, 0.62, z + 0.5), (0.030, 0.03, 1.0), PIS)
    BUSES.append((z, rnd.choice((-1, 1)), rnd.choice((1, 2, 2, 3))))

# --- paquetes de datos. El bucle cierra exacto: si van espaciados S y cada
# cuadro avanzan S/N, tras N cuadros la lamina es identica a si misma, asi
# que se puede repetir en horizontal sin que se note ni el corte ni el salto.
PAQUETES = []
for i, (z, sentido, cuantos) in enumerate(BUSES):
    S = W / cuantos
    for k in range(cuantos):
        o = cubo("paq_%d_%d" % (i, k), (0, 0.58, z), (0.22, 0.05, 0.048), PAQ)
        PAQUETES.append((o, z, sentido, S, k * S))

# --- chips: paquetes rectangulares con sus patas
for i in range(5):
    cx = -W/2 + 0.9 + i * (W - 1.8) / 4.0 + rnd.uniform(-0.25, 0.25)
    cz = rnd.uniform(-H/2 + 0.8, H/2 - 0.8)
    aw, ah = rnd.uniform(0.9, 1.7), rnd.uniform(0.6, 1.0)
    cubo("chip_%d" % i, (cx, 0.45, cz), (aw, 0.30, ah), CHIP, bisel=0.03)
    n = int(aw / 0.16)
    for k in range(n):
        px = cx - aw/2 + 0.08 + k * (aw - 0.16) / max(1, n - 1)
        for s in (-1, 1):
            cubo("pata_%d_%d_%d" % (i, k, s), (px, 0.50, cz + s * (ah/2 + 0.06)),
                 (0.055, 0.14, 0.10), PATA)
    cubo("muesca_%d" % i, (cx - aw/2 + 0.12, 0.30, cz), (0.10, 0.06, 0.10), PATA)

# --- condensadores: cilindros de pie, lo mas reconocible de una placa
for i in range(7):
    cx = -W/2 + 0.5 + rnd.uniform(0, W - 1.0)
    cz = rnd.uniform(-H/2 + 0.6, H/2 - 0.6)
    r, h = rnd.uniform(0.14, 0.24), rnd.uniform(0.5, 0.9)
    cil("cond_%d" % i, (cx, 0.35, cz), r, h, COND, rot=(math.radians(90), 0, 0))
    cil("tapa_%d" % i, (cx, 0.20, cz), r * 0.92, 0.04, PATA, rot=(math.radians(90), 0, 0))

# --- leds de actividad: los unicos puntos que brillan de verdad. Cada uno
# con su material para poder darle su propio ritmo; los periodos dividen a N
# para que todos vuelvan a la vez al empezar el bucle.
LEDS = []
for i in range(11):
    cx = -W/2 + rnd.uniform(0.3, W - 0.3)
    cz = rnd.uniform(-H/2 + 0.3, H/2 - 0.3)
    m = mat("led_%d" % i, (0.05, 0.14, 0.16), (0.21, 0.85, 1.00), 0.55, rug=0.4)
    cubo("led_%d" % i, (cx, 0.42, cz), (0.075, 0.06, 0.045), m)
    LEDS.append((m, rnd.choice((2, 4, 8, 16)), rnd.randrange(16)))

# ------------------------------------------------------------------ el bucle
for f in range(1, N + 1):
    t = (f - 1) / float(N)
    for o, z, sentido, S, x0 in PAQUETES:
        x = -W / 2 + math.fmod(x0 + sentido * S * t + W * 4, W)
        kf(o, f, loc=(x, 0.58, z))
    for m, periodo, fase in LEDS:
        # cuadrada con un poco de rampa: un led de actividad no se desvanece
        fase_local = ((f - 1) + fase) % periodo
        v = 0.72 if fase_local < periodo * 0.45 else 0.08
        brillo(m, f, v)

# ------------------------------------------------------------------- camara
cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = W
cam = bpy.data.objects.new("cam", cam_d)
cam.location = (0, -8, 0); cam.rotation_euler = (math.radians(90), 0, 0)
bpy.context.collection.objects.link(cam)

def luz(n, loc, e, c, t):
    d = bpy.data.lights.new(n, 'AREA'); d.energy = e; d.color = c; d.size = t
    o = bpy.data.objects.new(n, d); o.location = loc
    from mathutils import Vector
    o.rotation_euler = (Vector((0,0,0)) - Vector(loc)).to_track_quat('-Z','Y').to_euler()
    bpy.context.collection.objects.link(o)
# Centradas a proposito: si la luz viene de un lado, la lamina queda mas
# clara por ese lado y al repetirla en horizontal se ve la costura. Con el
# degradado simetrico, en la union se junta borde oscuro con borde oscuro.
luz("clave",   (0, -7,  3), 300, (0.72, 0.86, 1.0), 9.0)
luz("relleno", (0, -6, -3), 110, (0.35, 0.62, 0.85), 10.0)

sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = ANCHO * SS, int(ANCHO * SS * H / W)
sc.render.film_transparent = False
sc.render.image_settings.file_format = 'PNG'
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new("m"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.020, 0.022, 1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "fondo.blend"))
print("BLEND fondo guardado")

sc.frame_start, sc.frame_end = 1, N

if DO_RENDER:
    import numpy as np
    d = os.path.join(OUT, "hojas_fondo"); os.makedirs(d, exist_ok=True)
    dest = os.path.join(OUT, "cuadros_fondo") + os.sep
    os.makedirs(dest, exist_ok=True)
    sc.render.filepath = dest
    bpy.ops.render.render(animation=True)

    def cargar(r):
        im = bpy.data.images.load(r); w, h = im.size
        a = np.empty(w * h * 4, dtype=np.float32); im.pixels.foreach_get(a)
        bpy.data.images.remove(im); return a.reshape(h, w, 4)[::-1].copy()

    def reducir(a, s):
        h, w, _ = a.shape
        return a[:h // s * s, :w // s * s].reshape(h // s, s, w // s, s, 4).mean(axis=(1, 3))

    cuadros = [reducir(cargar(os.path.join(dest, "%04d.png" % i)), SS) for i in range(1, N + 1)]
    ch, cw, _ = cuadros[0].shape
    filas = [np.concatenate(cuadros[r:r + COLS], axis=1) for r in range(0, N, COLS)]
    hoja = np.concatenate(filas, axis=0)
    im = bpy.data.images.new("hoja", width=hoja.shape[1], height=hoja.shape[0], alpha=True)
    im.pixels.foreach_set(hoja[::-1].reshape(-1).astype(np.float32))
    ruta = os.path.join(d, "fondo_placa.png")
    im.filepath_raw = ruta; im.file_format = 'PNG'; im.save()
    print("FONDO %d cuadros de %dx%d -> hoja %dx%d" % (N, cw, ch, hoja.shape[1], hoja.shape[0]))

    ext = '[ext_resource type="Texture2D" path="res://arte/fondo/fondo_placa.png" id="1_f"]'
    sub_, refs = [], []
    for i in range(N):
        sid = "f%02d" % i
        sub_.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1_f")\n'
                    'region = Rect2(%d, %d, %d, %d)' % (sid, (i % COLS) * cw, (i // COLS) * ch, cw, ch))
        refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n\n'
            '[resource]\nanimations = [{\n"frames": [%s],\n"loop": true,\n"name": &"placa",\n"speed": %.1f\n}]\n'
            % (len(sub_) + 2, ext, "\n\n".join(sub_), ", ".join(refs), float(FPS)))
    open(os.path.join(d, "fondo_spriteframes.tres"), "w", encoding="utf-8").write(tres)
    print("TRES fondo con %d cuadros a %d fps" % (N, FPS))
print("LISTO")
