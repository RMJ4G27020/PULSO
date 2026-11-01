extends Node
## La pantalla CONTROLES (scripts/controles.gd) con teclas DE VERDAD.
##
## Las teclas entran por Input.parse_input_event, como las de un teclado, y no
## llamando a funciones: lo que se protege es justo lo que pasa entre una tecla
## y otra. Que la tecla que se asigna no haga ademas lo suyo (la flecha abajo
## mover el foco, el Esc que cancela cerrar tambien la pantalla, el Intro
## asignado volver a empezar la escucha), que la escucha no se quede colgada, y
## que todo quepa en 640 y en 780 de ancho.
##
## Escribe en el progreso DE VERDAD: se copia al empezar y se devuelve al final.

const MENU := "res://escenas/MenuPrincipal.tscn"
const GUION := "res://scripts/controles.gd"

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false
var menu: Control
var c: Control


func _ok(cond: bool, txt: String) -> void:
	if not cond: fallos += 1
	print("  %-66s %s" % [txt, "OK" if cond else "FALLA"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Guardado.poner_opcion("teclas", {})
	Teclas.aplicar()

	for ancho in [640, 780]:
		await _cabe(ancho)
	await _abrir()
	await _navegar()
	await _asignar()
	await _cancelar_y_cerrar()
	await _lo_que_no_es_tecla()
	await _se_acaba_sola()
	await _quitar()
	await _restaurar()
	await _raton_y_toque()
	_fin()


# ------------------------------------------------------------------ teclas
func _ev(cod: int, pulsado: bool, eco := false) -> void:
	var e := InputEventKey.new()
	e.keycode = cod as Key
	e.physical_keycode = cod as Key
	e.pressed = pulsado
	e.echo = eco
	Input.parse_input_event(e)


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _pulsar(cod: int) -> void:
	_ev(cod, true)
	await _cuadros(3)
	_ev(cod, false)
	await _cuadros(3)


func _codigos(accion: String) -> Array[int]:
	var r: Array[int] = []
	for k in Teclas.de(accion):
		r.append(Teclas.codigo(k))
	return r


func _ir_a(fila: int) -> void:
	var vueltas := 0
	while c.fila != fila and vueltas < 12:
		await _pulsar(KEY_DOWN)
		vueltas += 1


# ---------------------------------------------------------------- que cabe
## En un SubViewport del ancho pedido: las cajas se miden con
## get_viewport_rect(), asi que la pantalla se coloca sola como en ese movil.
func _cabe(ancho: int) -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(ancho, 360)
	add_child(vista)
	var p: Control = Control.new()
	p.set_script(load(GUION))
	vista.add_child(p)
	await _cuadros(2)
	var f: Font = ThemeDB.fallback_font
	var v := Rect2(Vector2.ZERO, Vector2(ancho, 360))
	var panel: Rect2 = p.caja_panel()
	var dentro := v.encloses(panel)
	var filas_ok := true
	var ranuras_ok := true
	var rotulos_ok := true
	var peor_rotulo := -INF
	for i in Teclas.ACCIONES.size() + 1:
		var fi: Rect2 = p.caja_fila(i)
		if not panel.encloses(fi):
			filas_ok = false
		for k in Teclas.MAX:
			if not fi.encloses(p.caja_ranura(i, k)):
				ranuras_ok = false
		var rot: String = Teclas.ROTULOS[p.accion_de(i)]
		var x_fin: float = fi.position.x + ancho * 0.025 + f.get_string_size(rot,
			HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_ROTULO).x
		peor_rotulo = maxf(peor_rotulo, x_fin - (p.caja_ranura(i, 0).position.x - 4.0))
		if x_fin > p.caja_ranura(i, 0).position.x - 4.0:
			rotulos_ok = false
	var res: Rect2 = p.caja_restaurar()
	var pie: Rect2 = p.caja_pie()
	_ok(dentro and filas_ok and panel.encloses(res) and panel.encloses(pie),
		"a %d px: panel, filas, Restaurar y pie caben" % ancho)
	_ok(res.position.y >= p.caja_fila(p.FILA_PAUSA).end.y + 9.0 and pie.position.y >= res.end.y,
		"a %d px: Restaurar va separado de las acciones y el pie debajo" % ancho)
	_ok(ranuras_ok, "a %d px: las tres ranuras caben en cada fila" % ancho)
	_ok(rotulos_ok, "a %d px: ningun nombre de accion pisa sus teclas (sobra %.0f px)" % [ancho, -peor_rotulo])

	# Restaurar: el texto largo y la cuenta no se tocan
	var largo: float = res.position.x + ancho * 0.025 + f.get_string_size(
		"Pulsa otra vez para confirmar", HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_ROTULO).x
	var cuenta: float = res.end.x - 16.0 - f.get_string_size("21 cambios",
		HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_PIE).x
	_ok(largo < cuenta - 4.0, "a %d px: 'Pulsa otra vez...' no pisa la cuenta de cambios" % ancho)

	# cabecera: titulo y nota no se tocan
	var x0: float = panel.position.x + ancho * 0.025
	var fin_titulo: float = x0 + f.get_string_size("> CONTROLES", HORIZONTAL_ALIGNMENT_LEFT, -1,
		p.TAM_TITULO).x
	var nota: float = panel.end.x - ancho * 0.025 - f.get_string_size(
		"Volumen y accesibilidad: en la pausa", HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_PIE).x
	_ok(fin_titulo < nota - 8.0, "a %d px: el titulo y la nota de la cabecera no se tocan" % ancho)

	# El peor aviso posible, con la tecla de nombre mas largo y la accion de
	# nombre mas largo, tiene que caber en el pie. Se mide, no se supone.
	var tecla_larga := ""
	for cod in range(KEY_SPACE, KEY_ASCIITILDE + 1) + Teclas.ESPECIALES:
		if Teclas.es_asignable(cod):
			var n := Teclas.nombre_codigo(cod)
			if f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_PIE).x \
					> f.get_string_size(tecla_larga, HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_PIE).x:
				tecla_larga = n
	var corto_largo := ""
	for a in Teclas.CORTOS:
		if String(Teclas.CORTOS[a]).length() > corto_largo.length():
			corto_largo = Teclas.CORTOS[a]
	var peores := [
		"Intercambio: %s a %s, %s a %s" % [tecla_larga, corto_largo, tecla_larga, corto_largo],
		"%s pasa de %s a %s" % [tecla_larga, corto_largo, corto_largo],
		"%s quitada de %s" % [tecla_larga, corto_largo],
		"%s necesita al menos una tecla" % corto_largo,
		"%s se quedaria sin tecla" % corto_largo,
		"Sin cambios: no llego ninguna tecla",
	]
	var peor := ""
	var peor_an := 0.0
	for m in peores:
		var an := f.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, p.TAM_PIE).x
		if an > peor_an:
			peor_an = an
			peor = m
	_ok(peor_an <= pie.size.x, "a %d px: el aviso mas largo cabe en el pie (%.0f de %.0f px)"
		% [ancho, peor_an, pie.size.x])
	vista.queue_free()
	await _cuadros(1)


# ------------------------------------------------------------- con el menu
func _abrir() -> void:
	menu = load(MENU).instantiate()
	add_child(menu)
	await _cuadros(4)
	c = menu.get_node("Controles")
	menu.sel = 1
	await _pulsar(KEY_ENTER)
	_ok(c.abierto and menu._panel == "controles", "Intro sobre OPCIONES abre CONTROLES")
	_ok(not c.escuchando, "y el Intro que la abre no se pone a escuchar")
	_ok(menu.OPCIONES.size() == 4, "el menu sigue teniendo 4 opciones")


func _navegar() -> void:
	await _pulsar(KEY_DOWN)
	_ok(c.fila == 1, "flecha abajo baja una fila")
	await _pulsar(KEY_UP)
	await _pulsar(KEY_UP)
	_ok(c.fila == c.FILA_RESTAURAR, "arriba desde la primera da la vuelta a Restaurar, sin pasar por Pausa")
	_ok(c.abierto, "navegar no cierra nada")


func _asignar() -> void:
	await _ir_a(2)                      # saltar
	await _pulsar(KEY_SPACE)
	_ok(c.escuchando and c.abierto, "Espacio (que es saltar) empieza la escucha y NO cierra la pantalla")
	_ev(KEY_K, true)
	await _cuadros(3)
	_ok(not c.escuchando and _codigos("saltar")[0] == KEY_K and c.fila == 2,
		"una K fisica se asigna a saltar y el foco no se mueve")
	_ev(KEY_K, false)
	await _cuadros(3)

	await _pulsar(KEY_RIGHT)
	await _pulsar(KEY_RIGHT)
	_ok(c.hueco == 2, "derecha mueve el foco entre las teclas de la fila")
	await _pulsar(KEY_ENTER)
	await _pulsar(KEY_DOWN)
	_ok(_codigos("saltar")[2] == KEY_DOWN and c.fila == 2,
		"asignar la flecha abajo NO baja ademas de fila")
	await _pulsar(KEY_LEFT)
	await _pulsar(KEY_ENTER)
	await _pulsar(KEY_ENTER)
	await _cuadros(3)
	_ok(_codigos("saltar")[1] == KEY_ENTER and not c.escuchando,
		"asignar Intro no vuelve a empezar la escucha")
	_ok(c.tipo_aviso == "bien" and c.aviso != "", "y el pie dice lo que paso (\"%s\")" % c.aviso)


func _cancelar_y_cerrar() -> void:
	var antes := _codigos("saltar")
	await _pulsar(KEY_ENTER)
	_ok(c.escuchando, "Intro sobre una tecla se pone a escuchar")
	await _pulsar(KEY_ESCAPE)
	_ok(not c.escuchando and c.abierto and _codigos("saltar") == antes,
		"Esc cancela la escucha sin cambiar nada, y la pantalla sigue abierta")
	await _pulsar(KEY_ESCAPE)
	_ok(not c.abierto and menu._panel == "", "un segundo Esc vuelve al menu")
	await _cuadros(3)
	_ok(menu._panel == "", "y el menu no vuelve a abrir nada por su cuenta")


func _lo_que_no_es_tecla() -> void:
	menu.sel = 1
	await _pulsar(KEY_ENTER)
	await _ir_a(2)
	var antes := _codigos("saltar")
	await _pulsar(KEY_ENTER)
	_ev(KEY_L, false)
	await _cuadros(3)
	_ok(c.escuchando and _codigos("saltar") == antes, "soltar una tecla no cuenta como tecla")
	_ev(KEY_L, true, true)
	await _cuadros(3)
	_ok(c.escuchando and _codigos("saltar") == antes, "ni una repeticion (eco)")
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = c.caja_panel().get_center()
	Input.parse_input_event(clic)
	await _cuadros(3)
	_ok(not c.escuchando and _codigos("saltar") == antes, "y un clic cancela la escucha sin asignar nada")
	var suelta := clic.duplicate() as InputEventMouseButton
	suelta.pressed = false
	Input.parse_input_event(suelta)
	await _cuadros(3)


func _se_acaba_sola() -> void:
	var antes := _codigos("saltar")
	await _pulsar(KEY_ENTER)
	_ok(c.escuchando, "otra escucha")
	Engine.time_scale = 10.0
	await get_tree().create_timer(0.7, true, false, true).timeout   # 7 s de juego
	Engine.time_scale = 1.0
	_ok(not c.escuchando and _codigos("saltar") == antes and c.abierto,
		"a los 5 s sin tecla la escucha se cancela sola y no cambia nada")


func _quitar() -> void:
	await _pulsar(KEY_LEFT)
	await _pulsar(KEY_LEFT)
	var n := _codigos("saltar").size()
	await _pulsar(KEY_DELETE)
	_ok(_codigos("saltar").size() == n - 1, "Supr quita la tecla enfocada (%d -> %d)" % [n, n - 1])
	await _ir_a(4)                      # pulso, que solo tiene la Q
	await _pulsar(KEY_DELETE)
	_ok(_codigos("pulso") == [KEY_Q] and c.tipo_aviso == "rojo",
		"y no deja quitar la ultima: avisa en rojo (\"%s\")" % c.aviso)


func _restaurar() -> void:
	await _ir_a(c.FILA_RESTAURAR)
	_ok(not Teclas.es_de_fabrica(), "antes de restaurar hay cambios (%d)" % Teclas.cambios())
	await _pulsar(KEY_ENTER)
	_ok(not Teclas.es_de_fabrica(), "el primer Intro en Restaurar solo pide confirmar")
	await _pulsar(KEY_ENTER)
	_ok(Teclas.es_de_fabrica(), "el segundo restaura todo")
	await _pulsar(KEY_ESCAPE)


## La rueda contaba como clic (dos muescas sobre Restaurar borraban todas las
## teclas, una fuera del panel la cerraba) y un dedo contaba dos veces (el clic
## que Godot emula del toque, y el toque): Restaurar se confirmaba de un toque.
func _raton_y_toque() -> void:
	Teclas.asignar("saltar", 0, KEY_L)
	menu.sel = 1
	await _pulsar(KEY_ENTER)
	_ok(c.abierto, "CONTROLES abierta otra vez, con un cambio (%d)" % Teclas.cambios())
	# las posiciones entran por la ventana: del juego (640x360) a la ventana
	var a_ventana: Transform2D = get_viewport().get_final_transform()
	var sobre: Vector2 = a_ventana * (c.caja_restaurar() as Rect2).get_center()
	for n in 2:
		await _boton(MOUSE_BUTTON_WHEEL_DOWN, sobre)
	_ok(not Teclas.es_de_fabrica() and c._t_confirma <= 0.0,
		"dos muescas de rueda sobre Restaurar no restauran ni piden confirmar")
	await _boton(MOUSE_BUTTON_WHEEL_UP, a_ventana * Vector2(20, 180))
	await _boton(MOUSE_BUTTON_RIGHT, a_ventana * Vector2(20, 180))
	_ok(c.abierto, "ni la rueda ni el clic derecho fuera del panel la cierran")
	await _tocar(sobre)
	_ok(not Teclas.es_de_fabrica() and c._t_confirma > 0.0,
		"UN toque en Restaurar solo pide confirmar")
	await _tocar(sobre)
	_ok(Teclas.es_de_fabrica(), "y el segundo toque restaura")
	await _pulsar(KEY_ESCAPE)


func _boton(boton: MouseButton, donde: Vector2) -> void:
	for pulsado in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = boton
		b.position = donde
		b.pressed = pulsado
		Input.parse_input_event(b)
		await _cuadros(2)


func _tocar(donde: Vector2) -> void:
	for pulsado in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = donde
		t.pressed = pulsado
		Input.parse_input_event(t)
		await _cuadros(2)


func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	Engine.time_scale = 1.0
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
	print("PRUEBA CONTROLES OK")
	get_tree().quit()
