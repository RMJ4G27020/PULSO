extends Node
## Mide llamadas de dibujado con la estela llena, contra el presupuesto del GDD.

var n: Node2D
var jug: CharacterBody2D
var t := 0.0
var pico := 0
var pico_celdas := 0

func _ready() -> void:
	n = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	await get_tree().process_frame
	Input.action_press("mover_der")

func _process(d: float) -> void:
	t += d
	if t < 0.6: return
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	pico = maxi(pico, dc)
	var rej = n.get_node("Estela")
	pico_celdas = maxi(pico_celdas, rej._marcas.size())
	if t > 2.5 and t < 2.6:
		jug.morir()                       # medir tambien con los efectos disparados
	if t > 5.0:
		Input.action_release("mover_der")
		print("CELDAS vivas (pico): %d" % pico_celdas)
		print("DRAW CALLS (pico): %d   presupuesto GDD: 60" % pico)
		print("FPS: %.0f" % Engine.get_frames_per_second())
		print("PRUEBA RENDIMIENTO OK")
		get_tree().quit()
