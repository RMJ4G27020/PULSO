extends Node
## Recursos graficos de la ficha de Google Play, sacados del juego DE VERDAD.
##
## Google exige que las capturas reflejen la app, asi que nada de montajes: se
## cargan los niveles, se juega con la entrada real y se fotografia el viewport.
## Solo el icono y el grafico destacado se componen, y con piezas del juego.
##
## Se guarda en user://ficha y se copia FUERA del proyecto
## (/Users/joserico/pulso/ficha_tienda/). Un PNG dentro de pulso-godot/ hace
## que Godot lo importe y ensucie el proyecto.
##
##   Godot --path . prueba/capficha.tscn      (con ventana, no headless)
##   SOLO=6 Godot --path . prueba/capficha.tscn   (una sola captura, para iterar)

const SALIDA := "user://ficha"
const RETRATO := "/Users/joserico/pulso/tsl04/retrato.png"
const FONDO := Color(0.031, 0.055, 0.086)
const CIAN := Color(0.21, 0.85, 1.0)

## El progreso con el que se saca la pantalla NIVELES: se pone EN MEMORIA y nunca
## se guarda (Guardado.cargar() lo devuelve). Es un estado al que se llega jugando:
## los cuatro niveles pasados, los 12 fragmentos y tiempos cerca del par.
const PROGRESO := {"max_nivel": 5, "tiempos": {"1": 34.2, "2": 49.7, "3": 61.5, "4": 55.3},
	"fragmentos": {"1": 3, "2": 3, "3": 3, "4": 3}, "opciones": {}}

var _t0 := 0.0
var _solo := ""
var _habia := false
var _copia := PackedByteArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SALIDA)
	# La ficha ensena a TSL-04 sin asistencia, no al personaje ni a los ajustes de
	# quien la saque: se fija en memoria, y el archivo de guardado se copia y se
	# devuelve por si algo lo escribiera.
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Personajes.forzado = Personajes.BASE
	Guardado.poner_opcion("asistencia", false)
	_solo = OS.get_environment("SOLO")
	# guardia: una captura colgada no puede quedarse abierta para siempre
	get_tree().create_timer(240.0).timeout.connect(func():
		print("TIEMPO AGOTADO")
		get_tree().quit())
	if _solo == "":
		_icono()
		await _destacado()
	await _capturas()
	_devolver_partida()
	print("FICHA LISTA en " + ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()


func _devolver_partida() -> void:
	Personajes.forzado = ""
	if _habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_copia)
			fa.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()


# ------------------------------------------------------------------- icono
## 512x512. Fondo lleno hasta el borde (Google aplica su propia mascara
## redondeada, asi que nada de esquinas ni sombras propias) y TSL-04 grande: un
## icono se ve a 48 px en el cajon de apps, y ahi el personaje tiene que seguir
## siendo una cara, no una bola.
func _icono() -> void:
	var ret: Image = Image.load_from_file(RETRATO)
	ret.convert(Image.FORMAT_RGBA8)
	var n := 512
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var centro := Vector2(n * 0.5, n * 0.5)
	for y in n:
		for x in n:
			var d: float = clampf(Vector2(x, y).distance_to(centro) / (n * 0.70), 0.0, 1.0)
			# halo del mismo cian del juego en el centro, fundido al azul del fondo
			img.set_pixel(x, y, Color(0.09, 0.28, 0.40).lerp(FONDO, d * d))
	var usado: Rect2i = ret.get_used_rect()
	var recorte: Image = ret.get_region(usado)
	var k: float = float(n) * 0.80 / float(maxi(usado.size.x, usado.size.y))
	recorte.resize(int(usado.size.x * k), int(usado.size.y * k), Image.INTERPOLATE_LANCZOS)
	var pos := Vector2i((n - recorte.get_width()) / 2, (n - recorte.get_height()) / 2)
	img.blend_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), pos)
	img.save_png(SALIDA + "/icono_512.png")
	for lado in [96, 48]:
		var p: Image = img.duplicate() as Image
		p.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
		p.save_png("%s/prueba_icono_%d.png" % [SALIDA, lado])
	print("icono 512x512 y reducciones a 96 y 48")


# ------------------------------------------------------- grafico destacado
## 1024x500 sin alfa. El mundo 3D del menu detras, el logotipo y TSL-04. Lo
## importante va centrado y con margen: en algunas vistas Google superpone cosas
## en los bordes.
func _destacado() -> void:
	get_window().size = Vector2i(1024, 500)
	await _esperar(8)

	var capa := CanvasLayer.new()
	capa.layer = -1
	add_child(capa)
	var marco := SubViewportContainer.new()
	marco.stretch = true
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(marco)
	var vista := SubViewport.new()
	marco.add_child(vista)
	var mundo := Node3D.new()
	mundo.set_script(load("res://scripts/menu3d.gd"))
	vista.add_child(mundo)
	await _esperar(2)
	# Sin TSL-04 ni su anillo: en el menu son el protagonista, pero aqui quedaban
	# justo debajo del logotipo y saldrian DOS TSL-04 en la misma imagen, el de
	# la escena 3D y el retrato. Se quedan las placas y los paquetes, que son el
	# mundo, y el personaje aparece una sola vez.
	mundo._tsl.visible = false
	mundo._anillo.visible = false

	var lienzo := Control.new()
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lienzo)
	var ret: Image = Image.load_from_file(RETRATO)
	var tex: ImageTexture = ImageTexture.create_from_image(ret)
	lienzo.draw.connect(func():
		var v: Vector2 = lienzo.size
		var f: Font = ThemeDB.fallback_font
		var tam := int(v.y * 0.30)
		var t := "PULSO"
		var an: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var p := Vector2(v.x * 0.36 - an * 0.5, v.y * 0.60)
		# el mismo neon del menu: tres halos cada vez mas tenues y el trazo
		for c in range(3):
			lienzo.draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
				8 + c * 7, Color(CIAN.r, CIAN.g, CIAN.b, 0.10 * (3 - c)))
		lienzo.draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4,
			Color(CIAN.r, CIAN.g, CIAN.b, 0.9))
		lienzo.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.85, 0.98, 1.0))
		var lado: float = v.y * 0.78
		lienzo.draw_texture_rect(tex, Rect2(Vector2(v.x * 0.78 - lado * 0.5,
			v.y * 0.5 - lado * 0.5), Vector2(lado, lado)), false))
	await _esperar(40)
	lienzo.queue_redraw()
	await _esperar(4)
	var img: Image = await _foto()
	if img.get_size() != Vector2i(1024, 500):
		img.resize(1024, 500, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)          # sin alfa: lo pide la especificacion
	img.save_png(SALIDA + "/destacado_1024x500.png")
	print("destacado %s" % str(img.get_size()))
	lienzo.queue_free()
	capa.queue_free()
	await _esperar(4)


# ----------------------------------------------------------------- capturas
func _hace(n: String) -> bool:
	return _solo == "" or _solo == n


func _capturas() -> void:
	get_window().size = Vector2i(1920, 1080)
	await _esperar(8)

	# 1. nivel 1: hacia la IZQUIERDA, donde estan la puerta y el portal. Corriendo
	# a la derecha a ciegas el personaje se tiraba al vacio: el nivel 1 es un
	# archipielago y la primera plataforma se acaba enseguida.
	if _hace("1"):
		var n1: Node2D = await _nivel("res://escenas/niveles/n1_ida_y_vuelta.tscn")
		Input.action_press("mover_izq")
		await _segundos(0.55)
		Input.action_press("saltar")
		await _segundos(0.16)
		await _guardar("captura_1_nivel.png")
		_soltar()
		n1.queue_free()
		await _esperar(6)

	# 2. el pozo del nivel 4: trepando, que es la mecanica que lo distingue
	if _hace("2"):
		var n4: Node2D = await _nivel("res://escenas/niveles/n4_la_chimenea.tscn")
		var j4: CharacterBody2D = n4.get_node("Jugador")
		j4.global_position = Vector2(35.5 * 16.0, 24.0 * 16.0)
		j4.velocity = Vector2.ZERO
		Input.action_press("mover_der")
		await _segundos(1.3)                 # que la camara llegue y el jugador se pegue
		await _guardar("captura_2_chimenea.png")
		_soltar()
		n4.queue_free()
		await _esperar(6)

	# 3. Lasermania, el nivel grande: por su primera calle, con las cortinas
	# cruzandola. Se fotografia cuando la primera esta encendida delante.
	if _hace("3"):
		var n5: Node2D = await _nivel("res://escenas/niveles/n5_lasermania.tscn")
		Input.action_press("mover_der")
		await _segundos(0.45)
		_soltar()
		var l: Node = null
		for p in get_tree().get_nodes_in_group("peligro"):
			if String((p.get_script() as Script).resource_path).ends_with("laser.gd"):
				l = p
				break
		# esperar bailando (ir y volver) a que la primera cortina dispare
		var lado := 1.0
		var t0 := 0.0
		while l != null and l._estado != "dispara" and t0 < 4.0:
			Input.action_press("mover_izq" if lado < 0.0 else "mover_der")
			await _segundos(0.12)
			_soltar()
			lado = -lado
			t0 += 0.12
		await _guardar("captura_3_lasermania.png")
		_soltar()
		n5.queue_free()
		await _esperar(6)

	# 4. el menu principal, con su escena 3D, y 5. la pantalla NIVELES con el
	# progreso de alguien que ya ha jugado: tiempos bajo el par en lima,
	# fragmentos y el personaje abajo. Comparten el menu.
	if _hace("4") or _hace("5"):
		var m: Control = load("res://escenas/MenuPrincipal.tscn").instantiate()
		add_child(m)
		await _segundos(1.8)
		if _hace("4"):
			await _guardar("captura_4_menu.png")
		if _hace("5"):
			Guardado._datos = PROGRESO.duplicate(true)
			var sel: Control = m.get_node("Niveles")
			sel.cambiar_de_verdad = false
			m._panel = "niveles"
			await _segundos(0.7)
			await _guardar("captura_5_niveles.png")
			m._panel = ""
			await _esperar(3)
			Guardado.cargar()
			Guardado.poner_opcion("asistencia", false)
		m.queue_free()
		await _esperar(4)

	# 6. otra celda en marcha: TSL-02 en el nivel 2, con su estela violeta detras.
	# La muestra el JUEGO: se fuerza en memoria el personaje y se corre de verdad.
	# Corre poco: a 250 px/s la primera plataforma se acaba enseguida, y el primer
	# intento salio con TSL-02 cayendose al vacio.
	if _hace("6"):
		Personajes.forzado = "tsl02"
		var n2: Node2D = await _nivel("res://escenas/niveles/n2_el_corredor.tscn")
		Input.action_press("mover_der")
		await _segundos(0.36)
		await _guardar("captura_6_personajes.png")
		_soltar()
		n2.queue_free()
		Personajes.forzado = Personajes.BASE
		await _esperar(6)


func _nivel(ruta: String) -> Node2D:
	var n: Node2D = load(ruta).instantiate() as Node2D
	add_child(n)
	await _esperar(3)
	var j: CharacterBody2D = n.get_node("Jugador")
	# Invulnerable SIN parpadear: con la gracia normal parpadea (y saldria
	# medio transparente en la foto); con _celebrando la gracia no se anuncia.
	j._celebrando = true
	j._t_gracia = 999.0
	j.modulate.a = 1.0
	return n


func _soltar() -> void:
	for a in ["mover_der", "mover_izq", "saltar"]:
		Input.action_release(a)


func _guardar(nombre: String) -> void:
	var img: Image = await _foto()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s" % [SALIDA, nombre])
	print("%s %s" % [nombre, str(img.get_size())])


func _foto() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _esperar(cuadros: int) -> void:
	for i in cuadros:
		await get_tree().process_frame


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout
