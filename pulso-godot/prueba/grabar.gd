extends Node
## Graba la cinematica cuadro a cuadro avanzando el tiempo a mano,
## para que el muestreo sea exacto y no dependa del reloj real.

const FPS := 6.0
const SALIDA := "user://cine"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var c: Control = load("res://escenas/CineIntro.tscn").instantiate()
	c.set_process(false)
	add_child(c)
	for i in 4: await get_tree().process_frame

	var total := 0.0
	for tm in c.TOMAS:
		total += float(tm[1])
	var n := int(total * FPS)
	var idx := 0
	var reloj := 0.0
	print("GRABANDO %.1f s  ->  %d cuadros a %d fps" % [total, n, int(FPS)])

	for toma_i in c.TOMAS.size():
		var dur := float(c.TOMAS[toma_i][1])
		var cuadros := int(round(dur * FPS))
		for k in cuadros:
			c.toma = toma_i
			c.t_toma = (float(k) + 0.5) / FPS
			c.t = reloj + c.t_toma
			c._colocar_actores()
			c.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/f%04d.png" % [SALIDA, idx])
			idx += 1
		reloj += dur
	print("GRABADOS %d cuadros en %s" % [idx, ProjectSettings.globalize_path(SALIDA)])
	get_tree().quit()
