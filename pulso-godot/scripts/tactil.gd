extends Control
## Mandos tactiles. Inyecta las mismas acciones que el teclado, asi que
## jugador.gd no se entera de nada.
##
## Dos decisiones de diseno:
##  * El joystick es FLOTANTE: nace donde pones el pulgar. Uno fijo te obliga
##    a mirar abajo para encontrarlo, y aqui no puedes apartar la vista.
##  * No hay boton de accionar. La terminal se activa sola al estar encima,
##    que ademas es seguro porque es toma de tierra.
##  * SI hay boton de pausa, arriba en el centro. Antes en movil no habia
##    ninguna forma de abrir el menu salvo el "atras" de Android.

## El boton de pausa NO inyecta la accion: Input.action_press() no genera
## ningun evento y la pausa se abre desde _unhandled_input. Va por senal.
signal pauso

const ZONA_MOVER := 0.45        ## fraccion izquierda de la pantalla
const ZONA_ALTA := 0.30         ## por encima de esto el joystick NO nace
const RADIO_JOY := 52.0
const MUERTA := 9.0             ## px antes de que cuente como mover
const RADIO_BOTON := 38.0       ## ~17 mm en un movil de 6": un dedo entra de sobra
## Radio por boton. La pausa es el unico que NO se busca a ciegas en plena
## carrera, asi que se le da menos area: con el radio grande se traga toques
## que iban al HUD o al salto.
const RADIOS := {"pausa": 26.0}

var _dedos: Dictionary = {}     ## indice de dedo -> que esta tocando
var _joy_centro := Vector2.ZERO
var _joy_punta := Vector2.ZERO
var _mover := ""                ## "", "mover_izq" o "mover_der"
## accion -> centro (Vector2 SIEMPRE: prueba_tactil.gd lo lee como Vector2)
var _botones: Dictionary = {}
var _jugador: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_colocar_botones()
	get_viewport().size_changed.connect(_colocar_botones)
	_jugador = get_tree().get_first_node_in_group("jugador") as Node2D

func _colocar_botones() -> void:
	var r: Vector2 = get_viewport_rect().size
	var m := RADIO_BOTON + 16.0
	# saltar es el mas usado: el mas grande y el mas a mano
	_botones = {
		"saltar":  Vector2(r.x - m, r.y - m),
		"impulso": Vector2(r.x - m - RADIO_BOTON * 2.1, r.y - m + 6.0),
		"pulso":   Vector2(r.x - m, r.y - m - RADIO_BOTON * 2.1),
		# arriba en el centro: fuera del 45% del pulgar izquierdo, a mas de 260
		# px de saltar y sin pisar el HUD (la barra acaba en 225 y el
		# cronometro empieza pasados los 500)
		"pausa":   Vector2(r.x * 0.5, 26.0),
	}
	queue_redraw()

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed: _abajo(t.index, t.position)
		else: _arriba(t.index)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if _dedos.get(d.index, "") == "joy":
			_mover_joy(d.position)

func _abajo(indice: int, pos: Vector2) -> void:
	# los botones ganan aunque caigan en la zona de mover: si no, un pulgar
	# grande sobre el borde mueve al personaje en vez de saltar
	for accion in _botones:
		var radio: float = float(RADIOS.get(accion, RADIO_BOTON))
		if pos.distance_to(_botones[accion]) <= radio * 1.25:
			_dedos[indice] = accion
			if accion == "pausa":
				pauso.emit()
			else:
				Input.action_press(accion)
			queue_redraw()
			return
	var r: Vector2 = get_viewport_rect().size
	# tambien se acota en vertical: un pulgar apoyado arriba a la izquierda
	# hacia nacer un joystick de 52 px justo encima de la barra de carga, y
	# ahora ademas competiria con el boton de pausa
	if pos.x < r.x * ZONA_MOVER and pos.y > r.y * ZONA_ALTA:
		_dedos[indice] = "joy"
		_joy_centro = pos
		_mover_joy(pos)

func _arriba(indice: int) -> void:
	var que: String = _dedos.get(indice, "")
	_dedos.erase(indice)
	if que == "joy":
		_soltar_mover()
		queue_redraw()
	elif que == "pausa":
		queue_redraw()
	elif que != "":
		Input.action_release(que)
		queue_redraw()

func _mover_joy(pos: Vector2) -> void:
	var d := pos - _joy_centro
	if d.length() > RADIO_JOY:
		d = d.normalized() * RADIO_JOY
	_joy_punta = _joy_centro + d
	var quiero := ""
	if d.x < -MUERTA: quiero = "mover_izq"
	elif d.x > MUERTA: quiero = "mover_der"
	if quiero != _mover:
		_soltar_mover()
		if quiero != "":
			Input.action_press(quiero)
			_mover = quiero
	queue_redraw()

func _soltar_mover() -> void:
	if _mover != "":
		Input.action_release(_mover)
		_mover = ""

func _notification(que: int) -> void:
	# al perder el foco (una llamada entra) hay que soltarlo todo, o el
	# personaje sigue corriendo solo cuando vuelves
	#
	# Y al SALIR DE LA ESCENA, por lo mismo: el cambio de nivel no espera a que
	# levantes el dedo. Las acciones de Input.action_press son globales y
	# sobreviven al cambio de escena, asi que un pulgar en el joystick al cruzar
	# el portal del nivel 3 dejaba "mover_der" pulsado durante todo el final, y
	# en el nivel 4 TSL-04 corria sola (o, empujando a la izquierda, se quedaba
	# parada: las dos direcciones pulsadas a la vez se anulan).
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT or que == NOTIFICATION_EXIT_TREE:
		soltar_todo()

func soltar_todo() -> void:
	_soltar_mover()
	for indice in _dedos:
		var q: String = _dedos[indice]
		if q != "joy" and q != "pausa":
			Input.action_release(q)
	_dedos.clear()
	queue_redraw()

func _process(_d: float) -> void:
	# el arco de enfriamiento y el circulo de pulso apagado cambian cada cuadro
	if _jugador:
		queue_redraw()

func _draw() -> void:
	var cian := Color(0.21, 0.85, 1.0)
	for accion in _botones:
		var c: Vector2 = _botones[accion]
		var radio: float = float(RADIOS.get(accion, RADIO_BOTON))
		var pulsado := false
		for i in _dedos:
			if _dedos[i] == accion: pulsado = true
		# el pulso se apaga cuando no hay carga para pagarlo: antes el toque
		# fallaba en silencio y parecia que el boton no respondia
		var apagado: bool = accion == "pulso" and _jugador != null \
			and float(_jugador.carga) <= float(_jugador.coste_pulso)
		var fondo: float = 0.30 if pulsado else (0.04 if apagado else 0.11)
		draw_circle(c, radio, Color(cian.r, cian.g, cian.b, fondo))
		draw_arc(c, radio, 0.0, TAU, 40,
			Color(cian.r, cian.g, cian.b, 0.20 if apagado else 0.55), 2.0, true)
		if accion == "pausa":
			# dos barras: el simbolo universal, y no depende de ninguna fuente
			for lado in [-4.5, 4.5]:
				draw_rect(Rect2(c.x + lado - 2.0, c.y - 7.0, 4.0, 14.0),
					Color(cian.r, cian.g, cian.b, 0.75))
		elif accion == "impulso" and _jugador != null:
			# arco de enfriamiento: sin el no se sabe si has fallado el toque o
			# es que el impulso todavia no esta listo
			var espera: float = float(_jugador.impulso_espera)
			var queda: float = float(_jugador._t_espera)
			if queda > 0.0 and espera > 0.0:
				draw_arc(c, radio - 5.0, -PI * 0.5,
					-PI * 0.5 + TAU * (1.0 - queda / espera), 32,
					Color(cian.r, cian.g, cian.b, 0.75), 3.0, true)
	if _mover != "" or _dedos.values().has("joy"):
		draw_arc(_joy_centro, RADIO_JOY, 0.0, TAU, 40, Color(cian.r, cian.g, cian.b, 0.35), 2.0, true)
		draw_circle(_joy_punta, 17.0, Color(cian.r, cian.g, cian.b, 0.42))
