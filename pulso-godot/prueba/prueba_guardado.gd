extends Node
## El progreso tiene que sobrevivir al cierre y no reventar si el archivo
## se corrompe (un movil se queda sin bateria a media escritura).
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-56s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Esta prueba escribe en el archivo de progreso DE VERDAD: lo borra al
	# empezar y lo deja corrupto al acabar. Sin devolverlo como estaba, pasar
	# las pruebas te borra la partida y deja un aviso en cada arranque.
	var habia: bool = FileAccess.file_exists(Guardado.RUTA)
	var copia := PackedByteArray()
	if habia:
		copia = FileAccess.get_file_as_bytes(Guardado.RUTA)

	Guardado.borrar_todo()
	_ok(Guardado.nivel_desbloqueado(1), "el nivel 1 empieza desbloqueado")
	_ok(not Guardado.nivel_desbloqueado(2), "el nivel 2 empieza bloqueado")

	Guardado.completar_nivel(1, 42.5, 2)
	_ok(Guardado.nivel_desbloqueado(2), "completar el 1 desbloquea el 2")
	_ok(is_equal_approx(Guardado.mejor_tiempo(1), 42.5), "guarda el tiempo (%.1f)" % Guardado.mejor_tiempo(1))
	_ok(Guardado.fragmentos(1) == 2, "guarda los fragmentos (%d)" % Guardado.fragmentos(1))

	Guardado.completar_nivel(1, 99.0, 1)
	_ok(is_equal_approx(Guardado.mejor_tiempo(1), 42.5), "un tiempo PEOR no pisa al mejor")
	_ok(Guardado.fragmentos(1) == 2, "menos fragmentos no pisan a los que ya tenias")

	Guardado.completar_nivel(1, 30.0, 3)
	_ok(is_equal_approx(Guardado.mejor_tiempo(1), 30.0), "un tiempo MEJOR si lo pisa (%.1f)" % Guardado.mejor_tiempo(1))

	Guardado.sumar_muerte(); Guardado.sumar_muerte()
	_ok(Guardado.muertes_totales() == 2, "cuenta las muertes (%d)" % Guardado.muertes_totales())

	# como si se cerrara y volviera a abrir
	Guardado.cargar()
	_ok(is_equal_approx(Guardado.mejor_tiempo(1), 30.0), "sobrevive a cerrar y abrir")
	_ok(Guardado.nivel_desbloqueado(2), "el desbloqueo tambien sobrevive")

	# archivo corrompido a media escritura
	var f := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
	f.store_string('{"max_nivel": 3, "tiem')
	f.close()
	Guardado.cargar()
	_ok(Guardado.nivel_desbloqueado(1), "un archivo corrupto no revienta: empieza de cero")

	_restaurar(habia, copia)
	_ok(FileAccess.file_exists(Guardado.RUTA) == habia,
		"y deja el archivo de progreso como estaba")

	print("FALLOS: %d" % fallos)
	print("PRUEBA GUARDADO OK")
	get_tree().quit()

func _restaurar(habia: bool, copia: PackedByteArray) -> void:
	if habia:
		var f := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if f != null:
			f.store_buffer(copia)
			f.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
