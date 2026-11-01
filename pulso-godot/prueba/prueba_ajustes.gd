extends Node
## Modo asistencia y vibracion al morir.
##
## Lo mas importante que protege esta prueba no es que la asistencia funcione,
## sino que con ella APAGADA el juego sea exactamente el de siempre: la celda
## tiene que matar desde 0,35 s, ni una centesima antes ni despues.

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-60s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Las medidas de esta prueba son las de TSL-04. Si quien juega ha elegido
	# otro personaje, sin esto fallaria sin que el juego tuviera nada roto.
	Personajes.forzado = Personajes.BASE
	get_tree().create_timer(60.0).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	# Esta prueba guarda en el archivo de progreso DE VERDAD: se copia antes y se
	# devuelve al final, o pasar las pruebas le cambia los ajustes a quien juega.
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Guardado.poner_opcion("asistencia", false)
	Guardado.poner_opcion("vibracion", true)

	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.4).timeout
	var rej: RejillaEstela = get_tree().get_first_node_in_group("estela") as RejillaEstela
	_ok(rej != null, "hay rejilla de estela en el nivel")
	if rej == null:
		_fin()
		return

	# --- 1. asistencia apagada: el juego de siempre
	var c := Vector2i(9000, 9000)          # lejos de cualquier toma de tierra
	rej.limpiar()
	# marcada en t = 0 y no en t = 100: 100,35 - 100 en coma flotante da
	# 0,3499999999999943, que es MENOR que 0,35, y la prueba fallaba sin que el
	# juego hubiera cambiado. Desde cero la resta es exacta.
	rej.marcar(c, 0.0)
	_ok(is_equal_approx(rej.retardo, RejillaEstela.RETARDO),
		"apagada, el retardo efectivo es el de siempre (%.2f s)" % rej.retardo)
	_ok(not rej.mata(c, 0.34), "apagada, a 0,34 s la celda todavia no mata")
	_ok(rej.mata(c, 0.35), "apagada, a 0,35 s ya mata, como siempre")

	# --- 2. asistencia encendida DESDE LA PAUSA, con el nivel en marcha
	n._abrir_pausa()
	var m: Control = n._pausa
	var fila: int = m.OPCIONES.find("Accesibilidad")
	_ok(fila >= 0, "la pausa tiene la fila de Accesibilidad")
	var k_asis: int = m.INTERRUPTORES.find("asistencia")
	m.alternar_interruptor(k_asis)
	_ok(bool(Guardado.opcion("asistencia", false)), "el interruptor guarda la asistencia")
	_ok(is_equal_approx(rej.retardo, RejillaEstela.RETARDO_ASISTIDO),
		"y la rejilla VIVA se entera sin reiniciar (%.2f s)" % rej.retardo)
	_ok(not rej.mata(c, 0.36), "encendida, a 0,36 s la celda no mata")
	_ok(not rej.mata(c, 0.69), "ni a 0,69 s")
	_ok(rej.mata(c, 0.70), "y a partir de 0,70 s si: pararse sigue siendo un error")

	# --- 3. la animacion de encendido no miente: acaba justo cuando empieza a matar
	var tope: Array = rej._estado(RejillaEstela.RETARDO_ASISTIDO - 0.001)
	var normal_ultimo: int = int((RejillaEstela.RETARDO - 0.001) * 24.0)
	_ok(tope[0] == "encendido" and int(tope[1]) == normal_ultimo,
		"con asistencia el ultimo cuadro de encendido llega justo al matar (%d)" % int(tope[1]))
	_ok(rej._estado(0.36)[0] == "encendido",
		"a 0,36 s con asistencia la celda aun se ve encendiendose, no activa")
	m.alternar_interruptor(k_asis)
	_ok(is_equal_approx(rej.retardo, RejillaEstela.RETARDO), "apagarla devuelve el retardo normal")

	# --- 4. persistencia
	Guardado.poner_opcion("asistencia", true)
	Guardado.poner_opcion("vibracion", false)
	Guardado.guardar()
	Guardado.poner_opcion("asistencia", false)
	Guardado.poner_opcion("vibracion", true)
	Guardado.cargar()
	_ok(bool(Guardado.opcion("asistencia", false)) and not bool(Guardado.opcion("vibracion", true)),
		"los dos ajustes sobreviven a cerrar y abrir")

	# --- 5. vibracion: solo con el ajuste encendido
	Guardado.poner_opcion("vibracion", false)
	var v0: int = Efectos.vibraciones
	Efectos.muerte(Vector2.ZERO)
	_ok(Efectos.vibraciones == v0, "con la vibracion apagada, morir no vibra")
	Guardado.poner_opcion("vibracion", true)
	Efectos.muerte(Vector2.ZERO)
	_ok(Efectos.vibraciones == v0 + 1, "con la vibracion encendida, morir vibra una vez")

	# --- 6. la pausa: cabe, y el mando no enciende cosas al pasar
	_ok(m.alto_total() <= 340.0, "el menu de pausa cabe en 360 px (%.0f px)" % m.alto_total())
	var f: Rect2 = m._filas[fila]
	var dentro := true
	for k in m.INTERRUPTORES.size():
		if not f.encloses(m._caja_chip(f, k)):
			dentro = false
	_ok(dentro, "los tres interruptores caben dentro de su fila")
	m._sel = fila
	m._chip = 0
	var antes: Array = []
	for k in m.INTERRUPTORES.size():
		antes.append(m.interruptor(k))
	m._mover_ajuste(1)
	m._mover_ajuste(1)
	var iguales := true
	for k in m.INTERRUPTORES.size():
		if m.interruptor(k) != antes[k]:
			iguales = false
	_ok(m._chip == 2 and iguales,
		"izquierda y derecha mueven el foco sin cambiar ningun ajuste")
	m.cerrar(true)
	_fin()

func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	if _habia:
		var fw := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fw != null:
			fw.store_buffer(_copia)
			fw.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	get_tree().paused = false
	print("FALLOS: %d" % fallos)
	print("PRUEBA AJUSTES OK")
	get_tree().quit()
