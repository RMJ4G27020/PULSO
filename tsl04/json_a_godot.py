# -*- coding: utf-8 -*-
"""niveles.json  ->  escenas .tscn de Godot 4.  python3 json_a_godot.py"""
import json, os

AQUI = os.path.dirname(os.path.abspath(__file__))
PROY = os.path.join(os.path.dirname(AQUI), "pulso-godot")
K = 1.6                      # 10 unidades de plano = 1 celda = 16 px
TITULOS = {"n03_ida_y_vuelta": ("Nivel 03 - Ida y vuelta", 31.0),
           "n15_corredor":     ("Nivel 15 - El corredor",  41.0),
           "n26_el_nudo":      ("Nivel 26 - El nudo",      56.0)}
# obstaculos por nivel, en coordenadas del plano (mismas que los diagramas).
# El nivel 03 no lleva ninguno: el GDD dice que su unico peligro es tu propia estela.
OBSTACULOS = {
 "n03_ida_y_vuelta": [],
 "n15_corredor": [
   ("dron", 430, 528, "recorrido = Vector2(320, 0)"),
   ("pinchos", 690, 372),
   ("pulsante", 380, 356, "desfase = 0.0"),
   ("pulsante", 470, 356, "desfase = 0.7"),
 ],
 "n26_el_nudo": [
   ("dron", 300, 686, "recorrido = Vector2(280, 0)"),
   ("zapador", 470, 250),
   ("pinchos", 350, 588),
   ("pulsante", 690, 306, "desfase = 0.0"),
   ("pulsante", 690, 434, "desfase = 0.9"),
 ],
}
COLOR = {"cian": "Color(0.16, 0.2, 0.24, 1)", "rojo": "Color(0.24, 0.16, 0.14, 1)",
         "verde": "Color(0.18, 0.22, 0.14, 1)"}
BORDE = {"cian": "Color(0.21, 0.85, 1, 1)", "rojo": "Color(1, 0.36, 0.28, 1)",
         "verde": "Color(0.78, 0.95, 0.31, 1)"}

def rect(r):
    return r["x"] * K, r["y"] * K, r["w"] * K, r["h"] * K

def poly(w, h):
    return "PackedVector2Array(0, 0, %g, 0, %g, %g, 0, %g)" % (w, w, h, h)

def escena(nv):
    nom = nv["nombre"]
    titulo, par = TITULOS[nom]
    ext, sub, nodos = [], [], []
    ext.append('[ext_resource type="Script" path="res://scripts/nivel.gd" id="1_nivel"]')
    ext.append('[ext_resource type="Script" path="res://scripts/rejilla_estela.gd" id="2_estela"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/Jugador.tscn" id="3_jugador"]')
    ext.append('[ext_resource type="Texture2D" path="res://arte/elementos/bloque_bloque.png" id="4_bloque"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/Portal.tscn" id="5_portal"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/Anclaje.tscn" id="6_anclaje"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/LaserEmisor.tscn" id="7_laser"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/DronPurga.tscn" id="8_dron"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/DronZapador.tscn" id="9_zap"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/Pinchos.tscn" id="10_pinchos"]')
    ext.append('[ext_resource type="PackedScene" path="res://escenas/obstaculos/BloquePulsante.tscn" id="11_bloque"]')

    formas = {}
    def forma_rect(w, h):
        clave = ("r", round(w, 2), round(h, 2))
        if clave not in formas:
            sid = "s%d" % len(formas)
            formas[clave] = sid
            sub.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)' % (sid, w, h))
        return formas[clave]
    def forma_circ(r):
        clave = ("c", round(r, 2))
        if clave not in formas:
            sid = "s%d" % len(formas)
            formas[clave] = sid
            sub.append('[sub_resource type="CircleShape2D" id="%s"]\nradius = %g' % (sid, r))
        return formas[clave]

    nodos.append('[node name="Nivel" type="Node2D"]\nscript = ExtResource("1_nivel")\n'
                 'titulo = "%s"\npar = %g' % (titulo, par))

    # geometria solida: pocas cajas grandes, no una por celda (plan del GDD)
    nodos.append('[node name="Geometria" type="StaticBody2D" parent="."]')
    for i, r in enumerate(nv["bloques"]):
        x, y, w, h = rect(r)
        sid = forma_rect(w, h)
        nodos.append('[node name="C%02d" type="CollisionShape2D" parent="Geometria"]\n'
                     'position = Vector2(%g, %g)\nshape = SubResource("%s")' % (i, x + w / 2, y + h / 2, sid))
        # bloque 3D repetido en rejilla: 2.5D real, no un poligono plano
        nodos.append('[node name="V%02d" type="Sprite2D" parent="Geometria"]\n'
                     'texture = ExtResource("4_bloque")\ncentered = false\n'
                     'position = Vector2(%g, %g)\nscale = Vector2(0.3333, 0.3333)\n'
                     'texture_repeat = 2\nregion_enabled = true\nregion_rect = Rect2(0, 0, %g, %g)'
                     % (i, x, y, w * 3.0, h * 3.0))

    nodos.append('[node name="Estela" type="Node2D" parent="." groups=["estela"]]\n'
                 'script = ExtResource("2_estela")')

    for r in nv["puertas"]:
        x, y, w, h = rect(r)
        w = max(w, 8.0); h = max(h, 12.0)
        sid = forma_rect(w, h)
        nodos.append('[node name="Puerta" type="StaticBody2D" parent="."]\nposition = Vector2(%g, %g)'
                     % (x + w / 2, y + h / 2))
        nodos.append('[node name="Col" type="CollisionShape2D" parent="Puerta"]\nshape = SubResource("%s")' % sid)
        nodos.append('[node name="Vis" type="Polygon2D" parent="Puerta"]\nposition = Vector2(%g, %g)\n'
                     'color = Color(1, 0.72, 0.24, 1)\npolygon = %s' % (-w / 2, -h / 2, poly(w, h)))

    nodos.append('[node name="Peligros" type="Node2D" parent="."]')
    for i, r in enumerate(nv["laseres"]):
        x, y, w, h = rect(r)
        celdas = max(int(round(h / 16.0)), 2)
        nodos.append('[node name="L%d" parent="Peligros" instance=ExtResource("7_laser")]\n'
                     'position = Vector2(%g, %g)\nlargo_celdas = %d\ndesfase = %.2f'
                     % (i, x + w / 2, y, celdas, i * 0.7))
    for i, o in enumerate(OBSTACULOS.get(nom, [])):
        clase, cx, cy = o[0], o[1] * K, o[2] * K
        extra = o[3] if len(o) > 3 else ""
        rec = {"dron": "8_dron", "zapador": "9_zap", "pinchos": "10_pinchos", "pulsante": "11_bloque"}[clase]
        nodos.append('[node name="%s%d" parent="Peligros" instance=ExtResource("%s")]\n'
                     'position = Vector2(%g, %g)%s' % (clase.capitalize(), i, rec, cx, cy,
                                                       ("\n" + extra) if extra else ""))

    for i, r in enumerate(nv["moviles"]):
        x, y, w, h = rect(r)
        h = max(h, 10.0)
        sid = forma_rect(w, h)
        nodos.append('[node name="Movil" type="AnimatableBody2D" parent="." groups=["sin_estela"]]\n'
                     'position = Vector2(%g, %g)' % (x + w / 2, y + h / 2))
        nodos.append('[node name="Col" type="CollisionShape2D" parent="Movil"]\nshape = SubResource("%s")' % sid)
        nodos.append('[node name="Vis" type="Polygon2D" parent="Movil"]\nposition = Vector2(%g, %g)\n'
                     'color = Color(0.85, 0.92, 0.8, 1)\npolygon = %s' % (-w / 2, -h / 2, poly(w, h)))

    if nv["fragmentos"]:
        nodos.append('[node name="Fragmentos" type="Node2D" parent="."]')
        sid = forma_circ(10.0)
        for i, (fx, fy) in enumerate(nv["fragmentos"]):
            nodos.append('[node name="F%d" type="Area2D" parent="Fragmentos"]\nposition = Vector2(%g, %g)'
                         % (i, fx * K, fy * K))
            nodos.append('[node name="Col" type="CollisionShape2D" parent="Fragmentos/F%d"]\nshape = SubResource("%s")' % (i, sid))
            nodos.append('[node name="Vis" type="Polygon2D" parent="Fragmentos/F%d"]\n'
                         'color = Color(0.78, 0.95, 0.31, 1)\n'
                         'polygon = PackedVector2Array(0, -11, 9, 0, 0, 11, -9, 0)' % i)

    for (mx, my, letra) in nv["marcadores"]:
        X, Y = mx * K, my * K
        if letra == "S":
            nodos.append('[node name="Aparicion" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (X, Y))
            nodos.append('[node name="Anclaje" parent="." instance=ExtResource("6_anclaje")]\n'
                         'position = Vector2(%g, %g)' % (X, Y + 14))
        elif letra == "T":
            sid = forma_rect(26.0, 44.0)
            nodos.append('[node name="Terminal" type="Area2D" parent="."]\nposition = Vector2(%g, %g)' % (X, Y))
            nodos.append('[node name="Col" type="CollisionShape2D" parent="Terminal"]\nshape = SubResource("%s")' % sid)
            nodos.append('[node name="Vis" type="Polygon2D" parent="Terminal"]\nposition = Vector2(-13, -22)\n'
                         'color = Color(0.78, 0.95, 0.31, 1)\npolygon = %s' % poly(26, 44))
        elif letra == "E":
            nodos.append('[node name="Salida" parent="." instance=ExtResource("5_portal")]\n'
                         'position = Vector2(%g, %g)' % (X, Y))

    nodos.append('[node name="Jugador" parent="." instance=ExtResource("3_jugador")]')
    nodos.append('[node name="HUD" type="CanvasLayer" parent="."]')
    nodos.append('[node name="Carga" type="ColorRect" parent="HUD"]\noffset_left = 8.0\noffset_top = 8.0\n'
                 'offset_right = 108.0\noffset_bottom = 16.0\ncolor = Color(0.21, 0.85, 1, 1)')
    nodos.append('[node name="Texto" type="Label" parent="HUD"]\noffset_left = 8.0\noffset_top = 20.0\n'
                 'offset_right = 620.0\noffset_bottom = 40.0')

    pasos = len(ext) + len(sub) + 1
    return "[gd_scene load_steps=%d format=3]\n\n%s\n\n%s\n\n%s\n" % (
        pasos, "\n".join(ext), "\n\n".join(sub), "\n\n".join(nodos))

os.makedirs(os.path.join(PROY, "escenas", "niveles"), exist_ok=True)
for nv in json.load(open(os.path.join(AQUI, "niveles.json"))):
    ruta = os.path.join(PROY, "escenas", "niveles", nv["nombre"] + ".tscn")
    open(ruta, "w", encoding="utf-8").write(escena(nv))
    print("%-20s %5.0f x %5.0f px" % (nv["nombre"], nv["W"] * K, nv["H"] * K))

jug = '''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/jugador.gd" id="1_jug"]
[ext_resource type="SpriteFrames" path="res://arte/tsl04/tsl04_spriteframes.tres" id="2_sf"]

[sub_resource type="CircleShape2D" id="c1"]
radius = 14.0

[node name="Jugador" type="CharacterBody2D" groups=["jugador"]]
script = ExtResource("1_jug")

[node name="Col" type="CollisionShape2D" parent="."]
shape = SubResource("c1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2_sf")
scale = Vector2(0.333333, 0.333333)
animation = &"reposo"
autoplay = "reposo"

[node name="Camara" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 8.0
'''
open(os.path.join(PROY, "escenas", "Jugador.tscn"), "w", encoding="utf-8").write(jug)
print("Jugador.tscn escrito")
