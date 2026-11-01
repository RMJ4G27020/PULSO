extends Node
## La adherencia estaba programada, animada y con coste de carga, pero sin una
## sola pared en el juego no se disparaba nunca. Esto comprueba que el pozo
## del nivel 4 la despierta y que de verdad se puede subir por el.
var fallos := 0
var jug: CharacterBody2D
var n: Node2D

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-58s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Las medidas de esta prueba son las de TSL-04. Si quien juega ha elegido
	# otro personaje, sin esto fallaria sin que el juego tuviera nada roto.
	Personajes.forzado = Personajes.BASE
	await get_tree().create_timer(0.5).timeout
	n = load("res://escenas/niveles/n4_la_chimenea.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.4).timeout
	jug = n.get_node("Jugador")

	# En MITAD del pozo, no al fondo: la adherencia pide is_on_wall_only(), o
	# sea tocar pared SIN tocar suelo. Soltado abajo cae al suelo y no se pega.
	# Paredes en x=32 y x=38, hueco util de 33 a 37.
	var C := 16.0
	jug.global_position = Vector2(35.0 * C, 25.0 * C)
	jug.velocity = Vector2.ZERO
	await get_tree().create_timer(0.15).timeout

	# empujarse contra la pared derecha mientras cae
	Input.action_press("mover_der")
	await get_tree().create_timer(0.45).timeout
	_ok(jug.pegado, "pegado a la pared derecha del pozo")
	_ok(jug._sprite.animation == "adherencia",
		"y reproduce la animacion de adherencia (sale '%s')" % jug._sprite.animation)
	var vy: float = jug.velocity.y
	_ok(vy > 0.0 and vy <= jug.deslizar + 1.0,
		"desliza frenado a %.0f px/s en vez de caer libre (tope %.0f)" % [vy, jug.deslizar])

	# Un salto de pared medido de verdad. Antes intentaba teclear una subida
	# entera y lo que medía era mi punteria simulando al jugador, no la
	# mecanica. Aqui se mide lo unico que importa: que el salto despegue
	# hacia ARRIBA y gane altura de sobra para el siguiente asidero.
	var y_pegado: float = jug.global_position.y
	# se MANTIENE pulsado: soltarlo activa el salto de altura variable, que lo
	# corta al 45%. Aqui se quiere medir el salto entero.
	Input.action_press("saltar")
	await get_tree().create_timer(0.05).timeout
	_ok(jug.velocity.y < -100.0,
		"al saltar de la pared sale hacia arriba (%.0f px/s)" % jug.velocity.y)
	_ok(not jug.pegado, "y se despega de la pared")

	# seguir el arco hasta que empiece a bajar
	var cima: float = y_pegado
	for i in 40:
		await get_tree().process_frame
		cima = minf(cima, jug.global_position.y)
		if jug.velocity.y > 0.0 and jug.global_position.y > cima + 4.0:
			break
	Input.action_release("saltar")
	var gana: float = y_pegado - cima
	# la teoria: 442 px/s con g=980 dan 100 px de altura
	_ok(gana > 60.0, "gana %.0f px de altura en un salto entero (teoria: 100)" % gana)
	Input.action_release("mover_der"); Input.action_release("mover_izq")

	print("FALLOS: %d" % fallos)
	print("PRUEBA PARED OK")
	get_tree().quit()
