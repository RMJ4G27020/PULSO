extends Node
## La musica ambiental tiene que sonar SIN robarle ninguna de las 8 voces a los
## efectos, dar la vuelta sin pararse, obedecer al volumen y al silencio, y
## hundirse (no cortarse) cuando el juego se congela.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-58s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	await get_tree().create_timer(0.6).timeout

	# --- el bus propio
	var bus := AudioServer.get_bus_index("Musica")
	_ok(bus > 0, "existe el bus Musica creado en caliente (indice %d)" % bus)
	_ok(bus > 0 and AudioServer.get_bus_send(bus) == "Master",
		"el bus Musica manda al Master")

	# --- el reproductor esta FUERA de la rotacion de efectos
	_ok(Audio._musica != null, "hay un reproductor de musica propio")
	_ok(not Audio._voces.has(Audio._musica),
		"el reproductor de musica NO esta en las %d voces" % Audio._voces.size())
	_ok(Audio._voces.size() == 8, "siguen siendo 8 las voces de efectos")
	_ok(Audio._musica != null and Audio._musica.process_mode == Node.PROCESS_MODE_ALWAYS,
		"el reproductor de musica es ALWAYS (sobrevive a la pausa)")
	_ok(Audio._musica != null and Audio._musica.bus == "Musica",
		"el reproductor de musica va por el bus Musica")

	# --- las firmas que llama el resto del juego
	_ok(Audio.has_method("poner_musica") and Audio.has_method("parar_musica")
		and Audio.has_method("musica_atenuada") and Audio.has_method("tiene_musica"),
		"estan las cuatro funciones publicas de musica")
	_ok(Audio.TEMAS.has("circuito"), "el tema 'circuito' esta en la lista explicita")

	# --- pedir un tema que no existe no puede reventar
	Audio.poner_musica("no_existe_esto")
	_ok(true, "pedir un tema inexistente no revienta")

	# --- volumen de musica separado del de efectos
	Audio.volumen_musica = 5.0
	_ok(is_equal_approx(Audio.volumen_musica, 1.0), "volumen_musica se recorta por arriba")
	Audio.volumen_musica = -3.0
	_ok(is_equal_approx(Audio.volumen_musica, 0.0), "volumen_musica se recorta por abajo")
	Audio.volumen_musica = 0.5
	await get_tree().process_frame
	var db_medio := AudioServer.get_bus_volume_db(bus)
	_ok(absf(db_medio - linear_to_db(0.5)) < 0.1,
		"volumen_musica 0,5 deja el bus en %.2f dB" % db_medio)
	var antes_voces: float = Audio._voces[0].volume_db
	Audio.volumen_musica = 0.2
	_ok(is_equal_approx(Audio._voces[0].volume_db, antes_voces),
		"bajar la musica NO toca el volumen de los efectos")
	Audio.volumen_musica = 0.55

	# --- el silencio general tambien silencia la musica
	Audio.silencio = true
	await get_tree().process_frame
	_ok(AudioServer.get_bus_volume_db(bus) <= -79.0,
		"con silencio el bus Musica queda en %.1f dB" % AudioServer.get_bus_volume_db(bus))
	Audio.silencio = false
	await get_tree().process_frame
	_ok(AudioServer.get_bus_volume_db(bus) > -79.0, "al quitar el silencio vuelve el bus")

	if not Audio.tiene_musica("circuito"):
		# El .sample no existe hasta que pasa el importador, y la regla de la
		# casa prohibe --import con otros agentes corriendo Godot. Para no
		# dejar sin medir la mitad del asunto, se monta el stream a mano desde
		# el PCM crudo del .wav: asi se prueba TODO el camino de verdad
		# (bucle, volumen, pausa, efectos) menos la compresion QOA.
		_ok(true, "sin el .sample, poner_musica avisa y no revienta")
		var crudo: AudioStreamWAV = Audio._preparar_bucle(_desde_wav_crudo())
		if crudo == null:
			_ok(false, "se puede leer el .wav crudo para probar el resto")
			print("FALLOS: %d" % fallos)
			print("PRUEBA MUSICA OK")
			get_tree().quit()
			return
		Audio._temas["circuito"] = crudo
		print("  ---- 'circuito' aun SIN IMPORTAR (falta abrir el editor una vez).")
		print("  ---- lo que sigue corre sobre el PCM crudo del mismo .wav.")

	# --- el stream viene preparado para dar la vuelta
	var s: AudioStreamWAV = Audio._temas["circuito"]
	_ok(s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "loop_mode = LOOP_FORWARD")
	var esperadas := int(s.get_length() * float(s.mix_rate))
	_ok(s.loop_end == esperadas and s.loop_end > 0,
		"loop_end en MUESTRAS: %d (con 0 no daria la vuelta)" % s.loop_end)
	_ok(s.mix_rate == 22050, "el tema va a %d Hz" % s.mix_rate)
	_ok(not s.stereo, "el tema es mono")
	_ok(s.get_length() >= 60.0 and s.get_length() <= 90.0,
		"el bucle dura %.2f s" % s.get_length())

	# --- suena, y sigue sonando
	Audio.poner_musica("circuito", 0.1)
	await get_tree().create_timer(0.3).timeout
	_ok(Audio._musica.playing, "poner_musica('circuito') arranca")
	var pos0: float = Audio._musica.get_playback_position()
	await get_tree().create_timer(0.4).timeout
	_ok(Audio._musica.get_playback_position() > pos0, "y avanza")

	# --- pedirlo otra vez NO lo reinicia (si no, cada portal cortaria el tema)
	var pos1: float = Audio._musica.get_playback_position()
	Audio.poner_musica("circuito")
	await get_tree().create_timer(0.2).timeout
	_ok(Audio._musica.get_playback_position() > pos1,
		"repetir poner_musica del mismo tema no lo reinicia")

	# --- los efectos NO pisan la musica (sonar() reescribe volume_db por voz)
	var vol_antes: float = Audio._musica.volume_db
	for n in ["salto", "aterrizaje", "impulso", "fragmento", "terminal", "salto",
			  "aviso", "puerta", "portal", "muerte"]:
		Audio.sonar(n)
	await get_tree().create_timer(0.15).timeout
	_ok(is_equal_approx(Audio._musica.volume_db, vol_antes),
		"diez efectos seguidos no tocan el volumen de la musica")
	_ok(Audio._musica.playing, "y la musica sigue sonando")

	# --- la vuelta del bucle, de verdad, sin esperar 68 s: mismo stream con un
	# loop_end corto. Lo que se mide es que un QOA con LOOP_FORWARD REBOBINA.
	var corto: AudioStreamWAV = s.duplicate() as AudioStreamWAV
	corto.loop_mode = AudioStreamWAV.LOOP_FORWARD
	corto.loop_begin = 0
	corto.loop_end = int(0.5 * float(corto.mix_rate))
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.stream = corto
	p.play()
	await get_tree().create_timer(1.3).timeout
	var dio_la_vuelta: bool = p.playing and p.get_playback_position() < 0.5
	_ok(dio_la_vuelta, "el bucle rebobina: a 1,3 s sigue sonando en %.3f s"
		% p.get_playback_position())
	p.stop()
	p.queue_free()

	# --- con el juego congelado la musica NO se corta: se hunde
	get_tree().paused = true
	Audio.musica_atenuada(true)
	await get_tree().create_timer(0.35).timeout
	var db_pausa := AudioServer.get_bus_volume_db(bus)
	_ok(Audio._musica.playing, "pausado, la musica sigue sonando (no se corta)")
	_ok(absf(db_pausa - (linear_to_db(0.55) + Audio.ATENUACION)) < 0.3,
		"pausado, el bus baja a %.2f dB (el Tween corre con el arbol pausado)" % db_pausa)
	Audio.musica_atenuada(false)
	await get_tree().create_timer(0.35).timeout
	var db_vuelta := AudioServer.get_bus_volume_db(bus)
	get_tree().paused = false
	_ok(absf(db_vuelta - linear_to_db(0.55)) < 0.3,
		"al cerrar la pausa vuelve a %.2f dB" % db_vuelta)

	# --- parar
	Audio.parar_musica(0.1)
	await get_tree().create_timer(0.35).timeout
	_ok(not Audio._musica.playing, "parar_musica la apaga con fundido")

	print("FALLOS: %d" % fallos)
	print("PRUEBA MUSICA OK")
	get_tree().quit()

## Lee el .wav de origen con FileAccess y arma el AudioStreamWAV sin pasar por
## el importador. Solo vale dentro de la prueba: en el juego exportado los .wav
## de origen no viajan, por eso audio.gd carga el recurso importado y no esto.
func _desde_wav_crudo() -> AudioStreamWAV:
	var f := FileAccess.open("res://arte/sonido/circuito.wav", FileAccess.READ)
	if f == null:
		return null
	var todo: PackedByteArray = f.get_buffer(int(f.get_length()))
	f.close()
	var i := 12                                    # saltar "RIFF....WAVE"
	while i + 8 <= todo.size():
		var id: String = todo.slice(i, i + 4).get_string_from_ascii()
		var tam: int = todo.decode_u32(i + 4)
		if id == "data":
			var s := AudioStreamWAV.new()
			s.format = AudioStreamWAV.FORMAT_16_BITS
			s.mix_rate = 22050
			s.stereo = false
			s.data = todo.slice(i + 8, i + 8 + tam)
			return s
		i += 8 + tam + (tam & 1)                   # los trozos van a par
	return null
