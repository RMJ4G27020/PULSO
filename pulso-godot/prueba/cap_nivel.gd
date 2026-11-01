extends Node
const SALIDA := "user://capniv"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	for nom in ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo"]:
		var n: Node2D = load("res://escenas/niveles/%s.tscn" % nom).instantiate()
		add_child(n)
		for i in 30: await get_tree().process_frame     # que arranquen los ciclos
		var cam := Camera2D.new()
		cam.position = n.get_node("Aparicion").position + Vector2(430, -180)
		cam.zoom = Vector2(0.62, 0.62)
		add_child(cam); cam.make_current()
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SALIDA, nom])
		print("CAP ", nom)
		cam.queue_free(); n.queue_free()
		await get_tree().process_frame
	print("CAPTURAS LISTAS")
	get_tree().quit()
