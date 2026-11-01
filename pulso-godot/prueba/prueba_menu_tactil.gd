extends Node
## El menu principal con el DEDO (y con raton), y el boton atras de Android.
##
## Hasta ahora el menu solo leia teclado: en un telefono no se podia pulsar
## JUGAR. Aqui los toques entran como los manda el sistema, por
## Input.parse_input_event, y eso trae dos cosas de verdad que hay que medir:
##  * cada toque llega DOS veces (el clic que Godot emula y el toque), y solo
##    puede contar una;
##  * el toque entra por la VENTANA, asi que el punto se pasa de coordenadas del
##    juego (640x360) a las de la ventana, o cae en otra parte y la prueba no
##    mide nada (le paso a la prueba de la pausa).
##
## Pulsar JUGAR cambia de escena de verdad: para sobrevivir, la prueba deja de
## ser la escena actual y el menu ocupa ese sitio.

const MENU := "res://escenas/MenuPrincipal.tscn"
const INTRO := "res://escenas/CineIntro.tscn"
const N1 := "res://escenas/niveles/n1_ida_y_vuelta.tscn"

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false
var menu: Control


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

	_ok(ProjectSettings.get_setting("application/config/quit_on_go_back") == false,
		"quit_on_go_back es false: atras le llega al juego y no cierra la app")
	# 16:9 de movil, 19,5:9 de movil ancho, y 4:3 de tablet (ahi crece el ALTO)
	for tam in [Vector2i(640, 360), Vector2i(780, 360), Vector2i(640, 480)]:
		await _geometria(tam)
	await _montar_menu()
	await _opciones_y_creditos()
	await _arrepentirse()
	await _mantener_salir()
	await _dedos_raros()
	await _raton()
	await _atras()
	await _jugar_y_la_intro()
	_fin()


# ------------------------------------------------------------------ ayudas
func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _a_ventana(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _toque(p: Vector2, pulsado: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = _a_ventana(p)
	t.pressed = pulsado
	Input.parse_input_event(t)
	await _cuadros(2)


func _tocar(p: Vector2) -> void:
	await _toque(p, true)
	await _toque(p, false)


func _arrastrar(p: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = _a_ventana(p)
	Input.parse_input_event(d)
	await _cuadros(2)


func _centro(i: int) -> Vector2:
	return (menu.caja_fila(i) as Rect2).get_center()


# ---------------------------------------------------------------- medidas
func _geometria(tam: Vector2i) -> void:
	var ancho := "%dx%d" % [tam.x, tam.y]
	var vista := SubViewport.new()
	vista.size = tam
	add_child(vista)
	var m: Control = load(MENU).instantiate()
	vista.add_child(m)
	await _cuadros(3)
	var v := Vector2(tam)
	var f: Font = ThemeDB.fallback_font
	var altas := true
	var dentro := true
	var sin_huecos := true
	for i in m.OPCIONES.size():
		var r: Rect2 = m.caja_fila(i)
		if r.size.y < 46.0:
			altas = false
		if not Rect2(Vector2.ZERO, v).encloses(m.caja_panel()):
			dentro = false
		if m.fila_en(r.get_center()) != i:
			sin_huecos = false
		# el punto medio del hueco con la siguiente tambien cuenta para alguna
		if i < m.OPCIONES.size() - 1:
			var hueco_y: float = r.end.y + m.FILA_HUECO * 0.5 - 0.5
			if m.fila_en(Vector2(r.get_center().x, hueco_y)) < 0:
				sin_huecos = false
	_ok(altas, "a %s: las cuatro filas miden al menos 46 px (las de la pausa)" % ancho)
	_ok(dentro, "a %s: el panel cabe en la pantalla (acaba en %.0f de %.0f)"
		% [ancho, (m.caja_panel() as Rect2).end.y, v.y])
	_ok(sin_huecos, "a %s: cada fila responde en su centro y entre filas no hay zona muerta" % ancho)
	_ok(m.fila_en(Vector2(10, 180)) == -1, "a %s: fuera del panel no se toca ninguna fila" % ancho)
	# El panel no pisa el logotipo. Lo que ocupa "PULSO" por debajo de su linea
	# base (0,30 del alto) es solo su halo: el mas ancho es un contorno de 16 px,
	# o sea 8 por fuera de la letra. No el "descenso" de la fuente, que es el
	# hueco para letras con rabo, y PULSO no tiene ninguna.
	var fondo_logo: float = v.y * 0.30 + 8.0
	_ok((m.caja_panel() as Rect2).position.y >= fondo_logo,
		"a %s: el panel empieza debajo del logotipo (%.0f >= %.0f)"
		% [ancho, (m.caja_panel() as Rect2).position.y, fondo_logo])
	# el aviso de atras, junto a SALIR, cabe en la pantalla
	var fin_aviso: float = (m.caja_fila(3) as Rect2).end.x + 32.0 + f.get_string_size(
		"Atrás otra vez para salir", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_ok(fin_aviso <= v.x - 4.0, "a %s: el aviso de atras cabe junto a SALIR" % ancho)
	# el pie de CONTROLES con la pista tactil cabe
	var c: Control = m.get_node("Controles")
	var peor := 0.0
	for args in [[false, false, true], [false, true, true], [true, false, false]]:
		peor = maxf(peor, c.ancho_partes(c.partes_pie(args[0], args[1], args[2])))
	_ok(peor <= (c.caja_pie() as Rect2).size.x,
		"a %s: el pie de CONTROLES con 'o toca fuera' cabe (%.0f de %.0f)"
		% [ancho, peor, (c.caja_pie() as Rect2).size.x])
	# TSL-04 mira a la fila con dos numeros que el menu le MIDE de sus filas: en
	# cualquier tamano tienen que caer justo donde estan las filas de verdad
	var mundo: Node3D = m.get_node("Escena3D/Marco/Vista/Mundo")
	var casa := true
	for i in m.OPCIONES.size():
		var frac: float = (m.caja_fila(i) as Rect2).get_center().y / (v.y * 0.5) - 1.0
		if absf(frac - (mundo.fila_primera + mundo.fila_paso * float(i))) > 0.002:
			casa = false
	_ok(casa, "a %s: TSL-04 mira justo a cada fila" % ancho)
	if tam == Vector2i(640, 360):
		_ok(absf(mundo.fila_primera - mundo.FILA_PRIMERA) < 0.002
			and absf(mundo.fila_paso - mundo.FILA_PASO) < 0.002,
			"y en 16:9 coincide con los valores de partida de menu3d.gd")
	vista.queue_free()
	await _cuadros(1)


# ------------------------------------------------------------- con el dedo
func _montar_menu() -> void:
	menu = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	menu.cerrar_de_verdad = false
	await _cuadros(4)


func _opciones_y_creditos() -> void:
	var c: Control = menu.get_node("Controles")
	await _tocar(_centro(1))
	_ok(menu.sel == 1 and menu._panel == "controles", "tocar OPCIONES abre CONTROLES")
	await _cuadros(2)
	_ok(c.abierto, "y la pantalla esta abierta de verdad")
	await _tocar(Vector2(20, 180))
	_ok(not c.abierto and menu._panel == "", "tocar fuera del panel vuelve al menu")
	await _tocar(_centro(2))
	_ok(menu._panel == "creditos", "tocar CREDITOS los abre")
	# Justo encima de la fila de CREDITOS: si el toque contara doble (el clic
	# emulado y el toque), el primero cerraria y el segundo los volveria a abrir.
	await _tocar(_centro(2))
	await _cuadros(2)
	_ok(menu._panel == "", "un toque los cierra, y no los vuelve a abrir el mismo toque")


func _arrepentirse() -> void:
	await _toque(_centro(2), true)
	_ok(menu.sel == 2, "poner el dedo en una fila la elige")
	await _arrastrar(_centro(0))
	await _toque(_centro(0), false)
	await _cuadros(2)
	_ok(menu._panel == "" and get_tree().current_scene == menu,
		"si el dedo se va a otra fila antes de levantarlo, no se activa nada")


func _mantener_salir() -> void:
	var mundo: Node3D = menu.get_node("Escena3D/Marco/Vista/Mundo")
	await _toque(_centro(3), true)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_ok(menu.sel == 3 and menu._reten > 0.6, "mantener el dedo en SALIR llena la retencion (%.2f s)" % menu._reten)
	_ok(mundo._p_adios > 0.1, "y TSL-04 se va despidiendo (%.2f)" % mundo._p_adios)
	await _arrastrar(_centro(0))
	_ok(menu._reten == 0.0 and not menu.salio, "si el dedo se sale de SALIR, se suelta y no sale")
	await _toque(_centro(0), false)
	await _toque(_centro(3), true)
	await get_tree().create_timer(3.3, true, false, true).timeout
	_ok(menu.salio, "y mantenido 3 s, sale")
	await _toque(_centro(3), false)
	menu.salio = false
	menu._reten = 0.0


## Lo que encontro la revision: dedos que no son el 0, sueltas que llegan con un
## panel abierto, toques que cancela el sistema y perder el foco con el dedo
## puesto.
func _dedos_raros() -> void:
	await _toque_i(1, _centro(1), true)
	await _toque_i(1, _centro(1), false)
	await _cuadros(2)
	_ok(menu._panel == "controles", "un dedo que no es el 0 tambien abre (en Android el index es del sistema)")
	await _tocar(Vector2(20, 180))
	# solo manda el primer dedo: un segundo dedo no activa nada a medias
	await _toque_i(0, _centro(2), true)
	await _toque_i(1, _centro(1), true)
	await _toque_i(1, _centro(1), false)
	_ok(menu._panel == "", "con un dedo puesto, otro dedo no activa nada")
	await _toque_i(0, _centro(2), false)
	_ok(menu._panel == "creditos", "y el primero sigue mandando")
	await _tocar(Vector2(320, 180))
	# la suelta que llega con un panel abierto tambien suelta el dedo
	await _toque(_centro(3), true)
	menu._panel = "creditos"
	await _toque(_centro(3), false)
	_ok(menu._dedo_fila == -1 and menu._dedo_indice == -1,
		"soltar con un panel abierto libera el dedo igual")
	menu._panel = ""
	menu.sel = 3
	await get_tree().create_timer(0.5, true, false, true).timeout
	_ok(menu._reten == 0.0 and not menu.salio, "y SALIR no se llena solo al volver al menu")
	# toque cancelado por el sistema: no es levantar el dedo
	await _toque(_centro(2), true)
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = _a_ventana(_centro(2))
	t.pressed = false
	t.canceled = true
	Input.parse_input_event(t)
	await _cuadros(2)
	_ok(menu._panel == "" and menu._dedo_indice == -1,
		"un toque cancelado por el sistema no activa nada y libera el dedo")
	# perder el foco con el dedo en SALIR
	await _toque(_centro(3), true)
	await get_tree().create_timer(0.4, true, false, true).timeout
	menu._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _cuadros(2)
	_ok(menu._reten == 0.0 and menu._dedo_indice == -1,
		"perder el foco con el dedo en SALIR lo suelta y vacia la retencion")
	await _toque(_centro(3), false)
	menu.sel = 0
	menu._elegir_fila(0)


func _toque_i(indice: int, p: Vector2, pulsado: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = indice
	t.position = _a_ventana(p)
	t.pressed = pulsado
	Input.parse_input_event(t)
	await _cuadros(2)


func _raton() -> void:
	var m := InputEventMouseMotion.new()
	m.position = _a_ventana(_centro(2))
	Input.parse_input_event(m)
	await _cuadros(2)
	_ok(menu.sel == 2, "con raton, pasar por encima de una fila la elige")
	var emu := InputEventMouseMotion.new()
	emu.device = InputEvent.DEVICE_ID_EMULATION
	emu.position = _a_ventana(_centro(0))
	Input.parse_input_event(emu)
	await _cuadros(2)
	_ok(menu.sel == 2, "el movimiento que Godot emula de un dedo no elige nada")
	for pulsado in [true, false]:
		var rueda := InputEventMouseButton.new()
		rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
		rueda.position = _a_ventana(_centro(1))
		rueda.pressed = pulsado
		Input.parse_input_event(rueda)
		await _cuadros(2)
	_ok(menu._panel == "", "la rueda encima de OPCIONES no la abre")


func _atras() -> void:
	menu._panel = "creditos"
	await _cuadros(2)
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(menu._panel == "", "atras cierra el panel abierto")
	menu._panel = "controles"
	await _cuadros(3)
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _cuadros(2)
	_ok(menu._panel == "" and not (menu.get_node("Controles") as Control).abierto,
		"y tambien la pantalla de controles")
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(menu.sel == 3 and not menu.salio, "en el menu, el primer atras lleva a SALIR y no sale")
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(menu.salio, "el segundo, antes de 2 s, sale")
	menu.salio = false
	await get_tree().create_timer(2.2, true, false, true).timeout
	menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(not menu.salio, "pasados 2 s, vuelve a hacer falta pulsar dos veces")
	await get_tree().create_timer(2.2, true, false, true).timeout


func _jugar_y_la_intro() -> void:
	_ok(load("res://scripts/cine.gd").texto_saltar(true) == "Toca para saltar"
		and load("res://scripts/cine.gd").texto_saltar(false) == "Espacio para saltar",
		"la intro dice 'Toca para saltar' con pantalla tactil, 'Espacio' sin ella")
	# sin progreso, JUGAR va directo a la intro (con progreso abre NIVELES, que
	# mide prueba/selector); el archivo real se devuelve al final
	Guardado._datos["max_nivel"] = 1
	await _tocar(_centro(0))
	await _cuadros(4)
	var cine: Node = get_tree().current_scene
	_ok(cine != null and cine.scene_file_path == INTRO, "tocar JUGAR empieza la intro")
	if cine == null or cine.scene_file_path != INTRO:
		return
	# el toque que entro en JUGAR no puede saltarse la intro
	await _tocar(Vector2(320, 180))
	_ok(not cine.acabo, "un toque nada mas empezar no salta la intro (espera 0,8 s)")
	await get_tree().create_timer(0.9, true, false, true).timeout
	await _tocar(Vector2(320, 180))
	await _cuadros(4)
	var nivel: Node = get_tree().current_scene
	_ok(nivel != null and nivel.scene_file_path == N1, "pasados 0,8 s, un toque la salta al nivel 1")
	if nivel != null:
		nivel.queue_free()
		await _cuadros(2)
	# y atras tambien la salta
	var otra: Control = load(INTRO).instantiate()
	add_child(otra)
	otra.siguiente = "res://no_existe.tscn"         # que no cambie de escena
	await _cuadros(2)
	otra._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(otra.acabo, "el boton atras tambien salta la intro")
	otra.queue_free()


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
	Teclas.aplicar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA MENU TACTIL OK")
	get_tree().quit()
