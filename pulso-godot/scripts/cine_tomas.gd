extends Control
## Cinematica de apertura de PULSO: las 8 vinetas del storyboard del GDD mas el
## rotulo de nivel. Se monta en Godot, no es video: pesa unos kilobytes y se
## puede saltar en cualquier cuadro, como pide el GDD.

signal termino

const SIGUIENTE := "res://escenas/niveles/n1_ida_y_vuelta.tscn"
const CIAN := Color(0.21, 0.85, 1.0)
const ROJO := Color(1.0, 0.20, 0.16)
const VOLT := Color(0.78, 0.95, 0.31)
const AMBAR := Color(1.0, 0.72, 0.24)
const METAL := Color(0.13, 0.15, 0.17)
const OSCURO := Color(0.035, 0.045, 0.05)

## nombre, duracion en segundos
const TOMAS := [
	["maquina", 4.0], ["celda", 3.0], ["exterior", 3.0], ["descarga", 2.0],
	["despierta", 4.5], ["error", 5.0], ["purga", 5.5], ["huida", 4.0], ["rotulo", 1.5],
]

var t := 0.0
var toma := 0
var t_toma := 0.0
var acabo := false

@onready var _tsl: AnimatedSprite2D = $Tsl
@onready var _dron: AnimatedSprite2D = $Dron

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tsl.visible = false
	_dron.visible = false

func _process(delta: float) -> void:
	if acabo:
		return
	t += delta
	t_toma += delta
	if t > 1.0 and (Input.is_action_just_pressed("ui_accept")
			or Input.is_action_just_pressed("pausa") or Input.is_action_just_pressed("saltar")):
		_terminar()
		return
	if t_toma >= float(TOMAS[toma][1]):
		t_toma = 0.0
		toma += 1
		if toma >= TOMAS.size():
			_terminar()
			return
	_colocar_actores()
	queue_redraw()

func _terminar() -> void:
	acabo = true
	termino.emit()
	if get_tree() != null and ResourceLoader.exists(SIGUIENTE):
		get_tree().change_scene_to_file(SIGUIENTE)

func _p() -> float:
	return clampf(t_toma / float(TOMAS[toma][1]), 0.0, 1.0)

func _nombre() -> String:
	return String(TOMAS[toma][0])

# ------------------------------------------------------------------- actores
func _colocar_actores() -> void:
	var v := size
	var n := _nombre()
	var p := _p()
	_tsl.visible = n in ["celda", "descarga", "despierta", "error", "purga", "huida"]
	_dron.visible = n == "purga" and p > 0.45
	match n:
		"celda":
			_tsl.position = Vector2(v.x * 0.52, v.y * 0.52)
			_tsl.scale = Vector2.ONE * (v.y / 360.0) * 0.42
			_tsl.modulate = Color(0.35, 0.38, 0.40)      # apagada, todavia no despierta
			_tsl.play("reposo")
		"descarga":
			_tsl.position = Vector2(v.x * 0.62, v.y * 0.50)
			_tsl.scale = Vector2.ONE * (v.y / 360.0) * 0.55
			_tsl.modulate = Color(0.35, 0.38, 0.40).lerp(Color.WHITE, p)
			_tsl.play("reposo")
		"despierta":
			_tsl.position = Vector2(v.x * 0.5, v.y * 0.5)
			_tsl.scale = Vector2.ONE * (v.y / 360.0) * (0.62 + 0.06 * sin(t * 3.0))
			_tsl.modulate = Color.WHITE
			if p < 0.55:
				_tsl.play("aparicion")
			else:
				_tsl.play("reposo")
		"error", "purga":
			_tsl.position = Vector2(v.x * (0.26 + 0.04 * sin(t * 2.0)), v.y * 0.55)
			_tsl.scale = Vector2.ONE * (v.y / 360.0) * 0.46
			_tsl.modulate = Color.WHITE
			_tsl.play("reposo")
		"huida":
			_tsl.position = Vector2(v.x * (0.18 + 0.5 * p), v.y * (0.62 - 0.10 * p))
			_tsl.scale = Vector2.ONE * (v.y / 360.0) * 0.5
			_tsl.modulate = Color.WHITE
			_tsl.play("correr")
	if _dron.visible:
		_dron.position = Vector2(v.x * (1.15 - 0.35 * (p - 0.45) / 0.55), v.y * 0.34)
		_dron.scale = Vector2.ONE * (v.y / 360.0) * 0.30
		_dron.play("alerta")

# ------------------------------------------------------------------- dibujo
func _draw() -> void:
	var v := size
	draw_rect(Rect2(Vector2.ZERO, v), OSCURO, true)
	var p := _p()
	match _nombre():
		"maquina": _maquina(v, p, 1.0 + 0.10 * p)
		"celda": _celda(v, p)
		"exterior": _exterior(v, p)
		"descarga": _descarga(v, p)
		"despierta": _maquina(v, p, 1.35)
		"error": _sala_terminal(v, p, ROJO, "ERROR 04")
		"purga": _sala_terminal(v, p, CIAN, "ORDEN DE PURGA")
		"huida": _ducto(v, p)
		"rotulo": _rotulo(v, p)
	_fundido(v)

func _fundido(v: Vector2) -> void:
	var a := 0.0
	if t_toma < 0.35:
		a = 1.0 - t_toma / 0.35
	var dur := float(TOMAS[toma][1])
	if t_toma > dur - 0.35:
		a = maxf(a, (t_toma - (dur - 0.35)) / 0.35)
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, a), true)

func _maquina(v: Vector2, p: float, zoom: float) -> void:
	## interior del sotano termico: bastidores, ductos y pilotos ambar
	var cx := v.x * 0.5
	for i in range(9):
		var w := v.x * 0.09 * zoom
		var h := v.y * (0.42 + 0.09 * ((i * 7) % 5)) * zoom
		var x := cx + (i - 4) * v.x * 0.115 * zoom - w * 0.5
		var y := v.y * 0.98 - h
		draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), METAL, true)
		draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.06, 0.08, 0.09), false, 1.0)
		for j in range(int(h / (v.y * 0.07))):
			var yy := y + v.y * 0.045 + j * v.y * 0.07
			var enc := ((i * 3 + j * 5) % 7) < 2
			draw_rect(Rect2(Vector2(x + w * 0.18, yy), Vector2(w * 0.64, v.y * 0.012)),
				AMBAR * Color(1, 1, 1, 0.85) if enc else Color(0.10, 0.11, 0.10), true)
	for i in range(6):                              # ductos del techo
		var y := v.y * (0.04 + i * 0.035)
		draw_line(Vector2(0, y), Vector2(v.x, y + v.y * 0.02 * sin(i * 1.3)),
			Color(0.10, 0.12, 0.13), 3.0 + i * 0.6)
	draw_rect(Rect2(Vector2(0, v.y * 0.9), Vector2(v.x, v.y * 0.1)), Color(0.05, 0.06, 0.06), true)

func _celda(v: Vector2, p: float) -> void:
	_maquina(v, p, 1.5)
	var anc := Vector2(v.x * 0.52, 0)
	var fin := Vector2(v.x * 0.52, v.y * 0.44)
	draw_line(anc, fin, Color(0.16, 0.18, 0.19), 6.0)
	draw_line(anc, fin, Color(0.09, 0.10, 0.11), 2.0)
	for i in range(3):
		draw_line(Vector2(v.x * (0.30 + i * 0.22), 0), Vector2(v.x * (0.26 + i * 0.24), v.y * 0.30),
			Color(0.13, 0.15, 0.16), 4.0)

func _exterior(v: Vector2, p: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.06, 0.07, 0.11), true)
	for i in range(7):                               # siluetas de edificios
		var w := v.x * (0.10 + 0.03 * (i % 3))
		var h := v.y * (0.24 + 0.13 * ((i * 5) % 4))
		draw_rect(Rect2(Vector2(v.x * 0.03 + i * v.x * 0.14, v.y - h), Vector2(w, h)),
			Color(0.045, 0.05, 0.07), true)
	var centro := v.x * 0.52
	draw_rect(Rect2(Vector2(centro - v.x * 0.13, v.y * 0.45), Vector2(v.x * 0.26, v.y * 0.55)),
		Color(0.07, 0.08, 0.10), true)
	draw_line(Vector2(centro, v.y * 0.45), Vector2(centro, v.y * 0.30), Color(0.14, 0.15, 0.16), 2.0)
	if p > 0.45:
		var f := clampf((p - 0.45) / 0.18, 0.0, 1.0)
		var pts := PackedVector2Array()
		var x := centro
		for i in range(9):
			var yy := v.y * 0.30 * (1.0 - float(i) / 8.0)
			pts.append(Vector2(x + sin(i * 2.3) * v.x * 0.035, yy))
		draw_polyline(pts, Color(1, 1, 0.75, 1.0 - f * 0.6), 3.0)
		if p < 0.55:
			draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, (1.0 - f) * 0.55), true)

func _descarga(v: Vector2, p: float) -> void:
	_maquina(v, p, 1.6)
	var y := v.y * 0.34
	draw_line(Vector2(0, y), Vector2(v.x * 0.62, v.y * 0.50), Color(0.16, 0.18, 0.19), 7.0)
	var q := clampf(p * 1.4, 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in range(10):
		var tt := (float(i) / 9.0) * q
		var b := Vector2(0, y).lerp(Vector2(v.x * 0.62, v.y * 0.50), tt)
		pts.append(b + Vector2(0, sin(i * 2.7 + t * 30.0) * v.y * 0.012))
	if pts.size() > 1:
		draw_polyline(pts, Color(0.8, 0.95, 1.0), 3.0)
	if p > 0.72:
		draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, (p - 0.72) / 0.28), true)

func _sala_terminal(v: Vector2, p: float, col: Color, texto: String) -> void:
	_maquina(v, p, 1.25)
	var r := Rect2(Vector2(v.x * 0.58, v.y * 0.30), Vector2(v.x * 0.30, v.y * 0.30))
	draw_rect(r, Color(0.08, 0.09, 0.10), true)
	draw_rect(r, Color(0.16, 0.18, 0.19), false, 2.0)
	var pant := Rect2(r.position + r.size * 0.10, r.size * 0.80)
	var parp := 0.65 + 0.35 * absf(sin(t * 6.0))
	draw_rect(pant, Color(col.r, col.g, col.b, 0.85 * parp), true)
	var f := ThemeDB.fallback_font
	var tam := int(v.y * 0.055)
	var an := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(f, pant.position + Vector2((pant.size.x - an) * 0.5, pant.size.y * 0.58),
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.05, 0.06, 0.06))
	draw_line(Vector2(v.x * 0.28, v.y * 0.30), Vector2(v.x * 0.58, v.y * 0.38),
		Color(0.15, 0.17, 0.18), 4.0)

func _ducto(v: Vector2, p: float) -> void:
	draw_rect(Rect2(Vector2(0, v.y * 0.22), Vector2(v.x, v.y * 0.56)), Color(0.075, 0.085, 0.095), true)
	for i in range(14):                              # nervios del ducto
		var x := fposmod(i * v.x * 0.085 - p * v.x * 1.2, v.x * 1.2) - v.x * 0.1
		draw_rect(Rect2(Vector2(x, v.y * 0.22), Vector2(v.x * 0.012, v.y * 0.56)),
			Color(0.11, 0.13, 0.14), true)
	for i in range(10):                              # lineas de velocidad
		var yy := v.y * (0.26 + 0.05 * i)
		var x0 := fposmod(i * 130.0 - p * v.x * 2.4, v.x * 1.4) - v.x * 0.2
		draw_line(Vector2(x0, yy), Vector2(x0 + v.x * 0.14, yy), Color(0.35, 0.75, 0.95, 0.30), 1.5)
	# reloj de carga: aparece por primera vez
	if p > 0.35:
		var a := clampf((p - 0.35) / 0.25, 0.0, 1.0)
		var b := Rect2(Vector2(v.x * 0.06, v.y * 0.08), Vector2(v.x * 0.24, v.y * 0.035))
		draw_rect(b, Color(0.08, 0.10, 0.10, a), true)
		draw_rect(Rect2(b.position, Vector2(b.size.x * (1.0 - p * 0.35), b.size.y)),
			Color(CIAN.r, CIAN.g, CIAN.b, a), true)
		draw_rect(b, Color(0.3, 0.45, 0.4, a), false, 1.0)

func _rotulo(v: Vector2, p: float) -> void:
	var f := ThemeDB.fallback_font
	var tam := int(v.y * 0.13)
	var s := "NIVEL 01"
	var an := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var pos := Vector2(v.x * 0.5 - an * 0.5, v.y * 0.55)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 8,
		Color(VOLT.r, VOLT.g, VOLT.b, 0.25))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, VOLT)
