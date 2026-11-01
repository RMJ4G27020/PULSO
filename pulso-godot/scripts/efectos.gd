extends CanvasLayer
## Efectos de pantalla, en un solo sitio. Autoload: se llama desde cualquier escena.
## Cifras del GDD: congelacion 0.08 s, destello 1 cuadro, sacudida 3 px,
## 24 chispas como maximo, aberracion que se disuelve en 0.2 s.

const CONGELACION := 0.08
const SACUDIDA := 3.0
const ABERRACION := 0.2

var _destello: ColorRect
var _filtro: ColorRect
var _mat: ShaderMaterial
var _chispas: GPUParticles2D
var _t_sacudida := 0.0
var _fuerza_sacudida := 0.0
var _t_aberracion := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS       # sigue vivo durante la congelacion

	_filtro = ColorRect.new()
	_filtro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/aberracion.gdshader")
	_mat.set_shader_parameter("fuerza", 0.0)
	_mat.set_shader_parameter("vineta", 0.0)
	_filtro.material = _mat
	_filtro.visible = false
	add_child(_filtro)

	_destello = ColorRect.new()
	_destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destello.color = Color(1, 1, 1, 0)
	add_child(_destello)

	# un solo emisor reutilizado: nada se instancia durante la partida
	_chispas = GPUParticles2D.new()
	_chispas.amount = 24                          # el tope del GDD
	_chispas.one_shot = true
	_chispas.emitting = false
	_chispas.explosiveness = 1.0
	_chispas.lifetime = 0.55
	_chispas.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 90.0
	m.initial_velocity_max = 240.0
	m.gravity = Vector3(0, 520, 0)
	m.scale_min = 0.6
	m.scale_max = 1.6
	m.damping_min = 40.0
	m.damping_max = 90.0
	_chispas.process_material = m
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_chispas.material = cm
	add_child(_chispas)

func _process(delta: float) -> void:
	if _t_sacudida > 0.0:
		_t_sacudida -= delta
		var cam := get_viewport().get_camera_2d()
		if cam:
			var f: float = _fuerza_sacudida * maxf(_t_sacudida / 0.18, 0.0)
			cam.offset = Vector2(randf_range(-f, f), randf_range(-f, f))
			if _t_sacudida <= 0.0:
				cam.offset = Vector2.ZERO
	if _destello.color.a > 0.0:
		_destello.color.a = maxf(_destello.color.a - delta * 9.0, 0.0)
	if _t_aberracion > 0.0:
		_t_aberracion -= delta
		var q: float = clampf(_t_aberracion / ABERRACION, 0.0, 1.0)
		_mat.set_shader_parameter("fuerza", 0.030 * q)
		_mat.set_shader_parameter("vineta", 0.55 * q)
		if _t_aberracion <= 0.0:
			_mat.set_shader_parameter("fuerza", 0.0)
			_mat.set_shader_parameter("vineta", 0.0)
			_filtro.visible = false

# ------------------------------------------------------------------ publicos
func sacudir(fuerza: float = SACUDIDA, dur: float = 0.18) -> void:
	_fuerza_sacudida = fuerza
	_t_sacudida = dur
				
func destello(color: Color = Color(1, 1, 1), alfa: float = 0.85) -> void:
	_destello.color = Color(color.r, color.g, color.b, alfa)

func aberrar(dur: float = ABERRACION) -> void:
	_t_aberracion = dur
	_filtro.visible = true

func chispas(donde: Vector2, tinte: Color = Color(0.21, 0.85, 1.0)) -> void:
	_chispas.position = donde
	_chispas.modulate = tinte
	_chispas.restart()
	_chispas.emitting = true

func congelar(dur: float = CONGELACION) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

## El paquete completo de la muerte, en el orden que pide el GDD.
## Vibracion al morir. 70 ms y no mas: por debajo de ~30 ms muchos motores de
## movil ni arrancan, y por encima de ~120 se nota como un zumbido en vez de un
## golpe. Aqui es el remate de un golpe visual que ya dura 0,2 s.
const VIBRACION_MS := 70
## Para las pruebas: en headless la vibracion no se siente, asi que se cuenta.
var vibraciones := 0

func muerte(donde: Vector2, tinte: Color = Color(0.55, 0.92, 1.0)) -> void:
	# El ajuste se lee AQUI y no en _ready: Efectos es el primer autoload y
	# arranca antes que Guardado, asi que en su _ready el progreso todavia no
	# esta cargado y siempre veria el valor por defecto.
	if bool(Guardado.opcion("vibracion", true)):
		vibraciones += 1
		Input.vibrate_handheld(VIBRACION_MS, 0.8)
	destello(Color(1, 1, 1), 0.9)
	sacudir(SACUDIDA, 0.18)
	aberrar()
	chispas(donde, tinte)
	congelar()

func aviso_peligro(donde: Vector2, tinte: Color = Color(1.0, 0.25, 0.2)) -> void:
	sacudir(1.2, 0.08)
	chispas(donde, tinte)
