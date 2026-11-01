extends Node
const SALIDA := "user://capefe"
var n: Node2D
var jug: CharacterBody2D
var cam: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # seguir vivo durante la congelacion
	DirAccess.make_dir_recursive_absolute(SALIDA)
	n = load("res://escenas/niveles/n2_el_corredor.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	cam = Camera2D.new(); cam.zoom = Vector2(2.2, 2.2)
	add_child(cam); cam.make_current()
	for i in 6: await get_tree().process_frame
	# correr un poco para dejar estela y luego morir
	Input.action_press("mover_der")
	for i in 40: await get_tree().process_frame
	Input.action_release("mover_der")
	cam.position = jug.global_position
	await _tirar("antes")
	jug.morir()
	await _tirar("muerte_destello")
	for i in 3: await get_tree().process_frame
	await _tirar("muerte_aberracion")
	Engine.time_scale = 1.0
	for i in 10: await get_tree().process_frame
	await _tirar("muerte_chispas")
	print("CAPTURAS LISTAS")
	get_tree().quit()

func _tirar(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SALIDA, nom])
	print("CAP ", nom)
