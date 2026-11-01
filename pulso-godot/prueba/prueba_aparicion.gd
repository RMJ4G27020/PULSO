extends Node
## El jugador tiene que NACER en la aparicion.
##
## Hasta ahora ningun .tscn a mano traia linea "position" para el nodo Jugador y
## nivel.gd solo lo colocaba en reiniciar(), que se llama al MORIR. Al entrar en
## un nivel nacia en (0,0) y caia desde la esquina superior izquierda hasta la
## zona del portal de SALIDA: 481 px de error en n1, 641 en n4. Y la animacion
## "aparicion" no se veia nunca.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-62s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	for nom in ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo", "n4_la_chimenea",
			"n5_lasermania", "n6_runthedrun"]:
		await _mirar(load("res://escenas/niveles/%s.tscn" % nom).instantiate() as Node2D, nom)
	print("FALLOS: %d" % fallos)
	print("PRUEBA APARICION OK")
	get_tree().quit()

func _mirar(n: Node2D, nom: String) -> void:
	add_child(n)
	# al PRIMER cuadro jugable: mas tarde ya ha caido la celda que separa la
	# aparicion del suelo y la animacion unica ha terminado
	await get_tree().process_frame
	await get_tree().process_frame
	var jug: CharacterBody2D = n.get_node("Jugador")
	var ap: Marker2D = n.get_node("Aparicion")
	var spr: AnimatedSprite2D = jug.get_node("Sprite")
	var d: float = jug.global_position.distance_to(ap.global_position)
	_ok(d < 4.0, "%-14s nace en la aparicion (%.0f px de ella)" % [nom, d])
	_ok(spr.animation == "aparicion",
		"%-14s reproduce 'aparicion' al entrar (es '%s')" % [nom, spr.animation])

	await get_tree().create_timer(0.45).timeout
	_ok(jug.is_on_floor(), "%-14s aterriza en suelo firme, no cae al vacio" % nom)
	var sal: Node2D = n.get_node_or_null("Salida")
	if sal:
		var ds: float = jug.global_position.distance_to(sal.global_position)
		_ok(ds > 100.0, "%-14s no nace encima del portal de salida (%.0f px)" % [nom, ds])
	n.queue_free()
	await get_tree().process_frame
