extends Node
const SALIDA := "user://capint"
var n: Node2D
var jug: CharacterBody2D
var it: Area2D
var pu: StaticBody2D
var cam: Camera2D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	n = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador"); it = n.get_node("Interruptor"); pu = n.get_node("Puerta")
	cam = Camera2D.new(); cam.zoom = Vector2(3.0, 3.0)
	add_child(cam); cam.make_current()
	for i in 8: await get_tree().process_frame
	jug.global_position = it.global_position + Vector2(-46, 2)
	cam.position = it.global_position + Vector2(0, -6)
	Input.action_press("mover_der")
	for i in 30: await get_tree().process_frame
	Input.action_release("mover_der")
	for i in 4: await get_tree().process_frame
	print("dentro=%s  a %.0f px" % [it._dentro, jug.global_position.distance_to(it.global_position)])
	await _tirar("1_aviso_E")          # el rotulo E flotando sobre la terminal
	it.activar()
	for i in 3: await get_tree().process_frame
	await _tirar("2_accionada")        # destello y chispas al accionar
	for i in 30: await get_tree().process_frame
	print("muertes: %d  usado: %s" % [n._muertes, it._usado])
	cam.position = pu.global_position
	await _tirar("3_puerta_abierta")
	print("puerta abierta: %s" % pu.abierta)
	print("CAPTURAS LISTAS")
	get_tree().quit()

func _tirar(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SALIDA, nom])
	print("CAP ", nom)
