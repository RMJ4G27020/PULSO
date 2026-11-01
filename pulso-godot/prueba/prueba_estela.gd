extends Node
## La estela llevaba RELOJ DE PARED (Time.get_ticks_msec()), y eso hacia que
## pausar matara: con el arbol congelado la celda que pisas seguia envejeciendo,
## asi que al reanudar llevaba mas de los 0,35 s del RETARDO y te mataba en el
## primer cuadro. Ahora la rejilla lleva un reloj propio que solo avanza en su
## _process, que es PAUSABLE.
##
## De regalo, el reloj propio hace la estela DETERMINISTA en headless: con
## Time.get_ticks_msec() la misma partida daba marcas distintas cada corrida.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-62s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	# Las medidas de esta prueba son las de TSL-04. Si quien juega ha elegido
	# otro personaje, sin esto fallaria sin que el juego tuviera nada roto.
	Personajes.forzado = Personajes.BASE
	await get_tree().create_timer(0.5).timeout
	await _pausa_no_envejece()
	await _determinismo()
	print("FALLOS: %d" % fallos)
	print("PRUEBA ESTELA OK")
	get_tree().quit()

func _pausa_no_envejece() -> void:
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	# esta prueba corre en ALWAYS para sobrevivir a la pausa y los hijos heredan
	# ese modo; en el juego el nivel es la escena raiz y SI se pausa
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().create_timer(0.4).timeout
	var jug: CharacterBody2D = n.get_node("Jugador")
	var rej: RejillaEstela = n.get_node("Estela")
	# gracia fuera: si no, el jugador es invulnerable y la prueba no mide nada
	# se pausa CORRIENDO: es el caso real. Con el reloj de pared, la celda que
	# pisabas envejecia durante la pausa y al reanudar te mataba en el acto.
	# Se corre hacia la izquierda porque la plataforma de partida de n1 acaba a
	# 64 px a la derecha de la aparicion y el personaje se caeria al vacio.
	Input.action_press("mover_izq")
	await get_tree().create_timer(0.25).timeout
	# la gracia de reaparicion fuera, o la estela no puede matar y no se mide nada
	jug._t_gracia = 0.0
	await get_tree().create_timer(0.05).timeout

	var celda: Vector2i = rej.celda_de(jug.global_position + Vector2(0, 15))
	var antes: float = rej.edad_de(celda)
	var reloj_antes: float = rej.reloj
	get_tree().paused = true
	await get_tree().create_timer(1.0).timeout
	var despues: float = rej.edad_de(celda)
	_ok(antes >= 0.0 and antes < RejillaEstela.RETARDO,
		"al pausar, la celda de debajo aun no ha prendido (%.2f s de %.2f)"
		% [antes, RejillaEstela.RETARDO])
	_ok(absf(rej.reloj - reloj_antes) < 0.02,
		"el reloj de la estela NO avanza con el arbol pausado (%.3f s)"
		% absf(rej.reloj - reloj_antes))
	_ok(absf(despues - antes) < 0.05,
		"la celda pisada no envejece en 1,0 s de pausa (%.2f -> %.2f s)" % [antes, despues])
	get_tree().paused = false
	await get_tree().create_timer(0.3).timeout
	Input.action_release("mover_izq")
	_ok(jug.vivo, "y al reanudar y seguir corriendo el jugador sigue VIVO")
	n.queue_free()
	await get_tree().process_frame

## Misma partida, dos veces: la misma secuencia de celdas.
func _determinismo() -> void:
	var a: Array = await _correr()
	var b: Array = await _correr()
	_ok(a.size() > 3, "la partida deja estela (%d celdas)" % a.size())
	_ok(a == b, "dos partidas identicas dan la misma secuencia de celdas (%d vs %d)"
		% [a.size(), b.size()])

func _correr() -> Array:
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.4).timeout
	var rej: RejillaEstela = n.get_node("Estela")
	Input.action_press("mover_izq")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("mover_izq")
	await get_tree().process_frame
	var celdas: Array = []
	for par in rej._camino:
		celdas.append(par[0])
	n.queue_free()
	await get_tree().process_frame
	return celdas
