extends Node
## La sombra de contacto de TSL-04. No se puede probar si "se ve bien"; se
## prueba lo que se rompe en silencio: que este en el suelo y no a un desfase
## fijo, que diga la altura de forma monotona, que no aparezca donde no hay
## suelo, que no sobreviva al jugador muerto, y que vaya detras del sprite.

var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-58s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Las medidas de esta prueba son las de TSL-04. Si quien juega ha elegido
	# otro personaje, sin esto fallaria sin que el juego tuviera nada roto.
	Personajes.forzado = Personajes.BASE
	# guardia: ninguna prueba puede colgarse
	get_tree().create_timer(60.0).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.5).timeout
	var j: CharacterBody2D = n.get_node("Jugador")
	var s: Node2D = j.get_node_or_null("Sombra")
	_ok(s != null, "el jugador lleva sombra")
	if s == null:
		_fin()
		return

	# detras del sprite: el orden de dibujo es el del arbol, sin z_index
	var sp: Node = j.get_node("Sprite")
	_ok(s.get_index() < sp.get_index(),
		"la sombra va antes que el sprite en el arbol (%d < %d)" % [s.get_index(), sp.get_index()])
	_ok(not s.top_level, "y sin top_level, que la sacaria del orden del padre")

	# El jugador quieto por codigo para medir alturas exactas. Sin fisica propia
	# se caeria entre medidas; la gracia evita que la estela lo mate.
	j.set_physics_process(false)
	j._t_gracia = 99.0
	var base: Vector2 = j.global_position

	j.global_position = base
	for i in 3: await get_tree().physics_frame
	_ok(absf(s.altura) < 2.0, "de pie, la sombra esta a ras de suelo (%.1f px)" % s.altura)
	_ok(is_equal_approx(s.escala, 1.0) and s.alfa > 0.5,
		"y a tamano y opacidad maximos (escala %.2f, alfa %.2f)" % [s.escala, s.alfa])
	var y_suelo: float = s.global_position.y

	# subiendo, la sombra se queda EN EL SUELO y encoge y se aclara
	var antes_e := 99.0
	var antes_a := 99.0
	var monotona := true
	var quieta := true
	for h in [10.0, 30.0, 60.0, 90.0, 115.0, 140.0]:
		j.global_position = base - Vector2(0.0, h)
		for i in 3: await get_tree().physics_frame
		if s.escala > antes_e + 0.0001 or s.alfa > antes_a + 0.0001:
			monotona = false
		if absf(s.global_position.y - y_suelo) > 1.0:
			quieta = false
		antes_e = s.escala
		antes_a = s.alfa
	_ok(monotona, "al subir, tamano y opacidad bajan sin volver a subir")
	_ok(quieta, "y la sombra se queda en el suelo, no sube con el jugador")

	# en la cima de un salto normal tiene que seguir viendose: es cuando dice
	# donde vas a caer
	j.global_position = base - Vector2(0.0, 115.0)
	for i in 3: await get_tree().physics_frame
	_ok(s.alfa > 0.08, "en la cima de un salto (115 px) sigue visible (alfa %.3f)" % s.alfa)

	# por encima del limite, nada
	j.global_position = base - Vector2(0.0, 200.0)
	for i in 3: await get_tree().physics_frame
	_ok(s.alfa == 0.0, "a 200 px del suelo no hay sombra")

	# sobre el vacio: muy lejos de toda plataforma, hacia abajo
	j.global_position = Vector2(base.x, 5000.0)
	for i in 3: await get_tree().physics_frame
	_ok(s.altura < 0.0 and s.alfa == 0.0, "sobre el vacio no se dibuja")

	# muerto, nada
	j.global_position = base
	for i in 3: await get_tree().physics_frame
	j._t_gracia = 0.0
	j.morir()
	for i in 3: await get_tree().physics_frame
	_ok(s.alfa == 0.0, "con el jugador muerto no hay sombra")
	_fin()

var _acabado := false
func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	print("FALLOS: %d" % fallos)
	print("PRUEBA SOMBRA OK")
	get_tree().quit()
