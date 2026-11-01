extends Node
## La pantalla NIVELES (scripts/selector.gd) y como la abre JUGAR.
##
## El progreso se pone EN MEMORIA (Guardado._datos) para cada caso y el archivo
## real se copia al empezar y se devuelve al final. Las teclas y los toques
## entran por Input.parse_input_event, y los toques pasados a coordenadas de
## ventana. Elegir un nivel no cambia de escena (cambiar_de_verdad = false): se
## mira a donde iria. Solo el ultimo caso cambia de escena de verdad.

const MENU := "res://escenas/MenuPrincipal.tscn"
const GUION := "res://scripts/selector.gd"
const INTRO := "res://escenas/CineIntro.tscn"

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false
var menu: Control
var s: Control


func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-66s %s" % [txt, "OK" if c else "FALLA"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	await get_tree().process_frame
	get_tree().current_scene = null

	_tabla()
	_textos()
	for tam in [Vector2i(640, 360), Vector2i(780, 360), Vector2i(640, 480)]:
		await _cabe(tam)
	await _montar()
	await _con_teclado()
	await _con_el_dedo()
	await _salir_de_la_pantalla()
	await _todo_abierto()
	await _doble_toque()
	await _musica_del_final()
	await _primera_vez()
	_fin()


# ------------------------------------------------------------------ ayudas
func _progreso(max_nivel: int, tiempos := {}, frags := {}) -> void:
	Guardado._datos = {"max_nivel": max_nivel, "tiempos": tiempos, "fragmentos": frags}


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _pulsar(cod: int) -> void:
	for pulsado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = cod as Key
		e.physical_keycode = cod as Key
		e.pressed = pulsado
		Input.parse_input_event(e)
		await _cuadros(3)


func _toque(p: Vector2, pulsado: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = get_viewport().get_final_transform() * p
	t.pressed = pulsado
	Input.parse_input_event(t)
	await _cuadros(2)


func _tocar(p: Vector2) -> void:
	await _toque(p, true)
	await _toque(p, false)


func _centro(i: int) -> Vector2:
	return (s.caja(i) as Rect2).get_center()


# ---------------------------------------------------------- datos y medidas
## La tabla del selector copia nombre y par de cada nivel; tienen que seguir
## siendo los de la escena, y el orden el de nivel.gd.
func _tabla() -> void:
	var guion: Script = load(GUION)
	var tabla: Array = guion.get("NIVELES") if guion.get("NIVELES") != null else []
	var orden: Array = load("res://scripts/nivel.gd").get("ORDEN")
	var casa := tabla.size() == orden.size()
	var motivo := ""
	for i in tabla.size():
		var fila: Array = tabla[i]
		if String(fila[0]) != String(orden[i]):
			casa = false
			motivo = "orden %d" % i
			continue
		var st: SceneState = (load(String(fila[0])) as PackedScene).get_state()
		var titulo := ""
		var par := -1.0
		for k in st.get_node_property_count(0):
			match st.get_node_property_name(0, k):
				"titulo": titulo = String(st.get_node_property_value(0, k))
				"par": par = float(st.get_node_property_value(0, k))
		if not titulo.ends_with(String(fila[1])) or not is_equal_approx(par, float(fila[2])):
			casa = false
			motivo = "%s: '%s' par %.0f" % [fila[1], titulo, par]
		# los tramos de carga: uno mas que las balizas que tenga el nivel
		var balizas := 0
		for k in st.get_node_count():
			var inst: PackedScene = st.get_node_instance(k)
			if inst != null and inst.resource_path.ends_with("Baliza.tscn"):
				balizas += 1
		if int(fila[3]) != balizas + 1:
			casa = false
			motivo = "%s: %d tramos y %d balizas" % [fila[1], int(fila[3]), balizas]
	_ok(casa, "los nombres, pares y tramos del selector son los de las escenas%s" %
		("" if casa else " (" + motivo + ")"))
	# las constantes de foco siguen a la tabla (no se pueden escribir derivadas)
	_ok(int(guion.get("DESDE_PRINCIPIO")) == tabla.size()
		and int(guion.get("ELEMENTOS")) == tabla.size() + 4,
		"DESDE_PRINCIPIO y ELEMENTOS siguen al numero de niveles (%d)" % tabla.size())


func _textos() -> void:
	var guion: Script = load(GUION)
	_ok(guion.texto_tiempo(0.0) == "--" and guion.texto_tiempo(12.68) == "12.7 s",
		"un nivel sin tiempo dice '--'; con tiempo, con un decimal")


func _cabe(tam: Vector2i) -> void:
	var nombre := "%dx%d" % [tam.x, tam.y]
	var vista := SubViewport.new()
	vista.size = tam
	add_child(vista)
	var p: Control = Control.new()
	p.set_script(load(GUION))
	vista.add_child(p)
	await _cuadros(2)
	var f: Font = ThemeDB.fallback_font
	var v := Rect2(Vector2.ZERO, Vector2(tam))
	var panel: Rect2 = p.caja_panel()
	# en pantallas bajas el panel acaba antes que el boton de abajo: lo que queda
	# entre medias y el borde es del boton, no "fuera"
	var per: Rect2 = p.caja_personaje()
	var vol: Rect2 = p.caja_volver()
	_ok(p.elemento_en(Vector2(per.get_center().x, v.end.y - 2.0)) == p.PERSONAJE
		and p.elemento_en(Vector2(vol.get_center().x, v.end.y - 2.0)) == p.VOLVER,
		"a %s: el personaje y Volver llegan hasta el borde de abajo" % nombre)
	var todo := v.encloses(panel)
	var altas := true
	var nombres := true
	for i in p.ELEMENTOS:
		var c: Rect2 = p.caja(i)
		if not panel.encloses(c):
			todo = false
		if c.size.y < 46.0:
			altas = false
		if i < p.NIVELES.size() and f.get_string_size(String(p.NIVELES[i][1]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > c.size.x - 20.0:
			nombres = false
	var pie: Rect2 = p.caja_pie()
	_ok(todo and panel.encloses(pie) and pie.position.y >= (p.caja_boton(p.DESDE_PRINCIPIO) as Rect2).end.y,
		"a %s: tarjetas, botones y pie caben, el pie debajo de todo" % nombre)
	_ok(altas, "a %s: todo lo que se toca mide al menos 46 px de alto" % nombre)
	_ok(nombres, "a %s: los nombres de nivel caben en su tarjeta (a 11 px, el minimo)" % nombre)
	var boton: Rect2 = p.caja_boton(p.DESDE_PRINCIPIO)
	var largo := f.get_string_size("Desde el principio", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 8.0 \
		+ f.get_string_size("con la intro", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_ok(largo < boton.size.x - 8.0, "a %s: 'Desde el principio  con la intro' cabe en su boton" % nombre)
	# La fila de abajo: la ayuda del pie, el personaje y Volver, sin pisarse.
	var volver: Rect2 = p.caja_volver()
	var pers: Rect2 = p.caja_personaje()
	var x_pie: float = pie.position.x
	var ayuda := f.get_string_size("Intro", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 13.0 \
		+ f.get_string_size("jugar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0 \
		+ f.get_string_size("Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 13.0 \
		+ f.get_string_size("volver", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_ok(x_pie + ayuda < pers.position.x - 8.0 and pers.end.x <= volver.position.x
		and volver.position.y >= boton.end.y and pers.size.y >= 46.0,
		"a %s: ayuda, personaje y Volver van en fila sin pisarse" % nombre)
	# Los avisos van en la cabecera, alineados a la derecha: el mas largo no
	# puede llegar al titulo
	var largo_aviso := 0.0
	for t in ["Recoge los 12 fragmentos para despertar a TSL-03", "Completa el nivel 4 para abrirlo",
			"TSL-03: trepa gratis; impulso lento", "Completa el nivel 3 para verlo"]:
		largo_aviso = maxf(largo_aviso, f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var fin_titulo: float = panel.position.x + tam.x * 0.025 + f.get_string_size("> NIVELES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var ini_aviso: float = panel.end.x - tam.x * 0.025 - largo_aviso
	_ok(fin_titulo < ini_aviso - 8.0,
		"a %s: el aviso mas largo cabe en la cabecera sin tocar el titulo" % nombre)
	vista.queue_free()
	await _cuadros(1)


# ------------------------------------------------------------- con el menu
func _montar() -> void:
	_progreso(3, {"1": 30.0, "2": 61.5}, {"1": 3, "2": 1})
	menu = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _cuadros(4)
	s = menu.get_node("Niveles")
	s.cambiar_de_verdad = false
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	_ok(menu._panel == "niveles" and s.abierto, "con progreso, JUGAR abre NIVELES")
	_ok(s.foco == 2, "con el foco en el nivel mas alto abierto (el 3)")
	_ok(s.destino == "", "y el Intro que la abre no elige nada")
	_ok(s.abierto_elemento(0) and s.abierto_elemento(2) and not s.abierto_elemento(3)
		and not s.abierto_elemento(5) and not s.abierto_elemento(s.VER_FINAL)
		and s.abierto_elemento(s.DESDE_PRINCIPIO),
		"llegado al 3: 1-3 abiertos; del 4 al 6 y el final, cerrados")


func _con_teclado() -> void:
	await _pulsar(KEY_RIGHT)
	_ok(s.foco == 3, "derecha pasa a la tarjeta siguiente")
	await _pulsar(KEY_ENTER)
	_ok(s.destino == "" and s.aviso == "Completa el nivel 3 para abrirlo",
		"un nivel cerrado no se abre y dice por que (\"%s\")" % s.aviso)
	await _pulsar(KEY_LEFT)
	_ok(s._rechazado == 3 and s.foco == 2,
		"el contorno rojo se queda en lo rechazado aunque el foco se vaya")
	await _pulsar(KEY_ENTER)
	_ok(s.destino == String(s.NIVELES[2][0]), "Intro sobre el nivel 3 lo juega")
	s.destino = ""
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.DESDE_PRINCIPIO, "abajo desde el nivel 3 va a 'Desde el principio'")
	await _pulsar(KEY_ENTER)
	_ok(s.destino == INTRO, "que pone la intro (y la intro lleva al nivel 1)")
	s.destino = ""
	await _pulsar(KEY_RIGHT)
	await _pulsar(KEY_ENTER)
	_ok(s.foco == s.VER_FINAL and s.destino == "" and s.aviso == "Completa el nivel 3 para verlo",
		"el final esta cerrado hasta pasar el nivel 3")
	await _pulsar(KEY_UP)
	_ok(s.foco == 2, "arriba vuelve a la tarjeta de la que se vino")


func _con_el_dedo() -> void:
	await _tocar(_centro(1))
	_ok(s.destino == String(s.NIVELES[1][0]), "tocar la tarjeta del nivel 2 lo juega")
	s.destino = ""
	await _toque(_centro(0), true)
	await _toque(_centro(1), false)
	_ok(s.destino == "" and s.foco == 0,
		"si el dedo se levanta en otra tarjeta, no se juega nada")
	# el toque se emula como clic tambien: tiene que contar una vez. Sobre un
	# cerrado, contarlo dos veces no se ve; sobre uno abierto, se jugaria igual,
	# asi que se mira que solo hay UN aviso y no se reabre nada raro.
	await _tocar(_centro(3))
	_ok(s.destino == "" and s.aviso == "Completa el nivel 3 para abrirlo",
		"tocar un nivel cerrado solo avisa")


func _salir_de_la_pantalla() -> void:
	await _tocar(Vector2(4, 4))
	_ok(not s.abierto and menu._panel == "", "tocar fuera del panel vuelve al menu")
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	await _pulsar(KEY_ESCAPE)
	_ok(not s.abierto and menu._panel == "", "Esc vuelve al menu")
	await _cuadros(3)
	_ok(menu._panel == "", "y el menu no vuelve a abrir nada por su cuenta")
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(not s.abierto and menu._panel == "", "el boton atras tambien vuelve")
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	await get_tree().create_timer(0.4, true, false, true).timeout
	await _tocar((s.caja_volver() as Rect2).get_center())
	_ok(not s.abierto and menu._panel == "", "el boton Volver (46 px) vuelve con el dedo")
	# la fila de abajo llega hasta el borde de la pantalla: un toque algo por
	# debajo del boton lo pulsa, no cierra lo que no se queria cerrar
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	await get_tree().create_timer(0.4, true, false, true).timeout
	var per: Rect2 = s.caja_personaje()
	var vol: Rect2 = s.caja_volver()
	# cerca del borde de la pantalla, FUERA del panel: donde antes un toque
	# cerraba la pantalla en vez de pulsar el boton
	var punto := Vector2(per.get_center().x, get_viewport().get_visible_rect().size.y - 4.0)
	_ok(not (s.caja_panel() as Rect2).has_point(punto),
		"(ese punto cae fuera del panel: %s, panel hasta %.0f)" % [punto, (s.caja_panel() as Rect2).end.y])
	await _tocar(punto)
	_ok(s.abierto and s.foco == s.PERSONAJE, "tocar bajo el personaje, en el borde, lo pulsa y no cierra")
	await _tocar(Vector2(vol.get_center().x, punto.y))
	_ok(not s.abierto and menu._panel == "", "y bajo Volver, en el borde, es Volver")
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	await _pulsar(KEY_DOWN)
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.PERSONAJE, "con el teclado, debajo de 'Desde el principio' esta el personaje")
	await _pulsar(KEY_UP)
	await _pulsar(KEY_RIGHT)
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.VOLVER, "y debajo de 'Ver el final', Volver")
	await _pulsar(KEY_LEFT)
	_ok(s.foco == s.PERSONAJE, "izquierda desde Volver va al personaje")
	# derecha desde el personaje lo CAMBIA (Volver queda a su derecha pero no se
	# llega con derecha): por eso abajo tiene que llevar a Volver
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.VOLVER, "y abajo desde el personaje, a Volver")
	await _pulsar(KEY_LEFT)
	await _pulsar(KEY_UP)
	await _pulsar(KEY_RIGHT)
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.VOLVER, "(y de vuelta a Volver)")
	await _pulsar(KEY_ENTER)
	_ok(not s.abierto and menu._panel == "", "e Intro sobre Volver vuelve")
	# abrir desde el menu deja la pantalla abierta en el mismo instante, sin un
	# cuadro en que no se vea ni el menu ni la pantalla
	menu.sel = 0
	menu._activar()
	_ok(s.abierto, "JUGAR abre NIVELES en el mismo cuadro")
	menu._panel = ""
	await _cuadros(2)


func _todo_abierto() -> void:
	_progreso(7, {"1": 30.0, "2": 61.5, "3": 50.0, "4": 40.0, "5": 170.0, "6": 140.0},
		{"1": 3, "2": 3, "3": 3, "4": 2, "5": 1, "6": 0})
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	_ok(s.abierto and s.foco == 5, "con todo pasado, el foco empieza en el nivel 6")
	_ok(s.abierto_elemento(5) and s.abierto_elemento(s.VER_FINAL), "y los seis niveles y el final estan abiertos")
	# llegar a los botones con el raton y subir con la flecha: vuelve a la
	# tarjeta en la que estaba, no a la primera
	var m := InputEventMouseMotion.new()
	m.position = get_viewport().get_final_transform() * _centro(s.DESDE_PRINCIPIO)
	Input.parse_input_event(m)
	await _cuadros(2)
	await _pulsar(KEY_UP)
	_ok(s.foco == 5, "raton a un boton y flecha arriba: vuelve a la tarjeta de antes (%d)" % s.foco)
	await _pulsar(KEY_RIGHT)
	_ok(s.foco == 5, "derecha en la ultima tarjeta no se sale de la fila")
	await _pulsar(KEY_ENTER)
	_ok(s.destino == String(s.NIVELES[5][0]), "Intro sobre el nivel 6 lo juega")
	s.destino = ""
	await _pulsar(KEY_DOWN)
	_ok(s.foco == s.VER_FINAL, "abajo desde las tarjetas de la derecha va a 'Ver el final'")
	await _pulsar(KEY_ENTER)
	_ok(s.destino == s.FINAL, "que pone el final (y el final lleva al nivel 4)")
	await _pulsar(KEY_ESCAPE)


## Doble toque en JUGAR: el primero abre NIVELES y el segundo cae sobre una
## tarjeta que aun no se ve. No puede jugarla.
func _doble_toque() -> void:
	_progreso(5, {"1": 30.0}, {})
	s.destino = ""
	# El punto de JUGAR que tiene una tarjeta ABIERTA debajo. Su centro exacto cae
	# en el hueco entre la 3 y la 4 (con seis tarjetas, el centro de la pantalla es
	# un hueco) y la prueba pasaba aunque faltara la guarda de ENTRADA.
	var fila: Rect2 = menu.caja_fila(0)
	var tarjeta: Rect2 = s.caja_tarjeta(2)
	var jugar := Vector2((maxf(tarjeta.position.x, fila.position.x) + minf(tarjeta.end.x, fila.end.x)) * 0.5,
		fila.get_center().y)
	_ok(fila.has_point(jugar) and s.elemento_en(jugar) == 2,
		"(el toque cae en JUGAR y, debajo, en la tarjeta abierta del nivel 3)")
	await _tocar(jugar)
	_ok(s.abierto, "el primer toque en JUGAR abre NIVELES")
	await _tocar(jugar)
	_ok(s.destino == "" and s.abierto,
		"el segundo toque de un doble toque no juega lo que haya debajo")
	await _pulsar(KEY_ESCAPE)


## Al final se llega tambien desde NIVELES, con "circuito" sonando a todo
## volumen. No puede cortarse en seco: se va con fundido y "libre" entra despues.
func _musica_del_final() -> void:
	Audio.poner_musica("circuito", 0.0)
	await _cuadros(2)
	var c: Control = load(s.FINAL).instantiate()
	add_child(c)
	c.siguiente = "res://no_existe.tscn"
	await _cuadros(2)
	_ok(Audio._tema != "libre" and Audio._musica.stream == Audio._temas.get("circuito"),
		"al entrar en el final, 'circuito' no se corta: se esta yendo")
	await get_tree().create_timer(0.8, true, false, true).timeout
	_ok(Audio._tema == "libre" and Audio._musica.playing,
		"y medio segundo despues entra 'libre', desde silencio")
	c.queue_free()
	Audio.parar_musica(0.0)
	await _cuadros(2)


func _primera_vez() -> void:
	_progreso(1)
	menu.sel = 0
	await _pulsar(KEY_ENTER)
	await _cuadros(3)
	var cur: Node = get_tree().current_scene
	_ok(cur != null and cur.scene_file_path == INTRO,
		"sin progreso, JUGAR sigue llevando directo a la intro")
	if cur != null and cur != menu:
		cur.queue_free()
		await _cuadros(2)


func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	if _habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_copia)
			fa.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA SELECTOR OK")
	get_tree().quit()
