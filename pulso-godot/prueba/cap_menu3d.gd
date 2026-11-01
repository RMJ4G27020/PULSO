extends Node
## Fotos del menu para mirar a TSL-04 con los ojos. Una prueba puede comprobar
## que el personaje esta montado, que parpadea y que la mirada se mueve, pero no
## puede decir si la cara se LEE: para eso hay que verla.
##
## Saca las cuatro reacciones pilladas en el momento y la espera, en
## user://menu3d. Se guarda fuera del proyecto a proposito: un PNG dentro de
## pulso-godot/ lo importa Godot y ensucia el proyecto.
##
## Con ventana, no headless. Y con SOLO=<parte> se saca una sola tanda, que es
## lo mismo que hace --solo en build_tsl04.py y por el mismo motivo: sacarlas
## todas son casi veinte segundos de reloj, y si la ventana queda tapada macOS
## frena el dibujo y no da tiempo ni a eso.
##
##   Godot --path . prueba/capmenu.tscn
##   SOLO=adios Godot --path . prueba/capmenu.tscn     (reac | espera | adios | controles | niveles | personajes)

const SALIDA := "user://menu3d"

var _solo := ""


func _hace(parte: String) -> bool:
	return _solo == "" or _solo == parte


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SALIDA)
	_solo = OS.get_environment("SOLO")
	get_tree().create_timer(300.0).timeout.connect(func():
		print("TIEMPO AGOTADO")
		get_tree().quit())
	get_window().size = Vector2i(1280, 720)
	await _esperar(8)

	var m: Control = load("res://escenas/MenuPrincipal.tscn").instantiate()
	add_child(m)
	await _esperar(6)
	var mundo: Node3D = m.get_node("Escena3D/Marco/Vista/Mundo")

	# la reaccion de cada opcion, pillada en el momento
	for i in (4 if _hace("reac") else 0):
		m.sel = i
		mundo.mirar_opcion(i, 4)
		await _segundos(0.16)
		await _guardar("reac_%d_a.png" % i)
		await _segundos(0.22)
		await _guardar("reac_%d_b.png" % i)
		await _segundos(0.9)
		await _guardar("reac_%d_c.png" % i)

	print("dibujos por cuadro: %d" % int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

	# y quieto un rato: tiene que levantar la vista a buscar al jugador
	if _hace("espera"):
		await _segundos(8.5)
		await _guardar("espera.png")

	# la despedida: mantener SALIR (se suelta antes de los 3 s o el juego cierra)
	if _hace("adios"):
		m.sel = 3
		mundo.mirar_opcion(3, 4)
		Input.action_press("ui_accept")
		for i in 5:
			await _segundos(0.52)
			await _guardar("adios_%d.png" % i)
		Input.action_release("ui_accept")
		await _segundos(1.2)
		await _guardar("adios_suelta.png")

	# la pantalla de controles, en sus cuatro momentos
	if _hace("controles"):
		var c: Control = m.get_node("Controles")
		m.sel = 1
		m._panel = "controles"
		await _segundos(0.6)
		await _guardar("controles_0_reposo.png")
		c.fila = 2
		c.hueco = 1
		c._empezar_escucha()
		await _segundos(0.3)
		await _guardar("controles_1_escucha.png")
		c.escuchando = false
		# El choque se monta EN MEMORIA (_poner) y no con asignar(): asignar
		# escribe el progreso, y una foto no tiene por que tocar la partida de
		# nadie. Al final aplicar() vuelve a leer lo guardado, sin escribir.
		# lo que deja poner la Q en el hueco 1 de impulso: Q era la unica de
		# pulso, asi que se intercambian y pulso se queda el Shift
		var fab: Array[InputEventKey] = Teclas.de_fabrica("impulso")
		var q := InputEventKey.new()
		q.physical_keycode = KEY_Q
		var imp: Array[InputEventKey] = [q, fab[1]]
		var pul: Array[InputEventKey] = [fab[0]]
		Teclas._poner("impulso", imp)
		Teclas._poner("pulso", pul)
		c._marca = "pulso"
		c._t_marca = c.MARCA
		c._destellos["impulso:0"] = c.DESTELLO
		c.fila = 3
		c.hueco = 0
		c._avisar("Intercambio: Q a IMPULSO, Shift a PULSO", "ambar")
		await _segundos(0.15)
		await _guardar("controles_2_choque.png")
		c.fila = c.FILA_RESTAURAR
		c._t_confirma = c.CONFIRMA
		await _segundos(0.15)
		await _guardar("controles_3_restaurar.png")
		Teclas.aplicar()

	# la pantalla de niveles: con el progreso de verdad, y con niveles cerrados.
	# El progreso de prueba se pone EN MEMORIA; cargar() lo devuelve sin escribir.
	if _hace("niveles"):
		var sel: Control = m.get_node("Niveles")
		sel.cambiar_de_verdad = false
		m._panel = "niveles"
		await _segundos(0.6)
		await _guardar("niveles_0_real.png")
		m._panel = ""
		await _esperar(3)
		Guardado._datos = {"max_nivel": 3, "tiempos": {"1": 31.4, "2": 58.2},
			"fragmentos": {"1": 3, "2": 1}}
		m._panel = "niveles"
		await _segundos(0.4)
		sel.foco = 3
		sel._elegir(3)
		await _segundos(0.1)
		await _guardar("niveles_1_cerrado.png")
		m._panel = ""
		Guardado.cargar()

	# los personajes: el selector con cada uno elegido y cada uno corriendo en un
	# nivel con su estela. Se fuerza en memoria (Personajes.forzado): ni la
	# eleccion ni el progreso de quien juega se tocan.
	if _hace("personajes"):
		var sel2: Control = m.get_node("Niveles")
		sel2.cambiar_de_verdad = false
		m._panel = "niveles"
		await _segundos(0.6)
		sel2.foco = sel2.PERSONAJE
		for id in Personajes.ORDEN:
			Personajes.forzado = id
			await _segundos(0.25)
			await _guardar("personajes_0_selector_%s.png" % id)
		m._panel = ""
		await _esperar(3)
		# El menu fuera de verdad: su escena 3D va en un CanvasLayer y no se
		# esconde con el Control, asi que se colaba debajo del nivel.
		m.queue_free()
		await _esperar(2)
		for id in Personajes.ORDEN:
			Personajes.forzado = id
			var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate()
			add_child(n)
			await _esperar(3)
			var j: CharacterBody2D = n.get_node("Jugador")
			j._celebrando = true
			j._t_gracia = 999.0
			j.modulate.a = 1.0
			Input.action_press("mover_izq")
			# la misma distancia para todos, aunque corran a distinta velocidad
			await _segundos(0.55 * 220.0 / j.velocidad)
			Input.action_press("saltar")
			await _segundos(0.16)
			await _guardar("personajes_1_nivel_%s.png" % id)
			Input.action_release("mover_izq")
			Input.action_release("saltar")
			n.queue_free()
			await _esperar(3)
		Personajes.forzado = ""

	print("LISTO en " + ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s" % [SALIDA, nombre])
	print(nombre)


func _esperar(cuadros: int) -> void:
	for i in cuadros:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout
