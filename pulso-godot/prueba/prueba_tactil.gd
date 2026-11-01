extends Node
## Lo que rompe en los mandos tactiles mal hechos es el multitactil: mover con
## un pulgar mientras saltas con el otro, y que soltar uno no suelte el otro.
var fallos := 0
var mandos: Control

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-58s %s" % [txt, "OK" if c else "FALLA"])

## Los eventos se inyectan en espacio de VENTANA y el Control los recibe en
## espacio de viewport: con estiramiento canvas_items (ventana 1280 sobre
## viewport 640) Godot los divide entre dos por el camino. Hay que compensar
## o la prueba toca en otro sitio del que cree.
var escala := 1.0

## Esperar FRAMES no vale: parse_input_event() encola el evento y en el
## arranque en frio (importando recursos, compilando shaders) los primeros
## frames son largos e irregulares, asi que la prueba fallaba una de cada
## tres corridas. Esperar tiempo real no depende de la cadencia de frames.
func _asentar() -> void:
	await get_tree().create_timer(0.06).timeout

func _toque(indice: int, pos: Vector2, pulsado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = indice; e.position = pos * escala; e.pressed = pulsado
	Input.parse_input_event(e)

func _arrastre(indice: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = indice; e.position = pos * escala
	Input.parse_input_event(e)

func _ready() -> void:
	# dejar que el motor termine de arrancar antes de medir nada
	await get_tree().create_timer(0.5).timeout
	var esc: Node = load("res://escenas/Tactil.tscn").instantiate()
	add_child(esc)
	mandos = esc.get_node("Mandos")
	# por si una corrida anterior dejo acciones pulsadas
	for a in ["mover_izq", "mover_der", "saltar", "impulso", "pulso"]:
		Input.action_release(a)
	await _asentar()
	var r: Vector2 = get_viewport().get_visible_rect().size
	escala = float(get_window().size.x) / r.x
	print("    viewport %s   ventana %s   escala x%.2f" % [r, get_window().size, escala])
	# se lee el centro REAL del boton en vez de recalcularlo aqui: si duplico
	# la aritmetica, la prueba puede pasar con los dos lados equivocados
	var b_saltar: Vector2 = mandos._botones["saltar"]
	print("    centro de saltar %s" % b_saltar)

	# --- el joystick nace donde pones el dedo
	_toque(0, Vector2(120, 300), true)
	await _asentar()
	_ok(not Input.is_action_pressed("mover_der") and not Input.is_action_pressed("mover_izq"),
		"tocar sin arrastrar no mueve todavia")

	_arrastre(0, Vector2(190, 300))
	await _asentar()
	_ok(Input.is_action_pressed("mover_der"), "arrastrar a la derecha mueve a la derecha")

	_arrastre(0, Vector2(60, 300))
	await _asentar()
	_ok(Input.is_action_pressed("mover_izq") and not Input.is_action_pressed("mover_der"),
		"cambiar de lado suelta el sentido anterior")

	# --- multitactil: saltar sin dejar de moverse
	_toque(1, b_saltar, true)
	await _asentar()
	_ok(Input.is_action_pressed("saltar"), "el segundo dedo pulsa saltar")
	_ok(Input.is_action_pressed("mover_izq"), "y NO deja de moverse mientras salta")

	_toque(1, b_saltar, false)
	await _asentar()
	_ok(not Input.is_action_pressed("saltar"), "soltar el boton suelta saltar")
	_ok(Input.is_action_pressed("mover_izq"), "pero el movimiento sigue con el otro dedo")

	_toque(0, Vector2(60, 300), false)
	await _asentar()
	_ok(not Input.is_action_pressed("mover_izq"), "soltar el pulgar para de moverse")

	# --- un toque en el vacio de la derecha no hace nada
	_toque(2, Vector2(r.x * 0.7, 40), true)
	await _asentar()
	var algo := Input.is_action_pressed("saltar") or Input.is_action_pressed("impulso") \
		or Input.is_action_pressed("pulso") or Input.is_action_pressed("mover_der")
	_ok(not algo, "tocar el vacio de la derecha no dispara nada")
	_toque(2, Vector2(r.x * 0.7, 40), false)

	# --- si entra una llamada hay que soltarlo todo
	_toque(3, Vector2(120, 300), true)
	_arrastre(3, Vector2(200, 300))
	await _asentar()
	_ok(Input.is_action_pressed("mover_der"), "moviendose antes de perder el foco")
	mandos.soltar_todo()
	await _asentar()
	_ok(not Input.is_action_pressed("mover_der"),
		"perder el foco lo suelta todo (si no, sigue corriendo solo)")

	# --- y al cambiar de escena con el dedo puesto, tambien. El cambio de nivel
	# no espera a que levantes el pulgar, y las acciones de action_press son
	# globales: sin esto, mover_der seguia pulsado en el nivel siguiente.
	_toque(4, Vector2(120, 300), true)
	_arrastre(4, Vector2(200, 300))
	await _asentar()
	_ok(Input.is_action_pressed("mover_der"), "moviendose al cruzar el portal")
	esc.queue_free()
	await _asentar()
	_ok(not Input.is_action_pressed("mover_der"),
		"si los mandos salen de la escena, sueltan lo que tenian pulsado")

	print("FALLOS: %d" % fallos)
	print("PRUEBA TACTIL OK")
	get_tree().quit()
