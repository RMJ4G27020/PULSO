extends Node
## El final de la historia, entre el nivel 3 y el 4.
##
## Lo que se protege es lo que se rompe sin que se vea en una captura:
##   - que no haya DOS escenas vivas a la vez (un nivel debajo del final)
##   - que no se pisen DOS sonidos: ni el portal con la musica del final, ni la
##     musica del nivel con la del final
##   - que la salida del nivel 3 dure lo mismo que la de cualquier nivel
##   - que el final lleve al nivel 4 y la intro siga exactamente como estaba
##
## Se recorre con los cambios de escena DE VERDAD. Para sobrevivir a ellos, el
## nivel se hace escena actual y esta prueba se queda colgando de la raiz:
## change_scene_to_file libera la escena actual, no lo que cuelga de root.

const N3 := "res://escenas/niveles/n3_el_nudo.tscn"
const N4 := "res://escenas/niveles/n4_la_chimenea.tscn"
const FINAL := "res://escenas/CineFinal.tscn"
const INTRO := "res://escenas/CineIntro.tscn"

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false


func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-66s %s" % [txt, "OK" if c else "FALLA"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	# salir del nivel 3 guarda el progreso en el archivo DE VERDAD
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	await get_tree().process_frame
	# esta prueba deja de ser la escena actual: el nivel ocupara ese sitio
	get_tree().current_scene = null
	_contenido()
	_intro_intacta()
	await _de_n3_al_final()
	await _del_final_al_n4()
	await _saltarse_el_final()
	_fin()


# ------------------------------------------------------------- 1. lo que hay
func _contenido() -> void:
	var c: Control = load(FINAL).instantiate()
	add_child(c)
	_ok(c.final and c.beats.size() == 8, "el final tiene %d laminas" % c.beats.size())
	var todas := true
	for b in c.beats:
		for s in ["a", "b"]:
			if not ResourceLoader.exists("res://arte/laminas/v%d%s.svg" % [int(b[0]), s]):
				todas = false
	_ok(todas, "y existen sus dos dibujos cada una (el hervor)")
	var dur := 0.0
	for b in c.beats:
		dur += float(b[1])
	var total: float = dur + c.FUNDIDO + c.ROTULO
	var tema: AudioStreamWAV = Audio._temas.get("libre")
	_ok(tema != null, "el tema 'libre' esta cargado")
	if tema != null:
		_ok(total < tema.get_length(),
			"el final (%.1f s) cabe en el tema (%.1f s): no da la vuelta" % [total, tema.get_length()])
	_ok(c.siguiente == N4, "despues del final se sigue en el nivel 4")
	_ok(c.get_node("Rotulo").text == "FIN", "el rotulo dice FIN")
	c.free()


func _intro_intacta() -> void:
	var c: Control = load(INTRO).instantiate()
	add_child(c)
	_ok(not c.final and c.beats == c.BEATS and c.beats.size() == 17,
		"la intro sigue con sus 17 laminas de siempre")
	_ok(c.siguiente == "res://escenas/niveles/n1_ida_y_vuelta.tscn", "y sigue llevando al nivel 1")
	_ok(c.get_node("Rotulo").text == "NIVEL 01", "y su rotulo no cambia")
	c.free()


# -------------------------------------------- 2. salir del nivel 3 al final
func _de_n3_al_final() -> void:
	Audio.poner_musica("circuito", 0.0)
	var n: Node2D = load(N3).instantiate() as Node2D
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	await _segundos(0.6)
	n._inter.activar()
	await _segundos(0.4)
	_ok(Audio._tema == "circuito" and Audio._musica.playing, "en el nivel 3 suena 'circuito'")

	var voz_portal: AudioStreamPlayer = null
	var t0: int = Time.get_ticks_usec()
	n._al_salir()
	for v in Audio._voces:
		if v.playing and v.stream == Audio._bancos.get("portal"):
			voz_portal = v
	_ok(voz_portal != null, "al tocar el portal suena el portal")

	var t_portal_fin := -1.0
	var t_musica_se_va := -1.0
	var t_cambio := -1.0
	var circuito_al_cambiar := true
	var nivel_vivo_en_final := true
	var jugadores_en_final := -1
	var t_libre := -1.0
	var portal_sonando_en_libre := true
	while _t(t0) < 4.0:
		await get_tree().process_frame
		var t: float = _t(t0)
		if t_portal_fin < 0.0 and voz_portal != null and not voz_portal.playing:
			t_portal_fin = t
		if t_musica_se_va < 0.0 and Audio._tema == "":
			t_musica_se_va = t
		var cur: Node = get_tree().current_scene
		if t_cambio < 0.0 and cur != null and cur.scene_file_path == FINAL:
			t_cambio = t
			circuito_al_cambiar = Audio._musica.playing and \
				Audio._musica.stream == Audio._temas.get("circuito")
			nivel_vivo_en_final = is_instance_valid(n)
			jugadores_en_final = get_tree().get_nodes_in_group("jugador").size()
		if t_libre < 0.0 and Audio._tema == "libre" and Audio._musica.playing:
			t_libre = t
			portal_sonando_en_libre = voz_portal != null and voz_portal.playing
			break

	_ok(t_cambio > 0.0, "del nivel 3 se pasa al FINAL, no al nivel 4")
	_ok(t_cambio > 1.4 and t_cambio < 1.7,
		"la salida del nivel 3 dura lo de siempre (%.2f s, ~1,5)" % t_cambio)
	_ok(t_musica_se_va > 0.8 and t_musica_se_va < 1.0,
		"'circuito' empieza a irse con el fundido a negro (%.2f s)" % t_musica_se_va)
	_ok(t_portal_fin > 0.0 and t_portal_fin <= t_musica_se_va + 0.05,
		"el portal ya ha sonado entero cuando se va la musica (%.2f s)" % t_portal_fin)
	_ok(not circuito_al_cambiar, "al cambiar de escena 'circuito' ya no suena")
	_ok(not nivel_vivo_en_final and jugadores_en_final == 0,
		"y el nivel 3 ya no existe: no hay dos escenas a la vez")
	_ok(t_libre >= t_cambio, "'libre' arranca ya dentro del final (%.2f s)" % t_libre)
	_ok(not portal_sonando_en_libre, "y el portal no se pisa con la musica del final")


# ------------------------------------------------- 3. del final al nivel 4
func _del_final_al_n4() -> void:
	var c: Node = get_tree().current_scene
	_ok(c != null and c.scene_file_path == FINAL, "estamos en el final")
	if c == null or c.scene_file_path != FINAL:
		return
	# 36 s de cinematica en ~4,5: el reloj de la cinematica y el fundido de la
	# musica van con el tiempo del juego, asi que se aceleran juntos
	Engine.time_scale = 8.0
	var vistas := {}
	var libre_al_fundir := true
	var musica_callada_antes_de_n4 := false
	var final_vivo_en_n4 := true
	var n4_tema := ""
	var llego := false
	while true:
		await get_tree().process_frame
		var cur: Node = get_tree().current_scene
		if cur != null and cur.scene_file_path == FINAL:
			if cur.beat < cur.beats.size():      # al fundir, beat vale 8: no es lamina
				vistas[cur.beat] = true
			if cur.fase == "rotulo":
				musica_callada_antes_de_n4 = not Audio._musica.playing
			if cur.fase == "fundido" and libre_al_fundir:
				libre_al_fundir = Audio._tema == "libre"
		elif cur != null and cur.scene_file_path == N4:
			final_vivo_en_n4 = is_instance_valid(c)
			await get_tree().process_frame
			n4_tema = Audio._tema
			llego = true
			break
		if Time.get_ticks_msec() > 140000:
			break
	Engine.time_scale = 1.0
	_ok(vistas.size() == 8, "el final pasa por sus 8 laminas (%d)" % vistas.size())
	_ok(not libre_al_fundir, "al fundir a negro, 'libre' se va con la imagen")
	_ok(musica_callada_antes_de_n4, "el rotulo FIN queda en silencio")
	_ok(llego, "al acabar, el final lleva al nivel 4")
	_ok(not final_vivo_en_n4, "y la cinematica ya no existe: no hay dos escenas a la vez")
	_ok(n4_tema == "circuito", "en el nivel 4 vuelve 'circuito', desde silencio")
	var n4: Node = get_tree().current_scene
	if n4 != null:
		n4.queue_free()
		await get_tree().process_frame


# -------------------------------------------------------- 4. saltarlo
func _saltarse_el_final() -> void:
	Audio.parar_musica(0.0)
	var c: Control = load(FINAL).instantiate()
	get_tree().root.add_child(c)
	get_tree().current_scene = c
	await _segundos(1.2)
	_ok(Audio._tema == "libre" and Audio._musica.playing, "al entrar en el final suena 'libre'")
	# Un evento de entrada de verdad y no Input.action_press: el "recien pulsado"
	# de action_press cae en el cuadro en que se llama, y si la cinematica ya se
	# ha procesado en ese cuadro no lo ve nunca. Con parse_input_event entra por
	# la cola de entrada, como una tecla real, y lo ven todos en el siguiente.
	#
	# Y el estado se mide DESDE la senal termino, no mirando la cinematica
	# despues: al saltar se libera en el mismo cuadro y ya no se puede consultar.
	# La medida va diferida: termino se emite ANTES de parar la musica, y el
	# cambio de escena, que tambien es diferido, se encola DESPUES que ella.
	var salto := {"hecho": false, "callada": false}
	c.termino.connect(func():
		salto["hecho"] = true
		(func(): salto["callada"] = not Audio._musica.playing and Audio._tema == "").call_deferred())
	_evento("saltar", true)
	for i in 4:
		await get_tree().process_frame
	_evento("saltar", false)
	_ok(salto["hecho"], "se puede saltar")
	_ok(salto["callada"], "y al saltarlo 'libre' se corta en el acto, no se arrastra al nivel 4")
	var t0: int = Time.get_ticks_usec()
	while _t(t0) < 3.0:
		await get_tree().process_frame
		var cur: Node = get_tree().current_scene
		if cur != null and cur.scene_file_path == N4:
			await get_tree().process_frame
			_ok(Audio._tema == "circuito", "y el nivel 4 arranca con su musica")
			cur.queue_free()
			return
	_ok(false, "saltar el final lleva al nivel 4")


# ---------------------------------------------------------------- utilidades
func _evento(accion: String, pulsado: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = pulsado
	Input.parse_input_event(ev)


func _t(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000000.0


func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	Engine.time_scale = 1.0
	if _habia:
		var f := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_copia)
			f.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA FINAL OK")
	get_tree().quit()
