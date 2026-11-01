extends Node
## Los dos niveles grandes (n5 Lasermania y n6 Runthedrun) y las balizas.
##
## Lo que se comprueba, y lo que NO:
##   - La estructura (lo que tiene cada nivel, que las balizas pisan suelo y
##     que ningun peligro cae encima de un sitio de descanso).
##   - Las balizas: recargan, fijan donde se reaparece, no deshacen lo hecho, y
##     el reinicio completo si lo deshace. Y que un nivel SIN balizas sigue
##     reiniciandose entero al morir.
##   - Que se pueden recorrer: un bot corre de la aparicion al portal sin
##     peligros (la geometria), el paciente de Lasermania pasa todas las
##     cortinas esperando a que se apaguen, y el de Runthedrun llega corriendo
##     con los drones puestos.
## NO prueba que sean divertidos ni justos para una persona: eso solo lo dice
## jugarlos. Un bot que pasa demuestra que se PUEDE pasar, no que sea facil.

const BOT := preload("res://prueba/bot_ruta.gd")
const NIVELES := {
	"n5_lasermania": "res://escenas/niveles/n5_lasermania.tscn",
	"n6_runthedrun": "res://escenas/niveles/n6_runthedrun.tscn",
}

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false


func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-70s %s" % [txt, "OK" if c else "FALLA"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Personajes.forzado = Personajes.BASE
	Guardado.poner_opcion("asistencia", false)
	# GRANDES=rutas corre solo los recorridos (los lentos); GRANDES=ficha, lo demas
	var solo := OS.get_environment("GRANDES")
	if solo != "rutas":
		for nom in NIVELES:
			await _estructura(nom)
		await _balizas()
		await _sin_balizas()
		await _reinicio_en_la_muerte()
		await _r_en_la_ceremonia()
	if solo != "ficha":
		await _recorrer("n5_lasermania", "geometria", false, true)
		await _recorrer("n6_runthedrun", "geometria", false, true)
		await _recorrer("n5_lasermania", "paciente", true, false)
		await _recorrer("n6_runthedrun", "con drones", false, false)
		# y con TSL-02, la que mas corre y mas salta: lo que se pone tras aterrizar
		# (balizas, pinchos) y el ancho de las plataformas se midio con ella
		Personajes.forzado = "tsl02"
		await _recorrer("n5_lasermania", "geometria con TSL-02", false, true)
		await _recorrer("n6_runthedrun", "con drones y TSL-02", false, false)
		await _recorrer("n5_lasermania", "paciente con TSL-02", true, false)
		Personajes.forzado = Personajes.BASE
	_fin()


func _cuadros(c: int) -> void:
	for i in c:
		await get_tree().process_frame


## Los solapes de las Area2D se actualizan en el tick de fisica, y en headless
## los cuadros de dibujo corren mucho mas deprisa que los ticks.
func _fisica(c: int) -> void:
	for i in c:
		await get_tree().physics_frame


func _cargar(nom: String) -> Node2D:
	var n: Node2D = (load(NIVELES.get(nom, nom)) as PackedScene).instantiate() as Node2D
	add_child(n)
	await _cuadros(3)
	return n


func _quitar(n: Node2D) -> void:
	n.queue_free()
	await _cuadros(3)


func _suelo_bajo(p: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2(0, 40))
	return not get_viewport().world_2d.direct_space_state.intersect_ray(q).is_empty()


# -------------------------------------------------------------- estructura
func _estructura(nom: String) -> void:
	var n: Node2D = await _cargar(nom)
	var jug: CharacterBody2D = n.get_node("Jugador")
	var ap: Marker2D = n.get_node("Aparicion")
	var sal: Node2D = n.get_node("Salida")
	var inter: Node2D = n.get_node("Interruptor")
	var tabla: Array = load("res://scripts/selector.gd").get("NIVELES")
	var tramos := 0
	for fila in tabla:
		if String(fila[0]).ends_with(nom + ".tscn"):
			tramos = int(fila[3])
	var balizas: Array = get_tree().get_nodes_in_group("baliza")
	_ok(n.has_node("Anclaje") and n.has_node("Puerta") and n.get_node("Fragmentos").get_child_count() == 3,
		"%s: anclaje, puerta y tres fragmentos" % nom)
	_ok(balizas.size() == tramos - 1 and balizas.size() >= 4,
		"%s: %d balizas (%d tramos de carga)" % [nom, balizas.size(), tramos])
	var largo: float = sal.global_position.x - ap.global_position.x
	_ok(largo > 6000.0, "%s: del anclaje al portal hay %.0f px (se va, no se vuelve)" % [nom, largo])
	_ok(inter.global_position.x > ap.global_position.x and inter.global_position.x < sal.global_position.x,
		"%s: la terminal esta entre el anclaje y el portal" % nom)
	var sin_suelo := ""
	for b in balizas:
		if not _suelo_bajo(b.punto_aparicion()):
			sin_suelo = "baliza en x=%.0f" % b.global_position.x
	if not _suelo_bajo(ap.global_position):
		sin_suelo = "anclaje"
	_ok(sin_suelo == "", "%s: el anclaje y las balizas pisan suelo %s" % [nom, sin_suelo])

	# ningun peligro encima de un sitio de descanso: un haz o una pua junto a una
	# baliza son una trampa, y un dron cerca te ve al reaparecer
	var malos: Array[String] = []
	var descansos: Array = []
	for b in balizas:
		descansos.append(b.global_position)
	descansos.append(inter.global_position)
	for pel in get_tree().get_nodes_in_group("peligro"):
		var ruta: String = String((pel.get_script() as Script).resource_path)
		for r in descansos:
			var dx: float = absf((pel.global_position.x) - (r as Vector2).x)
			if ruta.ends_with("laser.gd") or ruta.ends_with("pinchos.gd"):
				if dx < 64.0:
					malos.append("%s a %.0f px" % [ruta.get_file(), dx])
			elif ruta.ends_with("dron_zapador.gd"):
				# la torreta ve a `alcance` y dispara hacia donde estes
				var dz: float = pel.global_position.distance_to(r as Vector2)
				if dz < float(pel.alcance) + 16.0:
					malos.append("torreta a %.0f px" % dz)
			elif ruta.ends_with("dron_purga.gd"):
				var fin: float = pel.global_position.x + (pel.recorrido as Vector2).x
				var cerca: float = minf(absf(pel.global_position.x - (r as Vector2).x), absf(fin - (r as Vector2).x))
				if (r as Vector2).x >= pel.global_position.x and (r as Vector2).x <= fin:
					cerca = 0.0
				if cerca < 200.0:
					malos.append("dron a %.0f px" % cerca)
	_ok(malos.is_empty(), "%s: ningun peligro junto a una baliza ni a la terminal %s" % [nom, str(malos)])
	# Una torreta no puede vigilar el sitio donde se espera a una cortina (los 6
	# metros antes de ella): esperar mataria por un lado y no esperar, por el otro.
	var vigiladas: Array[String] = []
	for z in get_tree().get_nodes_in_group("peligro"):
		if not String((z.get_script() as Script).resource_path).ends_with("dron_zapador.gd"):
			continue
		for l in get_tree().get_nodes_in_group("peligro"):
			if not String((l.get_script() as Script).resource_path).ends_with("laser.gd"):
				continue
			var fondo := Vector2(l.global_position.x - 64.0, l.global_position.y + 16.0 * float(l.largo_celdas) - 16.0)
			if z.global_position.distance_to(fondo) < float(z.alcance):
				vigiladas.append("laser en x=%.0f" % l.global_position.x)
	_ok(vigiladas.is_empty(), "%s: ninguna torreta alcanza donde se espera a una cortina %s" % [nom, str(vigiladas)])
	await _quitar(n)


# ---------------------------------------------------------------- balizas
func _balizas() -> void:
	var n: Node2D = await _cargar("n5_lasermania")
	var jug: CharacterBody2D = n.get_node("Jugador")
	var lista: Array = get_tree().get_nodes_in_group("baliza")
	lista.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var b0: Node = lista[0]
	var b1: Node = lista[1]
	_ok(n._punto_control == Vector2.INF and not b0.usada(), "al empezar no hay punto de control")
	# pisar la primera: recarga, se vuelve el punto de reaparicion y avisa
	jug.carga = 30.0
	jug.global_position = b0.punto_aparicion()
	jug.velocity = Vector2.ZERO
	await _fisica(4)
	_ok(b0.usada() and jug.carga > 98.0 and n._punto_control == b0.punto_aparicion(),
		"pisar una baliza recarga a tope (%.0f %%) y fija el punto de control" % jug.carga)
	_ok(n._t_aviso_baliza > 0.0, "y avisa en el HUD (\"punto de control\")")
	# lo hecho antes de morir no se deshace
	n._fragmentos_tomados = 2
	n._inter.activar()
	await _cuadros(3)
	n._tiempo = 41.0
	jug.carga = 12.0
	jug.global_position = b0.punto_aparicion() + Vector2(300, 0)
	jug._t_gracia = 0.0                         # la gracia de empezar impediria morir
	jug.morir()
	await get_tree().create_timer(1.1, true, false, true).timeout
	await _cuadros(2)
	_ok(jug.global_position.distance_to(b0.punto_aparicion()) < 6.0 and jug.vivo,
		"al morir se reaparece en la baliza (a %.0f px)" % jug.global_position.distance_to(b0.punto_aparicion()))
	_ok(jug.carga > 98.0, "con la carga a tope (%.1f %%)" % jug.carga)
	_ok(n._fragmentos_tomados == 2 and n._puerta.abierta and n._tiempo >= 41.0 and n._muertes == 1,
		"sin deshacer los fragmentos, la terminal ni el cronometro (%d frag, %.0f s)" % [n._fragmentos_tomados, n._tiempo])
	# la siguiente sustituye a la anterior, y pisar una anterior no vuelve atras
	jug.global_position = b1.punto_aparicion()
	await _fisica(4)
	_ok(n._punto_control == b1.punto_aparicion(), "la siguiente baliza pasa a ser el punto de control")
	jug.global_position = b0.punto_aparicion()
	await _fisica(4)
	_ok(n._punto_control == b1.punto_aparicion(), "y una anterior, ya usada, no lo devuelve atras")
	# los peligros vuelven a su pose de partida al reaparecer
	var l: Node = null
	for p in get_tree().get_nodes_in_group("peligro"):
		if String((p.get_script() as Script).resource_path).ends_with("laser.gd"):
			l = p
			break
	l._t = 1.7                                  # a mitad de ciclo
	jug._t_gracia = 0.0
	jug.morir()
	await get_tree().create_timer(1.1, true, false, true).timeout
	await _cuadros(2)
	# sin el reinicio, _t seguiria en 1,7 + 1,1 s; con el, va poco mas alla de su desfase
	var dt: float = l._t - l.desfase
	_ok(dt >= 0.0 and dt < 0.6,
		"los lasers vuelven a su fase de partida al reaparecer (%.2f s pasada la de partida)" % dt)
	# el reinicio COMPLETO si lo deshace todo
	n.reiniciar()
	await _cuadros(3)
	_ok(n._punto_control == Vector2.INF and not b0.usada() and not b1.usada(),
		"reiniciar el nivel borra el punto de control y deja las balizas sin pisar")
	_ok(not n._puerta.abierta and n._fragmentos_tomados == 0
		and jug.global_position.distance_to(n.get_node("Aparicion").global_position) < 6.0,
		"y deja puerta cerrada, sin fragmentos y en el anclaje")
	await _quitar(n)


func _sin_balizas() -> void:
	# un nivel de los de siempre sigue reiniciandose ENTERO al morir
	var n: Node2D = await _cargar("res://escenas/niveles/n1_ida_y_vuelta.tscn")
	var jug: CharacterBody2D = n.get_node("Jugador")
	n._fragmentos_tomados = 2
	n._inter.activar()
	await _cuadros(3)
	jug._t_gracia = 0.0
	jug.morir()
	await get_tree().create_timer(1.1, true, false, true).timeout
	await _cuadros(2)
	_ok(n._fragmentos_tomados == 0 and not n._puerta.abierta
		and jug.global_position.distance_to(n.get_node("Aparicion").global_position) < 6.0,
		"sin balizas, morir reinicia el nivel entero como siempre")
	await _quitar(n)


## Reiniciar en la pausa de muerte (0,85 s): el reinicio ya revive al jugador, y
## la reaparicion pendiente no puede devolverlo al anclaje otra vez.
func _reinicio_en_la_muerte() -> void:
	var n: Node2D = await _cargar("res://escenas/niveles/n1_ida_y_vuelta.tscn")
	var jug: CharacterBody2D = n.get_node("Jugador")
	var ap: Vector2 = n.get_node("Aparicion").global_position
	jug._t_gracia = 0.0
	jug.morir()
	await get_tree().create_timer(0.2, true, false, true).timeout
	n.reiniciar()
	jug.global_position = ap + Vector2(96, 0)        # ya ha echado a correr
	jug.velocity = Vector2.ZERO
	await get_tree().create_timer(1.0, true, false, true).timeout
	_ok(jug.global_position.distance_to(ap) > 60.0,
		"reiniciar durante la pausa de muerte no deja un segundo reinicio pendiente")
	await _quitar(n)


## La tecla de reiniciar durante la ceremonia de salida no hace nada (como la
## pausa): si reiniciara, la ceremonia cargaria el siguiente nivel igual.
func _r_en_la_ceremonia() -> void:
	var n: Node2D = await _cargar("res://escenas/niveles/n1_ida_y_vuelta.tscn")
	var jug: CharacterBody2D = n.get_node("Jugador")
	n._inter.activar()
	await _fisica(4)
	n._tiempo = 33.0
	n._al_salir()
	_ok(n._terminado, "(la salida ha empezado)")
	var e := InputEventAction.new()
	e.action = "reiniciar"
	e.pressed = true
	Input.parse_input_event(e)
	await _cuadros(2)
	e = InputEventAction.new()
	e.action = "reiniciar"
	e.pressed = false
	Input.parse_input_event(e)
	await _cuadros(2)
	_ok(n._terminado and n._tiempo >= 33.0 and n._puerta.abierta,
		"la tecla de reiniciar no corta la ceremonia de salida")
	# que no cambie de escena: se quita antes de que acabe la ceremonia
	await _quitar(n)


# ----------------------------------------------------------------- rutas
## Corre el bot de la aparicion al portal. `sin_peligros` los quita todos (mide
## la geometria); con ellos puestos, `paciente` decide si espera a los lasers.
func _recorrer(nom: String, que: String, paciente: bool, sin_peligros: bool) -> void:
	var n: Node2D = await _cargar(nom)
	var sal: Node = n.get_node("Salida")
	# el portal de verdad cambiaria de escena y se llevaria la prueba por delante
	for c in sal.alcanzado.get_connections():
		sal.alcanzado.disconnect(c["callable"])
	if sin_peligros:
		for p in get_tree().get_nodes_in_group("peligro"):
			p.queue_free()
		await _cuadros(2)
	var bot: Node = BOT.new()
	add_child(bot)
	bot.iniciar(n, paciente)
	Input.action_press("mover_der")
	# 4 veces mas deprisa SIN cambiar la fisica: con time_scale solo, cada tick
	# de fisica dura 4/60 s y los saltos salen distintos (el bot se caia donde un
	# jugador no). Con 240 ticks por segundo y escala 4, cada tick sigue siendo
	# 1/60 s de juego.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var limite := 400.0
	var siguiente := 20.0
	while not bot.llegada and bot.t < limite and not _acabado:
		await get_tree().process_frame
		# La congelacion de la muerte (Efectos.congelar) devuelve time_scale a 1 al
		# acabar, no a lo que hubiera: sin esto, tras la primera muerte cada tick
		# de fisica pasaba a durar 1/240 s de juego.
		if Engine.time_scale != 0.0 and Engine.time_scale != 4.0:
			Engine.time_scale = 4.0
		if bot.t >= siguiente:
			print("    ... %s %s: t=%.0f s, x=%.0f, %d muertes" % [nom, que, bot.t, jug_x(n), bot.muertes])
			siguiente += 20.0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	bot.parar()
	var motivo := ""
	if not bot.llegada:
		motivo = " (se queda en x=%.0f de %.0f, %d muertes, murio en %s)" % [bot.x_max,
			sal.global_position.x, bot.muertes, str(bot.murio_en.slice(0, 5))]
	var sin_pisar := 0
	for b in get_tree().get_nodes_in_group("baliza"):
		if not b.usada():
			sin_pisar += 1
	_ok(sin_pisar == 0 or not bot.llegada, "%s, %s: pisa todas las balizas (%d sin pisar)" % [nom, que, sin_pisar])
	_ok(bot.llegada and (bot.muertes == 0 or not sin_peligros),
		"%s, %s: llega al portal en %.0f s de juego, con %d muertes y %d esperas%s" % [nom, que, bot.t,
			bot.muertes, bot.esperas, motivo])
	bot.queue_free()
	await _quitar(n)


func jug_x(n: Node2D) -> float:
	return (n.get_node("Jugador") as Node2D).global_position.x


func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Personajes.forzado = ""
	if _habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_copia)
			fa.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA GRANDES OK")
	get_tree().quit()
