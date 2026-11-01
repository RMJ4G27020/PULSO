extends Node
const SALIDA := "user://capniv"
## el viewport del juego es 640x360, no 1280x720: el zoom va a la mitad
## una vista cercana para juzgar la textura, y una general
## zoom 1.0 = lo que se ve jugando (la camara del jugador no lo cambia)
const CASOS := [["n4_la_chimenea", 560, 400, 1.0], ["n4_la_chimenea", 560, 470, 0.55]]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	for c in CASOS:
		var id: String = c[0]
		var n: Node2D = load("res://escenas/niveles/%s.tscn" % id).instantiate() as Node2D
		add_child(n)
		var cam := Camera2D.new()
		cam.zoom = Vector2(c[3], c[3])
		cam.position = Vector2(c[1], c[2])
		add_child(cam); cam.make_current()
		for i in 25: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%.2f.png" % [SALIDA, id, c[3]])
		print("CAP ", id, c[3])
		cam.queue_free(); n.queue_free()
		for i in 4: await get_tree().process_frame
	print("CAPTURAS LISTAS")
	get_tree().quit()
