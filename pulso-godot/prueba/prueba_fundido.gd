extends Node
## El cambio de nivel era un corte seco: sonar("portal"), celebrar, 1,6 s y
## change_scene_to_file sin nada por medio. Ahora funde a negro, como ya hacia
## la intro (scripts/cine.gd y su ColorRect $Negro), que es el precedente de la
## casa.
##
## La ceremonia NO se puede alargar: en PULSO pararse mata y esta ya es la parte
## mas quieta del juego. Sigue durando ~1,5 s, igual que antes.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-62s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Salir del nivel 1 llama a Guardado.completar_nivel() y escribe el progreso
	# DE VERDAD, con un tiempo de 0,8 s que ninguna persona hace. Esta prueba no
	# lo devolvia: cada vez que corria un poco mas deprisa, "mejoraba" el record
	# del nivel 1 de quien juega. Ahora se copia antes y se devuelve al final,
	# como en las demas pruebas que guardan.
	var habia := FileAccess.file_exists(Guardado.RUTA)
	var copia := FileAccess.get_file_as_bytes(Guardado.RUTA) if habia else PackedByteArray()
	await get_tree().create_timer(0.5).timeout
	await _entrada()
	await _salida()
	if habia:
		var f := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if f != null:
			f.store_buffer(copia)
			f.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA FUNDIDO OK")
	get_tree().quit()

## Al entrar, el nivel arranca en negro y se abre.
func _entrada() -> void:
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().process_frame
	var fun: CanvasLayer = n._fundido
	_ok(fun != null, "el nivel monta el fundido")
	_ok(fun.alfa() > 0.9, "el nivel arranca en negro (alfa %.2f)" % fun.alfa())
	_ok(fun.get_node("Negro").color.a > 0.9, "y el ColorRect lo refleja")
	await get_tree().create_timer(0.5).timeout
	_ok(fun.alfa() < 0.01, "y funde a la vista en 0,35 s (alfa %.2f)" % fun.alfa())
	n.queue_free()
	await get_tree().process_frame

## Al salir, la pantalla tiene que estar NEGRA antes del cambio de escena, o el
## corte se ve igual que antes.
func _salida() -> void:
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.5).timeout
	var jug: CharacterBody2D = n.get_node("Jugador")
	var fun: CanvasLayer = n._fundido
	n._inter.activar()
	await get_tree().create_timer(0.3).timeout

	# la ceremonia deja al personaje QUIETO sobre el portal mas de los 0,35 s del
	# RETARDO de la estela: sin la gracia de celebrar() se mata el solo en plena
	# victoria. Se le quita la gracia justo antes para medirlo de verdad.
	jug._t_gracia = 0.0
	n._al_salir()
	# Durante la ceremonia no se abre la pausa, ni con el boton ni con atras. Con
	# el arbol parado, la pausa se quedaba DEBAJO del fundido (pantalla negra sin
	# salida) y "Reiniciar" no servia: al cerrarla, la salida seguia su curso.
	await get_tree().create_timer(0.3).timeout
	n._abrir_pausa()
	n._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_ok(not n._pausa.abierto and not get_tree().paused,
		"durante la ceremonia de salida no se puede abrir la pausa")
	var t := 0.3                # esos 0,3 s ya son parte de la ceremonia
	var t_opaco := -1.0
	var murio := false
	while t < 1.45:
		await get_tree().create_timer(0.02).timeout
		t += 0.02
		if not jug.vivo:
			murio = true
		if t_opaco < 0.0 and fun.opaco():
			t_opaco = t
			break
	_ok(not murio, "durante la ceremonia el jugador NO muere por su propia estela")
	_ok(t_opaco > 0.0, "la pantalla llega a negro ANTES del cambio de escena")
	_ok(t_opaco > 1.2 and t_opaco < 1.55,
		"y la ceremonia entera sigue durando ~1,5 s (negro a los %.2f s)" % t_opaco)
	# se sale antes de que _siguiente() cambie de escena y se lleve la prueba
	n.queue_free()
	await get_tree().process_frame
