extends Node
## Fotos de los dos niveles grandes, a lo largo de la ruta: para mirarlos con los
## ojos (que las cortinas, balizas y drones se lean). Con ventana:
##   Godot --path . prueba/capgrandes.tscn
## Salen en user://grandes. El jugador se lleva a cada punto y se fotografia.

const SALIDA := "user://grandes"
const PUNTOS := {
	"n5_lasermania": [[16, 89], [60, 89], [113, 89], [150, 82], [230, 69], [300, 65], [340, 57], [380, 53], [420, 71], [480, 89], [505, 83], [536, 89]],
	"n6_runthedrun": [[16, 65], [60, 66], [131, 63], [180, 66], [220, 68], [280, 66], [309, 66], [360, 64], [409, 59], [460, 60], [495, 60]],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SALIDA)
	get_tree().create_timer(200.0).timeout.connect(func(): get_tree().quit())
	Personajes.forzado = Personajes.BASE
	get_window().size = Vector2i(1280, 720)
	await _esperar(6)
	for nom in PUNTOS:
		var n: Node2D = load("res://escenas/niveles/%s.tscn" % nom).instantiate()
		add_child(n)
		await _esperar(4)
		var j: CharacterBody2D = n.get_node("Jugador")
		j._celebrando = true
		j._t_gracia = 9999.0
		j.modulate.a = 1.0
		var k := 0
		for p in PUNTOS[nom]:
			j.global_position = Vector2(p[0] * 16.0, p[1] * 16.0)
			j.velocity = Vector2.ZERO
			(j.get_node("Camara") as Camera2D).reset_smoothing()
			await get_tree().create_timer(0.5).timeout
			await _guardar("%s_%02d.png" % [nom, k])
			k += 1
		n.queue_free()
		await _esperar(4)
	Personajes.forzado = ""
	print("LISTO en " + ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s" % [SALIDA, nombre])


func _esperar(c: int) -> void:
	for i in c:
		await get_tree().process_frame
