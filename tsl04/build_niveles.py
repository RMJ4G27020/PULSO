# -*- coding: utf-8 -*-
"""
Los tres niveles de PULSO construidos en 3D
Blender 5.x | blender -b --factory-startup --python build_niveles.py -- --render
La geometria sale de niveles.json, extraido de los planos del cuaderno de niveles.
"""
import bpy, json, math, os, sys
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--render" in ARGS
SOLO = ARGS[ARGS.index("--solo") + 1] if "--solo" in ARGS else None
OUT = os.path.dirname(os.path.abspath(__file__))
NIVELES = json.load(open(os.path.join(OUT, "niveles.json")))

U = 0.5          # 1 celda = 0.5 unidades  (TSL-04 mide 1.0 = 2 celdas, como el GDD)
PX = 16          # pixeles por celda al renderizar
FONDO_Y = 2.2    # profundidad del telon de fondo

PALETAS = {
    "cian":  {"bloque": (0.16, 0.20, 0.24), "borde": (0.21, 0.85, 1.00), "fondo": (0.045, 0.06, 0.07)},
    "rojo":  {"bloque": (0.24, 0.16, 0.14), "borde": (1.00, 0.36, 0.28), "fondo": (0.075, 0.045, 0.04)},
    "verde": {"bloque": (0.18, 0.22, 0.14), "borde": (0.78, 0.95, 0.31), "fondo": (0.05, 0.065, 0.038)},
}

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights, bpy.data.cameras, bpy.data.objects):
        for b in list(c):
            try: c.remove(b)
            except Exception: pass

def mat(nombre, base, emis=(0, 0, 0), fuerza=0.0, rug=0.45, metal=0.0):
    m = bpy.data.materials.new(nombre); m.use_nodes = True
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (*base, 1)
    n.inputs["Roughness"].default_value = rug
    n.inputs["Metallic"].default_value = metal
    n.inputs["Emission Color"].default_value = (*emis, 1)
    n.inputs["Emission Strength"].default_value = fuerza
    return m

def caja(nombre, cx, cy, cz, sx, sy, sz, material, bisel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cz))
    o = bpy.context.object; o.name = nombre; o.scale = (sx, sy, sz)
    if material: o.data.materials.append(material)
    if bisel:
        bpy.ops.object.modifier_add(type='BEVEL')
        o.modifiers[-1].width = bisel; o.modifiers[-1].segments = 2
    return o

def construir(nv):
    """coordenadas SVG -> mundo:  X = x/10*U ,  Z = (H - y)/10*U"""
    limpiar()
    P = PALETAS[nv["paleta"]]
    H = nv["H"]
    fx = lambda x: (x / 10.0) * U
    fz = lambda y: ((H - y) / 10.0) * U
    ancho_u = fx(nv["W"]); alto_u = fz(0)

    M_BLOQUE = mat("bloque", P["bloque"], rug=0.62)
    M_BORDE  = mat("borde",  P["borde"], P["borde"], 1.1, 0.3)
    M_FONDO  = mat("fondo",  P["fondo"], rug=0.9)
    M_TERM   = mat("terminal", (0.10, 0.14, 0.10), (0.78, 0.95, 0.31), 2.2, 0.25)
    M_PUERTA = mat("puerta", (0.25, 0.16, 0.05), (1.00, 0.72, 0.24), 1.6, 0.3)
    M_SALIDA = mat("salida", (0.10, 0.16, 0.08), (0.78, 0.95, 0.31), 2.6, 0.2)
    M_FRAG   = mat("fragmento", (0.14, 0.20, 0.08), (0.78, 0.95, 0.31), 2.4, 0.15)
    M_LASER  = mat("laser", (0.30, 0.05, 0.04), (1.0, 0.22, 0.16), 2.8, 0.2)
    M_MOVIL  = mat("movil", (0.55, 0.60, 0.52), (0.85, 0.92, 0.80), 0.6, 0.3, metal=0.4)
    M_ESTELA = mat("estela", (0.21, 0.85, 1.00), (0.21, 0.85, 1.00), 1.9, 0.2)
    M_ORBE   = mat("orbe", (0.13, 0.72, 1.00), (0.21, 0.88, 1.00), 0.6, 0.22)
    M_OJO    = mat("ojo", (0.02, 0.09, 0.12), rug=0.1)

    # telon de fondo + cajas de profundidad (el 2.5D vive aqui)
    caja("telon", ancho_u / 2, FONDO_Y + 1.6, alto_u / 2, ancho_u * 1.2, 0.4, alto_u * 1.2, M_FONDO, bisel=0)
    for i in range(26):
        a = (i * 7919) % 1000 / 1000.0; b = (i * 104729) % 1000 / 1000.0
        caja("fondo_%02d" % i, a * ancho_u, FONDO_Y + 0.5 + (i % 3) * 0.35, b * alto_u,
             1.2 + 2.4 * b, 0.5, 1.0 + 3.0 * a, M_FONDO, bisel=0.05)

    # bloques solidos, con una franja luminosa en la cara superior
    for i, r in enumerate(nv["bloques"]):
        x0, x1 = fx(r["x"]), fx(r["x"] + r["w"])
        z1, z0 = fz(r["y"]), fz(r["y"] + r["h"])
        caja("bloque_%02d" % i, (x0 + x1) / 2, 0, (z0 + z1) / 2, x1 - x0, 1.5, z1 - z0, M_BLOQUE)
        if (x1 - x0) > 0.6:      # solo las superficies pisables llevan borde
            caja("borde_%02d" % i, (x0 + x1) / 2, -0.76, z1 - 0.035, x1 - x0, 0.06, 0.07, M_BORDE, bisel=0)

    # props
    for r in nv["puertas"]:
        caja("puerta", fx(r["x"] + r["w"] / 2), -0.2, fz(r["y"] + r["h"] / 2),
             max(fx(r["w"]), 0.22), 0.5, max(fz(0) - fz(r["h"]), 0.4), M_PUERTA, bisel=0.02)
    for r in nv["laseres"]:
        caja("laser", fx(r["x"] + r["w"] / 2), -0.3, fz(r["y"] + r["h"] / 2),
             max(fx(r["w"]), 0.12), 0.12, max(fz(0) - fz(r["h"]), 0.12), M_LASER, bisel=0)
    for r in nv["moviles"]:
        caja("movil", fx(r["x"] + r["w"] / 2), -0.4, fz(r["y"] + r["h"] / 2),
             fx(r["w"]), 0.7, 0.22, M_MOVIL, bisel=0.03)
    for (x, y) in nv["fragmentos"]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.28, location=(fx(x), -0.6, fz(y)))
        o = bpy.context.object; o.name = "fragmento"; o.data.materials.append(M_FRAG)

    for (x, y, letra) in nv["marcadores"]:
        X, Z = fx(x), fz(y)
        if letra == "T":
            caja("terminal_cuerpo", X, -0.1, Z, 0.55, 0.6, 1.5, M_BLOQUE, bisel=0.04)
            caja("terminal_panel", X, -0.45, Z + 0.28, 0.42, 0.1, 0.55, M_TERM, bisel=0.02)
        elif letra == "E":
            bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.11,
                                             location=(X, -0.3, Z), rotation=(math.radians(90), 0, 0))
            bpy.context.object.name = "salida"; bpy.context.object.data.materials.append(M_SALIDA)
        elif letra == "S":
            bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.5, location=(X, -0.9, Z))
            b = bpy.context.object; b.name = "TSL04"; b.data.materials.append(M_ORBE)
            bpy.ops.object.shade_smooth()
            for sx in (-1, 1):
                bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=0.15,
                                                     location=(X + 0.185 * sx, -1.28, Z + 0.04))
                e = bpy.context.object; e.scale = (1, 0.5, 1.1); e.data.materials.append(M_OJO)
                bpy.ops.object.shade_smooth()

    # la estela recorriendo la ruta optima
    ruta = max(nv["ruta"], key=len)
    cu = bpy.data.curves.new("estela", 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = 0.13; cu.resolution_u = 4; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(ruta) - 1)
    for i, (x, y) in enumerate(ruta):
        sp.points[i].co = (fx(x), -1.05, fz(y), 1.0)
    ob = bpy.data.objects.new("estela", cu); ob.data.materials.append(M_ESTELA)
    bpy.context.collection.objects.link(ob)

    # luces: mismo esquema de tres puntos que el personaje, a escala del nivel
    def luz(nombre, loc, energia, color, tam):
        d = bpy.data.lights.new(nombre, 'AREA'); d.energy = energia; d.color = color; d.size = tam
        o = bpy.data.objects.new(nombre, d); o.location = loc
        o.rotation_euler = (Vector((ancho_u / 2, 0, alto_u / 2)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.collection.objects.link(o)
    d = max(ancho_u, alto_u)
    luz("clave",   (-d * 0.35, -d * 0.85, alto_u + d * 0.35), 26 * d * d, (1.0, 0.97, 0.92), d * 0.7)
    luz("relleno", (ancho_u + d * 0.4, -d * 0.7, -d * 0.2),    9 * d * d, (0.62, 0.82, 1.0), d * 0.7)
    luz("borde",   (ancho_u * 0.6, d * 0.8, alto_u + d * 0.3), 30 * d * d, P["borde"], d * 0.5)

    cam_d = bpy.data.cameras.new("camara"); cam_d.type = 'ORTHO'
    cam_d.ortho_scale = ancho_u
    cam = bpy.data.objects.new("camara", cam_d)
    cam.location = (ancho_u / 2, -d * 3.0, alto_u / 2)
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.collection.objects.link(cam)

    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = int(nv["W"] / 10 * PX)
    sc.render.resolution_y = int(nv["H"] / 10 * PX)
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = 'PNG'
    try: sc.eevee.taa_render_samples = 96
    except Exception: pass
    sc.view_settings.view_transform = 'Standard'
    try: sc.view_settings.look = 'None'
    except Exception: pass
    w = bpy.data.worlds.new("mundo"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*P["fondo"], 1); bg.inputs[1].default_value = 1.0
    return sc

for nv in NIVELES:
    if SOLO and SOLO not in nv["nombre"]: continue
    sc = construir(nv)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "nivel_%s.blend" % nv["nombre"]))
    print("BLEND %s  %d bloques  %dx%d px" % (nv["nombre"], len(nv["bloques"]),
                                              sc.render.resolution_x, sc.render.resolution_y))
    if DO_RENDER:
        sc.render.filepath = os.path.join(OUT, "render_%s.png" % nv["nombre"])
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % nv["nombre"])
print("LISTO")
