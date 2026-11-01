extends Node
## Muerte: pausa, reinicio de peligros, gracia al reaparecer y caida al vacio.
var n: Node2D
var jug: CharacterBody2D
var dron: Node2D
var t := 0.0
var paso := 0
var t_muerte := 0.0
var pos_dron_ini: Vector2
var fallos := 0

func _ready() -> void:
	# Las medidas de esta prueba son las de TSL-04. Si quien juega ha elegido
	# otro personaje, sin esto fallaria sin que el juego tuviera nada roto.
	Personajes.forzado = Personajes.BASE
	n = load("res://escenas/niveles/n2_el_corredor.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	# por tipo, no por nombre: el indice del nodo cambia si se reordenan los obstaculos
	for pel in get_tree().get_nodes_in_group("peligro"):
		if pel.get_script() and pel.get_script().resource_path.ends_with("dron_purga.gd"):
			dron = pel; break
	assert(dron != null)

func _proc(ok: bool, txt: String) -> void:
	if not ok: fallos += 1
	print("  %-46s %s" % [txt, "OK" if ok else "FALLA"])

func _process(d: float) -> void:
	t += d
	match paso:
		0:
			if t > 0.6:
				pos_dron_ini = dron._a      # su origen real, no donde este ahora patrullando
				# meterse encima del dron para que lo vea, lo persiga y lo mate
				jug.global_position = dron.global_position + Vector2(0, -2)
				paso = 1; t = 0.0
		1:
			if not jug.vivo:
				t_muerte = t
				_proc(dron._alerta, "el dron entra en alerta al verte")
				paso = 2; t = 0.0
			elif t > 2.0:
				_proc(false, "el dron deberia haberte matado")
				paso = 9; t = 0.0
		2:
			if jug.vivo:
				_proc(t > 0.7 and t < 1.3, "pausa de muerte de %.2f s (se busca 0.85)" % t)
				_proc(not dron._alerta, "el dron sale de alerta al reiniciar")
				_proc(dron.global_position.distance_to(pos_dron_ini) < 2.0,
					"el dron vuelve a su sitio (a %.0f px)" % dron.global_position.distance_to(pos_dron_ini))
				_proc(jug._t_gracia > 0.0, "reaparece con gracia (%.2f s)" % jug._t_gracia)
				jug.morir()
				_proc(jug.vivo, "durante la gracia no le pueden matar")
				paso = 3; t = 0.0
		3:
			if t > jug.gracia + 0.15:
				_proc(jug._t_gracia == 0.0 and jug.modulate.a == 1.0,
					"al acabar la gracia deja de parpadear (alfa %.2f)" % jug.modulate.a)
				# caida al vacio
				jug.global_position = Vector2(400, n.limite_caida + 40)
				paso = 4; t = 0.0
		4:
			if t > 0.4:
				_proc(not jug.vivo or n._muertes >= 2, "caer al vacio mata (limite y=%.0f)" % n.limite_caida)
				paso = 9; t = 0.0
		9:
			if t > 0.2:
				print("FALLOS: %d" % fallos)
				print("PRUEBA MUERTE OK")
				get_tree().quit()
