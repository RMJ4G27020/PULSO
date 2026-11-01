# -*- coding: utf-8 -*-
"""
Estela electrica de PULSO - celda de suelo cargada
Blender 5.x  |  blender -b --factory-startup --python build_estela.py -- --render
Los 4 estados del ciclo de vida que describe el GDD:
  encendido -> activa (3 s letal) -> aviso (0.4 s) -> apagado
"""
import bpy, math, os, sys, random

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
VARIANTE = ARGS[ARGS.index("--color") + 1] if "--color" in ARGS else "cian"
OUT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, OUT)
import rayos          # generador segun el modelo de ruptura dielectrica

PALETAS = {
    "cian":  {"nucleo": (0.62, 0.99, 1.00), "arco": (0.21, 0.85, 1.00), "base": (0.06, 0.45, 0.72)},
    "ambar": {"nucleo": (1.00, 0.93, 0.62), "arco": (1.00, 0.66, 0.16), "base": (0.60, 0.26, 0.03)},
    "violeta": {"nucleo": (0.90, 0.80, 1.00), "arco": (0.66, 0.48, 1.00), "base": (0.30, 0.12, 0.60)},
    "plata": {"nucleo": (0.97, 0.99, 1.00), "arco": (0.80, 0.88, 0.95), "base": (0.34, 0.42, 0.52)},
}
P = PALETAS[VARIANTE]

EMIS = 0.42       # por encima de 1.0 el color se recorta a blanco y se pierde el tono
RES = 64          # la celda mide 16 px; el sprite es 64 para que quepa el resplandor
SS = 4            # supermuestreo
ORTHO = 1.0       # 1 unidad = 32 px  ->  celda de 0.5 u = 16 px
CELDA = 0.5
SUELO = -0.30     # altura de la superficie cargada dentro del cuadro

# nombre, cuadros, fps, bucle
ANIMS = [
    ("encendido",  4, 24, False),   # el pie acaba de pasar
    ("activa",     8, 12, True),    # mata: 3 s en bucle
    ("aviso",      6, 15, True),    # 0.4 s parpadeando antes de apagarse
    ("apagado",    4, 20, False),
]

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights, bpy.data.cameras):
        for b in list(c): c.remove(b)

def mat(nombre, color, fuerza):
    m = bpy.data.materials.new(nombre); m.use_nodes = True
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (*color, 1.0)
    n.inputs["Emission Color"].default_value = (*color, 1.0)
    n.inputs["Emission Strength"].default_value = fuerza * EMIS
    n.inputs["Roughness"].default_value = 0.4
    return m

limpiar()
M_BARRA = mat("estela_barra", P["nucleo"], 1.05)
# el canal va casi al blanco a proposito: un canal ionizado esta al blanco y
# el color vive en el halo. Es lo que separa un rayo de una rama de arbol.
M_ARCO  = mat("estela_arco",  P["nucleo"], 1.45)
M_BASE  = mat("estela_base",  P["base"],   0.35)
# el halo es geometria, no bloom: el bloom de EEVEE no se guarda en PNG con alfa
M_HALO  = mat("estela_halo",  P["arco"],   0.55)

# --- superficie cargada: nucleo brillante sobre una base mas apagada
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, SUELO - 0.055))
BASE = bpy.context.object; BASE.name = "base"; BASE.scale = (CELDA, 0.10, 0.075)
BASE.data.materials.append(M_BASE)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, SUELO))
BARRA = bpy.context.object; BARRA.name = "barra"; BARRA.scale = (CELDA, 0.08, 0.055)
BARRA.data.materials.append(M_BARRA)

# --- arcos: 8 rayos distintos; se encienden por turnos = chisporroteo.
# La forma la da rayos.py: pasos dentro de +-30 grados, ramas a 20-45 grados
# y canal que se afila hacia la punta, como en un lider escalonado real.
def arco(nombre, x0, alto, semilla):
    rnd = random.Random(int(semilla * 977) & 0xffff)
    ang = math.radians(90) + rnd.gauss(0.0, 0.16)
    ramas = rayos.rayo(x0, SUELO, ang, alto, rnd,
                       pasos=7, max_nivel=1, p_rama=0.30, sigma=32.0,
                       tension=0.30)
    # a 16 px de celda el nucleo tiene que ganarle al halo o se lee como humo
    n, h = rayos.nucleo_y_halo(bpy, nombre, ramas, M_ARCO, M_HALO, 0.014, halo=3.0)
    return (n, h)

ARCOS = []
for i in range(8):
    x0 = -0.21 + 0.060 * i
    alto = (0.20, 0.30, 0.15, 0.35, 0.23, 0.17, 0.32, 0.26)[i]
    ARCOS.append(arco("arco_%d" % i, x0, alto, i * 1.7 + 0.3))

# ------------------------------------------------------------ camara y ajustes
cam_d = bpy.data.cameras.new("camara"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = ORTHO
cam = bpy.data.objects.new("camara", cam_d)
cam.location = (0, -6, 0); cam.rotation_euler = (math.radians(90), 0, 0)
bpy.context.collection.objects.link(cam)

sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = sc.render.resolution_y = RES * SS
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
try: sc.eevee.taa_render_samples = 64
except Exception: pass
sc.view_settings.view_transform = 'Standard'
try: sc.view_settings.look = 'None'
except Exception: pass
w = bpy.data.worlds.new("mundo"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[1].default_value = 0.0

# ------------------------------------------------------------------- animacion
def kf(o, f, loc=None, scl=None):
    if loc is not None: o.location = loc; o.keyframe_insert('location', frame=f)
    if scl is not None: o.scale = scl; o.keyframe_insert('scale', frame=f)

def ver(o, f, v):
    o.hide_render = not v; o.hide_viewport = not v
    o.keyframe_insert('hide_render', frame=f); o.keyframe_insert('hide_viewport', frame=f)

def brillo(m, f, v):
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Emission Strength"].default_value = v * EMIS
    n.inputs["Emission Strength"].keyframe_insert('default_value', frame=f)

def arcos_en(f, indices, alto=1.0):
    # cada arco son dos objetos (nucleo y halo) y hay que ocultar los dos:
    # ocultar solo el padre no oculta al hijo en el render
    for i, par in enumerate(ARCOS):
        on = i in indices
        for a in par:
            ver(a, f, on)
            if on: kf(a, f, scl=(1.0, 1.0, alto))

RANGOS = {}; cursor = 1
for nombre, n, fps, bucle in ANIMS:
    RANGOS[nombre] = (cursor, cursor + n - 1); cursor += n + 3
def R(n): return RANGOS[n][0]

# encendido: fogonazo ancho que se asienta
f = R("encendido")
for i, (eb, ancho, alt, arcs) in enumerate([
        (3.6, 1.55, 1.35, (0, 2, 4, 6, 8, 10, 11)),
        (2.4, 1.20, 1.15, (1, 3, 5, 7, 9)),
        (1.5, 1.02, 0.95, (0, 4, 6, 10)),
        (1.05, 1.00, 0.85, (2, 5, 8))]):
    brillo(M_BARRA, f + i, eb); brillo(M_ARCO, f + i, min(eb * 0.55, 1.0))
    kf(BARRA, f + i, scl=(CELDA, 0.08, 0.055 * ancho))
    kf(BASE,  f + i, scl=(CELDA, 0.10, 0.075 * ancho))
    arcos_en(f + i, arcs, alt)

# activa: brillo estable y arcos rotando -> chisporroteo continuo
f = R("activa")
for i in range(8):
    pulso = 1.05 + 0.16 * math.sin(i * math.pi / 4)
    brillo(M_BARRA, f + i, pulso); brillo(M_ARCO, f + i, 0.85)
    kf(BARRA, f + i, scl=(CELDA, 0.08, 0.055 * (0.94 + 0.10 * math.sin(i * math.pi / 4))))
    kf(BASE,  f + i, scl=(CELDA, 0.10, 0.075))
    arcos_en(f + i, (i % 8, (i + 4) % 8), 0.85 + 0.30 * ((i % 3) / 2.0))

# aviso: parpadeo claro, ultima llamada antes de apagarse
f = R("aviso")
for i in range(6):
    alto = (i % 2 == 0)
    brillo(M_BARRA, f + i, 1.45 if alto else 0.30)
    brillo(M_ARCO,  f + i, 0.95 if alto else 0.22)
    kf(BARRA, f + i, scl=(CELDA, 0.08, 0.055 * (1.0 if alto else 0.72)))
    kf(BASE,  f + i, scl=(CELDA, 0.10, 0.075))
    arcos_en(f + i, ((1, 5, 9) if alto else ()), 0.55)

# apagado: se desvanece y desaparece
f = R("apagado")
for i, (eb, alt) in enumerate([(0.85, 0.45), (0.45, 0.25), (0.18, 0.0), (0.0, 0.0)]):
    brillo(M_BARRA, f + i, eb); brillo(M_ARCO, f + i, eb)
    kf(BARRA, f + i, scl=(CELDA, 0.08, 0.055 * max(alt, 0.12)))
    kf(BASE,  f + i, scl=(CELDA, 0.10, 0.075 * max(alt, 0.35)))
    arcos_en(f + i, ((3, 8) if i == 0 else ()), 0.4)

for nombre, (a, b) in RANGOS.items(): sc.timeline_markers.new(nombre, frame=a)
sc.frame_start, sc.frame_end = 1, cursor
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "estela.blend"))
print("BLEND estela guardado")

# ------------------------------------------------------- render + hojas + .tres
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
        img = bpy.data.images.new("hoja", w, h, alpha=True)
        img.colorspace_settings.name = 'Non-Color'; img.alpha_mode = 'STRAIGHT'
        img.pixels.foreach_set(arr[::-1].reshape(-1).astype(np.float32))
        img.filepath_raw = ruta; img.file_format = 'PNG'; img.save()
        bpy.data.images.remove(img)

    dir_c = os.path.join(OUT, "cuadros_estela_%s" % VARIANTE)
    dir_h = os.path.join(OUT, "hojas_estela_%s" % VARIANTE)
    os.makedirs(dir_h, exist_ok=True)

    hojas = []
    for nombre, n, fps, bucle in ANIMS:
        a, b = RANGOS[nombre]
        destino = os.path.join(dir_c, nombre) + os.sep; os.makedirs(destino, exist_ok=True)
        sc.frame_start, sc.frame_end = a, b
        sc.render.filepath = destino
        bpy.ops.render.render(animation=True)
        cuadros = [reducir(cargar(os.path.join(destino, "%04d.png" % i)), SS) for i in range(a, b + 1)]
        hoja = np.concatenate(cuadros, axis=1)
        ruta = os.path.join(dir_h, "estela_%s.png" % nombre)
        guardar(hoja, ruta); hojas.append((nombre, n, fps, bucle))
        print("HOJA estela_%-10s %d cuadros -> %dx%d" % (nombre, n, hoja.shape[1], hoja.shape[0]))

    ext, sub, anim = [], [], []
    for idx, (nombre, n, fps, bucle) in enumerate(hojas, start=1):
        eid = "%d_%s" % (idx, nombre)
        # la cian es la de TSL-04; las demas, cada una en su carpeta
        carpeta = "res://arte/estela/" if VARIANTE == "cian" else "res://arte/estela/%s/" % VARIANTE
        ext.append('[ext_resource type="Texture2D" path="%sestela_%s.png" id="%s"]' % (carpeta, nombre, eid))
        refs = []
        for i in range(n):
            sid = "%s_%02d" % (nombre, i)
            sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, 0, %d, %d)'
                       % (sid, eid, i * RES, RES, RES))
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                    % (", ".join(refs), "true" if bucle else "false", nombre, float(fps)))
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n\n[resource]\nanimations = [%s]\n'
            % (len(ext) + len(sub) + 1, "\n".join(ext), "\n\n".join(sub), ", ".join(anim)))
    open(os.path.join(dir_h, "estela_spriteframes.tres"), "w", encoding="utf-8").write(tres)
    print("TRES estela con %d estados" % len(hojas))
print("LISTO")
