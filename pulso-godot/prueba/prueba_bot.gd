extends Node
## Bot de recorrido: corre en una direccion y salta al llegar al borde
## (lanza un rayo hacia abajo 26 px por delante). Si la escalera de plataformas
## es franqueable, avanza; si no, se queda clavado o cae al vacio.
## cada nivel dos veces: sin peligros mide la GEOMETRIA, con ellos mide
## lo lejos que llega un jugador que no espera a nada.
const CASOS := [
	["n1_ida_y_vuelta", 16.0, false, 1], ["n1_ida_y_vuelta", 16.0, true, 1],
	["n2_el_corredor", 18.0, false, 1],  ["n2_el_corredor", 18.0, true, 1],
	["n3_el_nudo", 22.0, false, 1],      ["n3_el_nudo", 22.0, true, 1],
	["n1_ida_y_vuelta", 18.0, false, -1],
	["n2_el_corredor", 22.0, false, -1],
	["n3_el_nudo", 26.0, false, -1],
	# El nivel 4 exige trepar el pozo saltando de pared a pared. La adherencia
	# y la altura de cada salto las mide aparte prueba/pared.tscn.
	["n4_la_chimenea", 22.0, false, 1],  ["n4_la_chimenea", 22.0, true, 1],
]
var dir := 1
var x_lim := 0.0
var caso := -1
var n: Node2D
var jug: CharacterBody2D
var t := 0.0
var listo := false
var x_max := -99999.0
var x_ini := 0.0
var y_min := 99999.0
var _reten := 0
var _rumbo_aire := 1.0
const RETEN := 32              # subida completa: 474,8 / 980 = 0,48 s

## La partida de quien juega no puede cambiar lo que se mide: se mide con TSL-04
## y sin asistencia (salvo que se pida otro con PULSO_PERSONAJE=tsl01), y el
## archivo de guardado se copia al empezar y se devuelve al salir.
var _habia := false
var _copia := PackedByteArray()

func _fijar_condiciones() -> void:
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	if Personajes.forzado == "":
		Personajes.forzado = Personajes.BASE
	Guardado.poner_opcion("asistencia", false)
	print("personaje: %s" % Personajes.actual())

func _devolver_partida() -> void:
	if _habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_copia)
			fa.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()

func _rumbo(d: float) -> void:
	Input.action_release("mover_izq" if d > 0.0 else "mover_der")
	Input.action_press("mover_der" if d > 0.0 else "mover_izq")

func _saltar() -> void:
	Input.action_press("saltar")
	_reten = RETEN
	_rumbo_aire = float(dir)

func _ready() -> void:
	_fijar_condiciones()
	_siguiente()

func _siguiente() -> void:
	Input.action_release("mover_der")
	Input.action_release("mover_izq")
	Input.action_release("saltar")
	_reten = 0
	listo = false
	caso += 1
	if caso >= CASOS.size():
		print("PRUEBA BOT OK"); _devolver_partida(); get_tree().quit(); return
	if n:
		n.queue_free(); n = null
		for i in 4: await get_tree().process_frame
	n = load("res://escenas/niveles/%s.tscn" % CASOS[caso][0]).instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	if not CASOS[caso][2]:
		for pel in get_tree().get_nodes_in_group("peligro"):
			pel.queue_free()
	for i in 30: await get_tree().process_frame
	dir = CASOS[caso][3]
	if dir < 0:
		# empezar en la terminal, que es donde arranca la vuelta
		jug.global_position = n.get_node("Interruptor").global_position + Vector2(0, -4)
		for i in 20: await get_tree().process_frame
	x_ini = jug.global_position.x
	x_max = x_ini
	x_lim = x_ini
	y_min = jug.global_position.y
	t = 0.0
	listo = true
	Input.action_press("mover_der" if dir > 0 else "mover_izq")

func _solido(desde: Vector2, hasta: Vector2) -> bool:
	var esp := jug.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(desde, hasta)
	q.exclude = [jug.get_rid()]
	return not esp.intersect_ray(q).is_empty()

func _borde() -> bool:
	## no hay suelo 26 px por delante: toca saltar o darse la vuelta
	var d: Vector2 = jug.global_position + Vector2(26.0 * dir, 0)
	return not _solido(d, d + Vector2(0, 36))

func _hay_donde_caer() -> bool:
	## busca suelo por delante, dentro de lo que da un salto... y tambien MUY
	## por debajo: en PULSO caer no hace daño, lo que mata es el vacio. Mirando
	## solo 104 px abajo, el bot llegaba a la boca del pozo del nivel 4, no veia
	## fondo a 496 px y se daba la vuelta en vez de tirarse dentro.
	for dx in [48.0, 72.0, 96.0, 120.0, 144.0, 168.0]:
		for dy in [-104.0, -80.0, -56.0, -32.0, -8.0, 16.0, 48.0, 96.0,
				   160.0, 240.0, 320.0, 400.0, 480.0]:
			var a: Vector2 = jug.global_position + Vector2(dx * dir, dy)
			if _solido(a, a + Vector2(0, 20)):
				return true
	return false

func _physics_process(d: float) -> void:
	if not listo: return
	t += d
	if jug.vivo:
		x_max = maxf(x_max, jug.global_position.x)
		x_lim = maxf(x_lim, (jug.global_position.x - x_ini) * dir)
		y_min = minf(y_min, jug.global_position.y)
		# El boton de salto se pulsa y se RETIENE hasta que acaba la subida.
		# El salto es de altura variable: soltarlo mientras sube recorta la
		# velocidad al 45%, o sea la altura al 20%. Y no vale mirar `velocity`
		# para decidir, porque este nodo corre antes que el jugador y lo que lee
		# va un tick atrasado.
		if _reten > 0:
			_rumbo(_rumbo_aire)
			_reten -= 1
			if _reten == 0:
				Input.action_release("saltar")
		elif jug.pegado:
			# trepar. Se aprieta CONTRA la pared, no hacia el hueco: la
			# adherencia exige que el eje apunte a la pared, y soltandola en el
			# mismo fotograma que se pulsa salto el salto de pared no dispara.
			_rumbo(-signf(jug.get_wall_normal().x))
			# al despegar, rumbo a la salida: el salto de pared ya empuja hacia
			# atras, y volviendo a apretar hacia adelante se cancela ese empujon
			# y se vuelve a la misma pared mas arriba, que es como se gana altura
			_rumbo_aire = float(dir)
			Input.action_press("saltar")
			_reten = RETEN
		elif jug.is_on_floor() and _borde():
			if _hay_donde_caer():
				_saltar()
			else:
				# callejon sin salida: el zigzag sigue hacia el otro lado
				Input.action_release("mover_der" if dir > 0 else "mover_izq")
				dir = -dir
				Input.action_press("mover_der" if dir > 0 else "mover_izq")
		elif jug.is_on_floor() and jug.is_on_wall():
			# muro delante y suelo por delante: no es un borde, es una pared, y
			# la unica salida es trepar. Sin esto el bot llegaba al pozo del
			# nivel 4, se plantaba contra la pared y esperaba a que la estela lo
			# matara.
			_saltar()
	# se corta en la primera muerte: si no, los reintentos falsean la distancia
	if t > CASOS[caso][1]:
		print("  %-18s %-13s %s  avanzo %5.0f px, subio a y=%4.0f   %s"
			% [CASOS[caso][0], "con peligros" if CASOS[caso][2] else "sin peligros",
			   "ida  " if dir > 0 else "vuelta", absf(x_lim), y_min,
			   "murio en x=%.0f" % jug.global_position.x if not jug.vivo else "vivo al acabar"])
		_siguiente()
