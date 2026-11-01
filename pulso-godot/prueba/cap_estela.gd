extends Node
const SALIDA := "user://capest"
var n: Node2D
var jug: CharacterBody2D
var cam: Camera2D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	n = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	cam = Camera2D.new(); cam.zoom = Vector2(2.6, 2.6)
	add_child(cam); cam.make_current()
	for i in 5: await get_tree().process_frame
	Input.action_press("mover_der")
	# dejar que corra y vaya dejando estela
	for paso in 3:
		for i in 46: await get_tree().process_frame
		cam.position = jug.global_position + Vector2(-40, -10)
		for i in 2: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/estela%d.png" % [SALIDA, paso])
		print("CAP estela%d  carga=%.0f  vivo=%s" % [paso, jug.carga, jug.vivo])
	Input.action_release("mover_der")
	print("CAPTURAS LISTAS")
	get_tree().quit()
