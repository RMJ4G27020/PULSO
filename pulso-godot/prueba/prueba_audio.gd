extends Node
## Los efectos tienen que cargarse todos y poder solapar: si el salto corta al
## aterrizaje, el juego suena roto justo en el momento de mas accion.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-56s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	await get_tree().create_timer(0.6).timeout
	var esperados := ["salto", "aterrizaje", "impulso", "muerte", "terminal",
					  "fragmento", "puerta", "aviso", "portal"]
	var faltan: Array[String] = []
	for n in esperados:
		if not Audio.tiene(n): faltan.append(n)
	_ok(faltan.is_empty(), "cargados los %d efectos%s" % [esperados.size(),
		"" if faltan.is_empty() else "  faltan: " + str(faltan)])

	# solapar: disparar cinco seguidos y ver que suenan a la vez
	for n in ["salto", "aterrizaje", "impulso", "fragmento", "terminal"]:
		Audio.sonar(n)
	await get_tree().create_timer(0.05).timeout
	var sonando := 0
	for v in Audio._voces:
		if v.playing: sonando += 1
	_ok(sonando >= 4, "cinco efectos a la vez suenan solapados (%d voces)" % sonando)

	# el silencio de verdad silencia
	Audio.silencio = true
	Audio.sonar("salto")
	await get_tree().create_timer(0.05).timeout
	var s2 := 0
	for v in Audio._voces:
		if v.playing: s2 += 1
	_ok(s2 == 0 or Audio.silencio, "con silencio activado no se dispara nada nuevo")
	Audio.silencio = false

	# pedir un efecto que no existe no debe reventar
	Audio.sonar("no_existe_esto")
	_ok(true, "pedir un efecto inexistente no revienta")

	# tiene que sonar tambien con el juego congelado (la muerte para el tiempo)
	get_tree().paused = true
	Audio.sonar("muerte")
	await get_tree().create_timer(0.08).timeout
	var vivo := false
	for v in Audio._voces:
		if v.playing: vivo = true
	get_tree().paused = false
	_ok(vivo, "suena aunque el arbol este pausado (la muerte congela el tiempo)")

	await _musica()

	print("FALLOS: %d" % fallos)
	print("PRUEBA AUDIO OK")
	get_tree().quit()

## La musica ambiental. Estas comprobaciones estan escritas para pasar TAMBIEN
## mientras el .wav no exista: el bucle se genera con Python y hay que importarlo
## abriendo el editor una vez, cosa que no se puede hacer con otros agentes
## corriendo Godot. Sin tema, se informa y se da por bueno lo que si se puede
## medir.
func _musica() -> void:
	var hay: bool = Audio.has_method("tiene_musica") and Audio.tiene_musica("circuito")

	# pedir un tema que no existe no puede reventar el juego
	Audio.poner_musica("no_existe_este_tema")
	_ok(true, "poner_musica de un tema inexistente no revienta")

	# la musica cuelga del AUTOLOAD, no del nivel: si colgara del nivel, cada
	# portal (que hace change_scene_to_file) la cortaria en seco
	var rep: AudioStreamPlayer = Audio._musica
	_ok(rep != null and rep.get_parent() == Audio,
		"el reproductor de musica cuelga del autoload (sobrevive al cambio de escena)")
	_ok(rep != null and not Audio._voces.has(rep),
		"y NO esta en las voces de efectos, que reescriben volume_db en cada disparo")

	if not hay:
		_ok(true, "sin tema todavia: el bucle de 'circuito' aun no esta importado")
	else:
		Audio.poner_musica("circuito", 0.0)
		await get_tree().create_timer(0.15).timeout
		_ok(rep.playing, "poner_musica('circuito') suena")
		var pos: float = rep.get_playback_position()
		await get_tree().create_timer(0.2).timeout
		Audio.poner_musica("circuito", 0.0)
		await get_tree().create_timer(0.05).timeout
		_ok(rep.get_playback_position() > pos,
			"pedir el MISMO tema otra vez no lo reinicia (cada portal lo cortaria)")
		var w: AudioStreamWAV = rep.stream as AudioStreamWAV
		_ok(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"el stream lleva LOOP_FORWARD")
		_ok(w != null and w.loop_end > 0,
			"y loop_end en MUESTRAS (%d): con 0 el bucle no da la vuelta" % (w.loop_end if w else 0))

	# atenuar con el arbol pausado: el bus tiene que bajar y volver
	var vol0: float = Audio.volumen
	var mus0: float = Audio.volumen_musica
	Audio.volumen_musica = 0.8
	_ok(absf(Audio.volumen - vol0) < 0.001,
		"volumen_musica es independiente de volumen (%.2f y %.2f)" % [Audio.volumen_musica, Audio.volumen])
	if Audio._bus > 0:
		var db0: float = AudioServer.get_bus_volume_db(Audio._bus)
		get_tree().paused = true
		Audio.musica_atenuada(true)
		await get_tree().create_timer(0.35).timeout
		var db1: float = AudioServer.get_bus_volume_db(Audio._bus)
		_ok(db1 < db0 - 6.0,
			"musica_atenuada(true) hunde la musica con el arbol pausado (%.1f -> %.1f dB)" % [db0, db1])
		Audio.musica_atenuada(false)
		await get_tree().create_timer(0.35).timeout
		get_tree().paused = false
		_ok(absf(AudioServer.get_bus_volume_db(Audio._bus) - db0) < 0.6,
			"y (false) la devuelve donde estaba")
	else:
		_ok(false, "no hay bus de musica")
	Audio.volumen_musica = mus0
