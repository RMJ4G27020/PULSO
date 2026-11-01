extends Node
## Guarda capturas del menu y de varias tomas de la cinematica.

const SALIDA := "user://cap"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await _captura_menu()
	await _captura_cine()
	print("CAPTURAS EN: ", ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()

func _tirar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SALIDA, nombre])
	print("CAP ", nombre, " ", img.get_width(), "x", img.get_height())

func _captura_menu() -> void:
	var m: Control = load("res://escenas/MenuPrincipal.tscn").instantiate()
	add_child(m)
	for i in 5: await get_tree().process_frame
	await _tirar("menu_jugar")
	m.sel = 3
	m._reten = 1.7
	m.queue_redraw()
	for i in 3: await get_tree().process_frame
	await _tirar("menu_salir")
	m._panel = "controles"
	m.queue_redraw()
	for i in 3: await get_tree().process_frame
	await _tirar("menu_opciones")
	m.queue_free()
	await get_tree().process_frame

func _captura_cine() -> void:
	var c: Control = load("res://escenas/CineIntro.tscn").instantiate()
	c.set_process(false)                     # control manual de la toma
	add_child(c)
	for i in 3: await get_tree().process_frame
	for idx in [0, 2, 4, 5, 6, 7, 8]:
		c.toma = idx
		c.t_toma = float(c.TOMAS[idx][1]) * 0.55
		c.t = 5.0
		c._colocar_actores()
		c.queue_redraw()
		for i in 3: await get_tree().process_frame
		await _tirar("cine_%d_%s" % [idx + 1, c._nombre()])
	c.queue_free()
