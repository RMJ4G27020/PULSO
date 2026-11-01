extends Node
const SALIDA := "user://capintro"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var c: Control = load("res://escenas/CineIntro.tscn").instantiate()
	c.set_process(false)
	add_child(c)
	for i in 4: await get_tree().process_frame
	for b in [2, 3, 5, 9, 10, 15]:
		c.beat = b
		c.t_beat = float(c.BEATS[b][1]) * 0.6
		c.fase = "laminas"
		c.call("_colocar")
		c._lamina.modulate.a = 1.0
		c._tira.modulate.a = 1.0
		# las dos mitades del par que hierve
		c._lamina.texture = c._tex[b][0]
		for i in 3: await get_tree().process_frame
		await _tirar("b%02d" % b)
	c.fase = "rotulo"; c._negro.color.a = 1.0; c._rotulo.modulate.a = 1.0
	for i in 3: await get_tree().process_frame
	await _tirar("rotulo")
	print("CAPTURAS EN ", ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()

func _tirar(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SALIDA, n])
	print("CAP ", n)
