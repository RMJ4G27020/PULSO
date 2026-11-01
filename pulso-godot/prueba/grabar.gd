extends Node
## Graba material para el README con el Movie Maker de Godot (cuadros a ritmo
## fijo y el audio del juego, sin depender del reloj real). Con ventana:
##
##   GRABAR=intro  Godot --path . --resolution 1280x720 --fixed-fps 30 \
##       --write-movie /ruta/cuadro.png res://prueba/grabar.tscn
##
## GRABAR = intro | final (las cinematicas, de principio a fin) o una de las
## tomas de mecanicas: estela | saltos | pared | terminal | lasermania |
## runthedrun. Las mecanicas se juegan con la entrada de verdad (Input), con
## TSL-04 y sin asistencia en memoria: el guardado no se toca.

const BOT := preload("res://prueba/bot_ruta.gd")

var _que := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_que = OS.get_environment("GRABAR")
	# La ventana no coge el foco: una tecla pulsada por error (Intro, Espacio)
	# saltaba la cinematica a mitad de la grabacion.
	get_window().unfocusable = true
	Personajes.forzado = Personajes.BASE
	if _que != "intro" and _que != "final":
		Guardado.poner_opcion("asistencia", false)
	get_tree().create_timer(120.0).timeout.connect(_fin)
	match _que:
		"intro", "final":
			await _cine(_que == "final")
		"estela":
			await _estela()
		"saltos":
			await _saltos()
		"pared":
			await _pared()
		"terminal":
			await _terminal()
		"lasermania":
			await _bot("n5_lasermania", true, 15.0)
		"runthedrun":
			await _bot("n6_runthedrun", false, 13.0)
		_:
			push_error("GRABAR='%s' no es ninguna toma" % _que)
	_fin()


func _fin() -> void:
	for a in ["mover_izq", "mover_der", "saltar", "impulso", "pulso"]:
		Input.action_release(a)
	# Lo puesto en memoria (asistencia, muertes de las tomas) no puede acabar en
	# la partida de quien juega: se vuelve a leer del disco antes de salir.
	Personajes.forzado = ""
	Guardado.cargar()
	get_tree().quit()


func _s(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _pulsar(a: String, t: float) -> void:
	Input.action_press(a)
	await _s(t)
	Input.action_release(a)


func _nivel(nom: String) -> Node2D:
	var n: Node2D = load("res://escenas/niveles/%s.tscn" % nom).instantiate()
	add_child(n)
	# el portal cambiaria de escena: en una toma no se sale del nivel
	var sal: Node = n.get_node_or_null("Salida")
	if sal:
		for c in sal.alcanzado.get_connections():
			sal.alcanzado.disconnect(c["callable"])
	return n


# --------------------------------------------------------------- cinematicas
func _cine(final: bool) -> void:
	var c: Control = load("res://escenas/CineFinal.tscn" if final else "res://escenas/CineIntro.tscn").instantiate()
	add_child(c)
	c.siguiente = "res://no_existe.tscn"
	await c.termino
	await _s(0.6)


# ----------------------------------------------------------------- mecanicas
## Correr deja estela; el pulso (Q) la borra; quedarse quieto mata.
func _estela() -> void:
	var n := _nivel("n1_ida_y_vuelta")
	await _s(1.3)
	Input.action_press("mover_izq")
	await _s(0.45)
	Input.action_release("mover_izq")
	Input.action_press("mover_der")
	await _s(0.55)
	Input.action_release("mover_der")
	Input.action_press("mover_izq")
	await _s(0.3)
	Input.action_release("mover_izq")
	await _pulsar("pulso", 0.1)                 # la estela desaparece
	Input.action_press("mover_der")
	await _s(0.4)
	Input.action_release("mover_der")
	await _s(2.2)                               # quieto: la celda prende y mata
	n.queue_free()


## Saltos entre plataformas e impulso en el aire.
func _saltos() -> void:
	var n := _nivel("n1_ida_y_vuelta")
	await _s(1.2)
	var bot: Node = BOT.new()
	add_child(bot)
	bot.iniciar(n, false)
	await _s(1.6)
	await _pulsar("impulso", 0.1)
	await _s(3.2)
	bot.parar()
	n.queue_free()


## Adherencia y salto de pared en el pozo del nivel 4.
func _pared() -> void:
	var n := _nivel("n4_la_chimenea")
	var j: CharacterBody2D = n.get_node("Jugador")
	await _s(0.4)
	j.global_position = Vector2(35.5 * 16.0, 37.0 * 16.0)
	j.velocity = Vector2.ZERO
	j._t_gracia = 0.0
	(j.get_node("Camara") as Camera2D).reset_smoothing()
	var t := 0.0
	var reten := 0.0
	while t < 6.5:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		if reten > 0.0:
			reten -= d
			if reten <= 0.0:
				Input.action_release("saltar")
			continue
		# contra la pared derecha; pegado, salto de pared y otra vez contra ella
		Input.action_release("mover_izq")
		Input.action_press("mover_der")
		if j.pegado or (j.is_on_floor() and t > 0.3):
			Input.action_press("saltar")
			reten = 0.3
	n.queue_free()


## La terminal: pararse encima la acciona y abre la puerta.
func _terminal() -> void:
	var n := _nivel("n1_ida_y_vuelta")
	var j: CharacterBody2D = n.get_node("Jugador")
	var it: Node2D = n.get_node("Interruptor")
	await _s(0.3)
	j.global_position = it.global_position + Vector2(-150, -4)
	j.velocity = Vector2.ZERO
	(j.get_node("Camara") as Camera2D).reset_smoothing()
	await _s(0.4)
	Input.action_press("mover_der")
	await _s(0.62)
	Input.action_release("mover_der")
	await _s(2.6)
	n.queue_free()


## Un tramo de cada nivel grande con el bot de ruta.
func _bot(nom: String, paciente: bool, dur: float) -> void:
	var n := _nivel(nom)
	await _s(0.5)
	var bot: Node = BOT.new()
	add_child(bot)
	bot.iniciar(n, paciente)
	Input.action_press("mover_der")
	await _s(dur)
	bot.parar()
	n.queue_free()
