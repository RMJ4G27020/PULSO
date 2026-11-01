extends Control
## Intro de PULSO con el metodo de The Binding of Isaac:
##   - laminas dibujadas a mano, NO video ni animacion por tween
##   - cada pose son DOS dibujos casi iguales que se alternan: la linea "hierve"
##   - se cambia de dibujo cada 3 cuadros a 30 fps = 10 dibujos por segundo
##   - todo ocurre sobre una hoja apoyada en un escritorio
##
## La misma maquinaria cuenta el FINAL (escenas/CineFinal.tscn, con final = true).
## Intro y final son el mismo objeto a proposito: las dos son laminas que
## hierven sobre el mismo escritorio, y el final rima con la intro vineta a
## vineta. Si fueran dos scripts, se desincronizarian al primer retoque.

signal termino

const SIGUIENTE := "res://escenas/niveles/n1_ida_y_vuelta.tscn"
## Despues del final el juego SIGUE, en el nivel 4. La historia se cierra en el
## tercero, pero la chimenea y los niveles generados son el juego de despues: si
## el final llevara al menu, nadie volveria a verlos, porque JUGAR empieza
## siempre por la intro y el nivel 1.
const SIGUIENTE_FINAL := "res://escenas/niveles/n4_la_chimenea.tscn"
const HERVOR := 0.1      ## 3 cuadros a 30 fps: la cadencia de Isaac
const VOLT := Color(0.78, 0.95, 0.31)

## lamina, duracion, giro de la hoja, narracion
const BEATS := [
	[10, 4.0, -1.4, "El centro de datos NIMBUS-9 llevaba catorce años sin apagarse ni una sola vez."],
	[ 1, 4.0,  1.1, "En su sótano térmico vivía la máquina. Nadie bajaba nunca a verla."],
	[11, 3.5, -0.9, "De sus cables colgaban cuatro celdas de prueba de carga."],
	[12, 4.0,  1.6, "Tres ya se habían apagado. Nadie las bajó de ahí."],
	[ 2, 3.5, -1.2, "La cuarta se llamaba TSL-04. Nunca había hecho nada."],
	[13, 3.5,  0.8, "Arriba, algo lo miraba todo. Todo el tiempo."],
	[ 3, 3.5, -1.6, "Una noche de tormenta, un rayo cayó sobre el pararrayos."],
	[ 4, 2.5,  1.3, "La descarga recorrió el cable de tierra hasta el final."],
	[ 5, 4.0, -1.0, "Y TSL-04 abrió los ojos."],
	[14, 4.0,  1.4, "Dio un paso. El suelo se encendió detrás de ella."],
	[15, 4.5, -1.3, "Y entendió que no podía volver por donde había venido."],
	[ 6, 4.5,  0.9, "La máquina no supo qué era. La llamó ERROR 04."],
	[ 7, 3.0, -1.5, "Y mandó borrarla."],
	[17, 3.5,  1.2, "Los drones de mantenimiento cambiaron de tarea."],
	[16, 3.5, -0.8, "Las puertas empezaron a cerrarse por sectores."],
	[18, 4.0,  1.5, "A TSL-04 le quedaba muy poca carga. Y bajaba sola."],
	[ 8, 4.5, -1.1, "Así que echó a correr. Y no ha parado desde entonces."],
]
## El final. Viene del storyboard original, que acababa en la vineta 9 (el
## escape) y la intro nunca uso. Cada linea contesta a una de la intro:
##   "Dio un paso. El suelo se encendio detras de ella."  -> "...no se encendio."
##   "le quedaba muy poca carga. Y bajaba sola."          -> "El sol empezo a llenarle la carga."
##   "echo a correr. Y no ha parado desde entonces."      -> "...por primera vez, se paro."
##   "Tres ya se habian apagado. Nadie las bajo de ahi."  -> "...otras tres luces."
## Suman 33,5 s; con fundido y rotulo, 36,3. El tema "libre" dura 38,4: no llega
## a dar la vuelta.
const BEATS_FINAL := [
	[19, 4.0, -1.2, "Al final del conducto había una rejilla. Y detrás, luz de verdad."],
	[13, 3.5,  1.0, "Arriba, el ojo lo miraba todo. Pero a ella ya no la vio."],
	[ 9, 4.5, -0.8, "TSL-04 atravesó la pared de NIMBUS-9 y cruzó la ciudad sin mirar atrás."],
	[20, 4.0,  1.3, "Al otro lado había campos. Allí nadie la buscaba."],
	[21, 4.0, -1.4, "Dio un paso. El suelo no se encendió."],
	[22, 4.0,  0.9, "El sol empezó a llenarle la carga. Despacio, sin prisa."],
	[23, 4.5, -1.1, "Y por primera vez desde aquella noche, TSL-04 se paró."],
	[24, 5.0,  1.2, "A su lado se encendieron otras tres luces."],
]
const FUNDIDO := 1.2
const ROTULO := 1.6
## La musica del final entra ya con la pantalla en negro que deja el nivel 3,
## asi que puede entrar despacio: no hay nada que tapar.
const ENTRA_MUSICA := 1.5

## true en CineFinal.tscn. Cambia las laminas, a donde se va despues, el rotulo
## y la musica; el resto de la maquinaria es la misma.
@export var final := false
var beats: Array = BEATS
var siguiente: String = SIGUIENTE

var t := 0.0
var beat := 0
var t_beat := 0.0
var _t_hervor := 0.0
var _b := false
var fase := "laminas"        ## laminas -> fundido -> rotulo
var acabo := false
var _tex := []               ## [[texA, texB], ...]

@onready var _lamina: TextureRect = $Lamina
@onready var _cartel: Label = $Cartel/Texto
@onready var _tira: ColorRect = $Cartel
@onready var _saltar: Label = $Saltar
@onready var _negro: ColorRect = $Negro
@onready var _rotulo: Label = $Rotulo

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if final:
		beats = BEATS_FINAL
		siguiente = SIGUIENTE_FINAL
		# Un solo reproductor de musica para todo el juego, asi que dos temas no
		# pueden sonar a la vez por construccion. Lo que si podria pasar es un
		# corte: por eso el nivel 3 apaga "circuito" durante SU fundido, y
		# "libre" arranca aqui, en negro y desde silencio.
		if Audio.has_method("poner_musica"):
			_entrar_libre()
	for b in beats:
		_tex.append([load("res://arte/laminas/v%da.svg" % b[0]),
					 load("res://arte/laminas/v%db.svg" % b[0])])
	_negro.color = Color(0, 0, 0, 0)
	_rotulo.modulate = Color(1, 1, 1, 0)
	_saltar.text = texto_saltar(DisplayServer.is_touchscreen_available())
	_colocar()


## Desde el nivel 3, "circuito" llega ya apagada: el nivel la funde con su
## fundido a negro. Pero al final tambien se llega desde NIVELES ("Ver el
## final"), con "circuito" sonando a todo volumen, y cambiar de tema en el unico
## reproductor la cortaba en seco: justo el corte que el proyecto evita. Si
## suena otra cosa, se apaga primero en medio segundo y "libre" entra despues,
## desde silencio, como cuando se llega del nivel 3.
const SALE_MUSICA := 0.5

func _entrar_libre() -> void:
	var otro := String(Audio.get("_tema"))
	if otro != "" and otro != "libre":
		Audio.parar_musica(SALE_MUSICA)
		await get_tree().create_timer(SALE_MUSICA).timeout
		# si se ha saltado mientras tanto, no se pone nada
		if acabo or not is_inside_tree():
			return
	Audio.poner_musica("libre", ENTRA_MUSICA)


## "Espacio" no significa nada en un telefono sin teclado. Con pantalla tactil
## se dice lo que de verdad funciona ahi; Espacio sigue funcionando igual.
static func texto_saltar(tactil: bool) -> String:
	return "Toca para saltar" if tactil else "Espacio para saltar"


## Un toque (o un clic izquierdo) salta, con la misma espera de 0,8 s que la
## tecla: es el toque que entro en JUGAR, y no puede saltarse la intro entera.
## El clic que Godot emula a partir del toque se ignora, que ya llega el toque.
func _input(e: InputEvent) -> void:
	if acabo or t <= 0.8:
		return
	var toque := e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed
	var clic := e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
		and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and e.device != InputEvent.DEVICE_ID_EMULATION
	if toque or clic:
		get_viewport().set_input_as_handled()
		_terminar()


## El boton atras de Android tambien la salta. Ir al menu desde aqui obligaria a
## volver a ver la intro al pulsar JUGAR, y el final no se podria terminar.
func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_GO_BACK_REQUEST and not acabo and is_inside_tree():
		_terminar()

func _process(delta: float) -> void:
	if acabo:
		return
	t += delta
	t_beat += delta
	if t > 0.8 and (Input.is_action_just_pressed("ui_accept")
			or Input.is_action_just_pressed("pausa") or Input.is_action_just_pressed("saltar")):
		_terminar(); return

	# el hervor: cambiar de dibujo cada 3 cuadros, pase lo que pase
	_t_hervor += delta
	while _t_hervor >= HERVOR:
		_t_hervor -= HERVOR
		_b = not _b
		if fase == "laminas":
			_lamina.texture = _tex[beat][1 if _b else 0]

	match fase:
		"laminas":
			_saltar.modulate.a = clampf(t - 0.8, 0.0, 1.0) * 0.55
			if t_beat >= float(beats[beat][1]):
				t_beat = 0.0
				beat += 1
				if beat >= beats.size():
					fase = "fundido"
					# la musica se va con la imagen, ni antes ni despues: asi el
					# rotulo queda en silencio y el nivel 4 arranca su tema limpio
					if final and Audio.has_method("parar_musica"):
						Audio.parar_musica(FUNDIDO)
				else:
					_colocar()
			else:
				_entrada()
		"fundido":
			_negro.color.a = clampf(t_beat / FUNDIDO, 0.0, 1.0)
			_lamina.modulate.a = 1.0 - _negro.color.a
			_tira.modulate.a = 1.0 - _negro.color.a
			_saltar.modulate.a = (1.0 - _negro.color.a) * 0.55
			if t_beat >= FUNDIDO:
				t_beat = 0.0; fase = "rotulo"
				_negro.color.a = 1.0
		"rotulo":
			_rotulo.modulate.a = clampf(t_beat / 0.35, 0.0, 1.0)
			if t_beat >= ROTULO:
				_terminar()

func _colocar() -> void:
	var b = beats[beat]
	_lamina.texture = _tex[beat][0]
	_lamina.rotation_degrees = float(b[2])
	_cartel.text = String(b[3])
	_lamina.modulate.a = 0.0
	_tira.modulate.a = 0.0

func _entrada() -> void:
	## la hoja no se desliza: aparece, como cuando pasas una pagina
	var a := clampf(t_beat / 0.22, 0.0, 1.0)
	_lamina.modulate.a = a
	_tira.modulate.a = clampf((t_beat - 0.25) / 0.3, 0.0, 1.0)

func _terminar() -> void:
	acabo = true
	termino.emit()
	# Si se salta el final a medias, "libre" sigue sonando. Se corta aqui y no
	# con fundido: el nivel 4 va a pedir "circuito" en su _ready, y cambiar de
	# tema en el unico reproductor a mitad de un fundido se oye como un tropiezo.
	# Parado en seco, el nivel lo hace entrar desde silencio, como siempre.
	if final and Audio.has_method("parar_musica"):
		Audio.parar_musica(0.0)
	if get_tree() != null and ResourceLoader.exists(siguiente):
		get_tree().change_scene_to_file(siguiente)
