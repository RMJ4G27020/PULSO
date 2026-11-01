extends Area2D
## La terminal: abre la puerta del nivel y devuelve carga.
##
## Se acciona SOLA tras un momento encima. Es lo que pide el tactil (un boton
## mas en pantalla es un boton que tapa el juego), y de paso quita friccion en
## teclado. Pararse aqui es seguro porque la terminal es toma de tierra.
## La tecla sigue estando para quien quiera dispararla al instante.

signal activado

@export var carga_devuelta := 15.0
@export var espera_auto := 0.45        ## s encima antes de accionarse sola

var _dentro := false
var _usado := false
var _t_dentro := 0.0

func _ready() -> void:
	$Sprite.play("apagado")
	_rotular_aviso()
	body_entered.connect(func(c): if c.has_method("morir"): _dentro = true)
	body_exited.connect(func(c): if c.has_method("morir"): _dentro = false)
	_a_tierra.call_deferred()

## La terminal esta conectada a tierra, asi que la estela no prende sobre ella.
func _a_tierra() -> void:
	var r := get_tree().get_first_node_in_group("estela") as RejillaEstela
	if r == null:
		return
	var tam: Vector2 = ($Col.shape as RectangleShape2D).size
	# se ensancha hasta donde llega el aviso (media caja + radio del jugador),
	# para que no puedas morir de pie en un sitio donde el juego te pide pulsar E
	var margen := Vector2(16, 0)
	r.tomar_tierra(Rect2(global_position - tam * 0.5 - margen, tam + margen * 2 + Vector2(0, 16)))

## El aviso dice la tecla que el jugador tiene DE VERDAD para accionar. Era una
## "E" fija: con la tecla reasignada mandaba a pulsar otra cosa, y si la E habia
## pasado a pulso, a gastar un cuarto de la carga. Se ensancha con el nombre
## ("Flecha izq." no cabe en los 48 px de la "E") y sigue centrado.
func _rotular_aviso() -> void:
	var teclas: Array[InputEventKey] = Teclas.de("interactuar")
	if teclas.is_empty():
		return
	var aviso: Label = $Aviso
	aviso.text = Teclas.nombre(teclas[0])
	var an: float = aviso.get_theme_font("font").get_string_size(aviso.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, aviso.get_theme_font_size("font_size")).x
	var medio: float = maxf(24.0, an * 0.5 + 6.0)
	aviso.offset_left = -medio
	aviso.offset_right = medio

## Cierto mientras el jugador puede accionarla: lo usa el HUD del nivel.
func en_rango() -> bool:
	return _dentro and not _usado

func _process(d: float) -> void:
	var listo := en_rango()
	$Aviso.visible = listo
	if not listo:
		_t_dentro = 0.0
		return
	_t_dentro += d
	# late para que se vea aunque pases corriendo, y el latido se acelera
	# conforme se llena: asi se ve que algo esta pasando y no es un adorno
	var f := Time.get_ticks_msec() / 1000.0
	var prisa: float = 7.0 + 9.0 * clampf(_t_dentro / espera_auto, 0.0, 1.0)
	$Aviso.position.y = -46.0 + sin(f * prisa) * 2.0
	$Aviso.modulate.a = 0.7 + sin(f * prisa) * 0.3
	if Input.is_action_just_pressed("interactuar") or _t_dentro >= espera_auto:
		activar()

func activar() -> void:
	if _usado:
		return
	_usado = true
	$Aviso.visible = false
	$Sprite.play("activar")
	Audio.sonar("terminal")
	Efectos.destello(Color(0.78, 0.95, 0.31), 0.35)
	Efectos.sacudir(1.8, 0.14)
	Efectos.chispas(global_position, Color(0.78, 0.95, 0.31))
	activado.emit()
	await $Sprite.animation_finished
	$Sprite.play("activo")

func reiniciar() -> void:
	_usado = false
	_dentro = false
	_t_dentro = 0.0
	$Aviso.visible = false
	$Sprite.play("apagado")
