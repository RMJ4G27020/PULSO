extends Node
## Conduce a TSL-04 por todos los estados y registra que animaciones salen.

var jug: CharacterBody2D
var vistas := {}
var paso := 0

func _ready() -> void:
	var niv: Node = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate()
	add_child(niv)
	jug = niv.get_node("Jugador")

func _anotar() -> void:
	var a: String = jug.get_node("Sprite").animation
	if not vistas.has(a):
		vistas[a] = paso

func _physics_process(_d: float) -> void:
	if jug == null:
		return
	_anotar()
	paso += 1

	match paso:
		30: Input.action_press("mover_der")
		60:
			Input.action_release("mover_der")
			Input.action_press("mover_izq")   # cambio de sentido en el suelo -> giro
		75:
			Input.action_release("mover_izq")
			Input.action_press("mover_der")
		90: Input.action_press("saltar")
		93: Input.action_release("saltar")
		150: Input.action_press("impulso")
		152: Input.action_release("impulso")
		200:
			# soltar contra la pared izquierda, en el aire, empujando hacia ella
			Input.action_release("mover_der")
			jug.global_position = Vector2(52, 400)   # junto al muro izquierdo del nivel 1
			jug.velocity = Vector2(-160, 60)
			Input.action_press("mover_izq")
		270:
			Input.action_release("mover_izq")
			jug.global_position = Vector2(320, 528)  # sobre el corredor inferior
			jug.velocity = Vector2.ZERO
			jug.carga = 18.0            # por debajo del 25 % y quieto
		300: Input.action_press("mover_der")   # moverse: quieto se muere en su propia estela
		320: jug.celebrar()
		370:
			Input.action_release("mover_der")
			jug.morir()
		420:
			var esperadas := ["reposo", "correr", "giro", "salto", "caida", "aterrizaje",
							  "impulso", "adherencia", "muerte", "aparicion",
							  "carga_baja", "victoria"]
			var faltan := []
			for e in esperadas:
				if not vistas.has(e):
					faltan.append(e)
			print("VISTAS (%d/12): %s" % [vistas.size(), str(vistas.keys())])
			print("FALTAN: ", faltan)
			get_tree().quit()
	if jug != null:
		_anotar()
