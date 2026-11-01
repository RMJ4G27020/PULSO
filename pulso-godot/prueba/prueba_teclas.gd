extends Node
## La logica de la reasignacion de teclas (scripts/teclas.gd), sin pantalla.
##
## Lo que se protege son las tres promesas de teclas.gd, comprobadas despues de
## CADA operacion y no solo al final: ninguna accion sin tecla, ninguna tecla en
## dos acciones, y Esc siempre y solo en la pausa. Mas que lo guardado vuelva
## identico al leerlo y que un guardado roto nunca deje el juego sin controles.
##
## Escribe en el progreso DE VERDAD: se copia al empezar y se devuelve al final.

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false


func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-66s %s" % [txt, "OK" if c else "FALLA"])


func _ready() -> void:
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Guardado.poner_opcion("teclas", {})
	Teclas.aplicar()

	_fabrica()
	_asignar_y_disco()
	_robo_e_intercambio()
	_rechazos()
	_guardados_rotos()
	await _revision()
	_restaurar()
	_nombres()
	_fin()


# ------------------------------------------------------------------ ayudas
func _codigos(accion: String) -> Array[int]:
	var r: Array[int] = []
	for k in Teclas.de(accion):
		r.append(Teclas.codigo(k))
	return r


func _firmas(accion: String) -> Array[String]:
	return Teclas._firma(Teclas.de(accion))


## Las tres promesas. Se llama tras cada operacion.
func _invariante(cuando: String) -> void:
	var vistas := {}
	var bien := true
	var motivo := ""
	for a in Teclas.ACCIONES + ["pausa"]:
		var cs := _codigos(a)
		if cs.size() < 1 or cs.size() > Teclas.MAX:
			bien = false
			motivo = "%s tiene %d teclas" % [a, cs.size()]
		for c in cs:
			if vistas.has(c):
				bien = false
				motivo = "%s esta en %s y en %s" % [Teclas.nombre_codigo(c), vistas[c], a]
			vistas[c] = a
	if vistas.get(KEY_ESCAPE, "") != "pausa":
		bien = false
		motivo = "Esc no esta en la pausa"
	_ok(bien, "invariante tras %s%s" % [cuando, "" if bien else " (" + motivo + ")"])


func _mapa() -> String:
	var s := ""
	for a in Teclas.ACCIONES + ["pausa"]:
		s += "%s=%s;" % [a, ",".join(_firmas(a))]
	return s


func _evento(cod: int, fisica: bool) -> InputEventKey:
	var e := InputEventKey.new()
	if fisica:
		e.physical_keycode = cod as Key
	else:
		e.keycode = cod as Key
	e.pressed = true
	return e


# ------------------------------------------------------------------ partes
func _fabrica() -> void:
	_ok(_firmas("saltar") == ["k32", "k4194320", "f87"],
		"de fabrica saltar es Espacio, flecha arriba y W fisica")
	_ok(_firmas("impulso") == ["k4194325", "f74"], "impulso es Shift y J fisica")
	_ok(_firmas("pausa") == ["k4194305"], "y la pausa es Esc, sola")
	_ok(Teclas.es_de_fabrica() and Teclas.cambios() == 0, "es_de_fabrica() y 0 cambios")
	var zona_ok := true
	for a in Teclas.ACCIONES + ["pausa"]:
		var ps: Variant = ProjectSettings.get_setting("input/" + a)
		if not InputMap.has_action(a) or not is_equal_approx(InputMap.action_get_deadzone(a),
				float((ps as Dictionary).get("deadzone", 0.5))):
			zona_ok = false
	_ok(zona_ok, "las 8 acciones existen y conservan su zona muerta de project.godot")
	# la pausa se arreglo para elegir solo con ui_accept: Espacio tiene que estar ahi
	_ok(InputMap.event_is_action(_evento(KEY_SPACE, false), "ui_accept"),
		"Espacio es de ui_accept (la pausa y los menus eligen con el)")
	_invariante("arrancar")


func _asignar_y_disco() -> void:
	var r: Array = Teclas.asignar("saltar", 1, KEY_K)
	_ok(bool(r[0]) and _codigos("saltar") == [KEY_SPACE, KEY_K, KEY_W],
		"asignar K al hueco 2 de saltar la pone en su sitio")
	var nueva: InputEventKey = Teclas.de("saltar")[1]
	_ok(nueva.physical_keycode == KEY_K and nueva.keycode == KEY_NONE,
		"y va por posicion fisica, sin keycode")
	_ok(InputMap.event_is_action(_evento(KEY_K, true), "saltar"), "K fisica ya salta")
	var arriba := _evento(KEY_UP, false)
	_ok(not InputMap.event_is_action(arriba, "saltar") and InputMap.event_is_action(arriba, "ui_up"),
		"la flecha arriba ya no salta, y sigue moviendo por los menus")
	_ok(Teclas.cambios() == 1 and Teclas.hueco_cambiado("saltar", 1)
		and not Teclas.hueco_cambiado("saltar", 0), "cuenta 1 cambio, en ese hueco")
	_invariante("asignar")

	# el archivo, leido en crudo: solo la accion cambiada y con su forma exacta
	var j := JSON.new()
	var leido := j.parse(FileAccess.get_file_as_string(Guardado.RUTA)) == OK
	var t: Variant = (j.data as Dictionary).get("opciones", {}).get("teclas", null) if leido else null
	_ok(t is Dictionary and (t as Dictionary).keys() == ["saltar"]
		and (t as Dictionary)["saltar"] == ["k32", "f75", "f87"],
		"en disco solo va saltar, como [k32, f75, f87]")
	# y vuelve identico al leerlo: lo que pasaria al abrir el juego otro dia
	for a in Teclas.ACCIONES:
		Teclas._poner(a, Teclas.de_fabrica(a))
	Guardado.cargar()
	Teclas.aplicar()
	_ok(_codigos("saltar") == [KEY_SPACE, KEY_K, KEY_W],
		"al volver a cargar, saltar sigue con K, con el codigo exacto")


func _robo_e_intercambio() -> void:
	# J es de impulso, que tiene otra (Shift): se la quita y ya
	var r: Array = Teclas.asignar("pulso", 0, KEY_J)
	_ok(bool(r[0]) and _codigos("pulso") == [KEY_J] and _codigos("impulso") == [KEY_SHIFT],
		"poner J en pulso se la quita a impulso, que se queda con Shift")
	_ok(String(r[1]) != "" and String(r[2]) == "impulso",
		"y avisa (\"%s\")" % String(r[1]))
	_invariante("robar")
	# Shift es ahora la UNICA de impulso: se intercambian
	r = Teclas.asignar("reiniciar", 0, KEY_SHIFT)
	_ok(bool(r[0]) and _codigos("reiniciar") == [KEY_SHIFT] and _codigos("impulso") == [KEY_R],
		"poner Shift en reiniciar las intercambia: impulso se queda la R")
	_ok(String(r[1]).begins_with("Intercambio"), "y lo dice (\"%s\")" % String(r[1]))
	_invariante("intercambiar")


func _rechazos() -> void:
	var antes := _mapa()
	# R es la unica de impulso y el hueco 2 de terminal esta vacio: no hay nada
	# que darle a cambio
	var r: Array = Teclas.asignar("interactuar", 1, KEY_R)
	_ok(not bool(r[0]) and _mapa() == antes,
		"no se le quita a nadie su unica tecla desde un hueco vacio (\"%s\")" % String(r[1]))
	r = Teclas.quitar("interactuar", 0)
	_ok(not bool(r[0]) and _mapa() == antes, "ni se quita la ultima tecla de una accion")
	var prohibidas := [KEY_ESCAPE, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_NONE, KEY_VOLUMEUP,
		KEY_MEDIAPLAY, KEY_BACK]
	var ninguna := true
	for c in prohibidas:
		if bool(Teclas.asignar("saltar", 0, c)[0]):
			ninguna = false
	_ok(ninguna and _mapa() == antes,
		"Esc, Cmd, los bloqueos, el 0, volumen, multimedia y Atras se rechazan")
	r = Teclas.asignar("saltar", 2, KEY_K)
	_ok(not bool(r[0]) and _mapa() == antes, "ni se repite una tecla dentro de la misma accion")
	r = Teclas.asignar("pausa", 1, KEY_P)
	_ok(not bool(r[0]) and _codigos("pausa") == [KEY_ESCAPE], "la pausa no se reasigna")
	r = Teclas.asignar("saltar", 3, KEY_L)
	_ok(not bool(r[0]) and _mapa() == antes, "ni se pasa de tres teclas")
	_invariante("rechazar")
	# quitar si se puede cuando quedan mas
	r = Teclas.quitar("saltar", 2)
	_ok(bool(r[0]) and _codigos("saltar") == [KEY_SPACE, KEY_K], "quitar una de tres deja dos")
	_invariante("quitar")


func _guardados_rotos() -> void:
	# basura de todo tipo: nada de esto puede dejar una accion vacia
	Guardado.poner_opcion("teclas", {"saltar": ["x1", 3, "f0", "f-5", ""], "impulso": "no",
		"inventada": ["f75"], "pulso": ["f4194305"]})
	Teclas.aplicar()
	_ok(_codigos("saltar") == _codigos_de(Teclas.de_fabrica("saltar"))
		and _codigos("impulso") == _codigos_de(Teclas.de_fabrica("impulso")),
		"entradas ilegibles: esas acciones vuelven a fabrica")
	_ok(_codigos("pulso") == [KEY_Q], "Esc guardado en pulso se descarta (vuelve la Q)")
	_ok(not InputMap.has_action("inventada"), "una accion que no existe no se crea")
	_invariante("guardado ilegible")
	# una tecla en dos acciones: se vuelve a fabrica TODO
	Guardado.poner_opcion("teclas", {"saltar": ["f75"], "pulso": ["f75"]})
	Teclas.aplicar()
	_ok(Teclas.es_de_fabrica(), "una tecla repetida entre acciones devuelve todo a fabrica")
	_invariante("tecla repetida")
	Guardado.poner_opcion("teclas", "esto no es un diccionario")
	Teclas.aplicar()
	_ok(Teclas.es_de_fabrica(), "y si 'teclas' no es ni un diccionario, tambien")
	_invariante("teclas de otro tipo")


func _codigos_de(teclas: Array[InputEventKey]) -> Array[int]:
	var r: Array[int] = []
	for k in teclas:
		r.append(Teclas.codigo(k))
	return r


## Lo que encontro la revision adversarial, cada cosa con su caso.
func _revision() -> void:
	_ok(not Teclas.es_asignable(97) and not Teclas.es_asignable(122) and Teclas.es_asignable(KEY_A),
		"las minusculas (97-122) no son teclas; KEY_A (65) si")
	_ok(not Teclas.es_asignable(KEY_KP_4) and not Teclas.es_asignable(KEY_KP_8)
		and Teclas.es_asignable(KEY_KP_ADD) and Teclas.es_asignable(KEY_KP_ENTER),
		"del numerico solo lo que no cambia con Bloq Num (Num 4/8 serian flechas)")
	_ok(Teclas.es_asignable(KEY_CTRL) == (OS.get_name() != "macOS"),
		"Ctrl no se asigna en macOS (Ctrl+flechas son del sistema): aqui %s" % OS.get_name())
	# ida y vuelta: quitarle el Shift a impulso y devolverselo deja todo de fabrica,
	# aunque ahora el Shift este escrito por posicion y el de fabrica por codigo
	Teclas.restaurar()
	Teclas.asignar("impulso", 0, KEY_Q)
	Teclas.asignar("impulso", 0, KEY_SHIFT)
	var t: Variant = Guardado.opcion("teclas", null)
	_ok(Teclas.es_de_fabrica() and t is Dictionary and (t as Dictionary).is_empty(),
		"devolver una tecla a su sitio cuenta como fabrica y no se guarda nada")
	_invariante("ida y vuelta")
	# el aviso de la terminal dice la tecla que hay de verdad
	Teclas.asignar("interactuar", 0, KEY_F)
	var ter: Node = load("res://escenas/obstaculos/Interruptor.tscn").instantiate()
	add_child(ter)
	await get_tree().process_frame
	_ok((ter.get_node("Aviso") as Label).text == "F",
		"la terminal ya no dice 'E' si accionar es la F (dice '%s')" % (ter.get_node("Aviso") as Label).text)
	ter.queue_free()
	Teclas.restaurar()


func _restaurar() -> void:
	Teclas.asignar("saltar", 0, KEY_L)
	Teclas.asignar("mover_izq", 1, KEY_H)
	_ok(Teclas.cambios() == 2, "dos cambios antes de restaurar (%d)" % Teclas.cambios())
	Teclas.restaurar()
	var t: Variant = Guardado.opcion("teclas", null)
	_ok(Teclas.es_de_fabrica() and t is Dictionary and (t as Dictionary).is_empty(),
		"restaurar deja todo de fabrica y 'teclas' vacio")
	_ok(InputMap.action_get_events("mover_izq").size() == 2, "mover_izq vuelve a tener sus 2 teclas")
	_invariante("restaurar")


func _nombres() -> void:
	_ok(Teclas.nombre_codigo(KEY_SPACE) == "Espacio" and Teclas.nombre_codigo(KEY_SEMICOLON) == ";"
		and Teclas.nombre_codigo(KEY_KP_5) == "Num 5" and Teclas.nombre_codigo(KEY_F5) == "F5"
		and Teclas.nombre_codigo(KEY_A) == "A",
		"nombres en espanol, no 'Space', 'Semicolon' ni 'Kp 5'")
	# Cada tecla que se puede asignar tiene que caber en su ranura (64 px a 640,
	# menos 6 de margen) y estar dibujada con caracteres que la fuente TIENE.
	var f: Font = ThemeDB.fallback_font
	var peor := ""
	var peor_an := 0.0
	var sin_glifo := ""
	var candidatas: Array[int] = []
	for c in range(KEY_SPACE, 256):
		candidatas.append(c)
	candidatas.append_array(Teclas.ESPECIALES)
	for c in candidatas:
		if not Teclas.es_asignable(c) or Teclas.es_flecha(c):
			continue
		var n := Teclas.nombre_codigo(c)
		var an := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if an > peor_an:
			peor_an = an
			peor = n
		for ch in n:
			if not f.has_char(ch.unicode_at(0)):
				sin_glifo = n
	_ok(peor_an <= 58.0, "el nombre mas largo cabe en su ranura a 11 px (%s, %.0f px)" % [peor, peor_an])
	_ok(sin_glifo == "", "y la fuente tiene todos los caracteres%s" %
		("" if sin_glifo == "" else " (falla: %s)" % sin_glifo))


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
	print("PRUEBA TECLAS OK")
	get_tree().quit()
