extends SceneTree
func _init():
	var fallos := 0
	for r in ["res://arte/tsl04/tsl04_spriteframes.tres",
			  "res://arte/estela/estela_spriteframes.tres",
			  "res://arte/elementos/pinchos_spriteframes.tres",
			  "res://arte/elementos/bloque_pulsante_spriteframes.tres",
			  "res://arte/elementos/laser_emisor_spriteframes.tres",
			  "res://arte/elementos/laser_haz_spriteframes.tres",
			  "res://arte/elementos/dron_purga_spriteframes.tres",
			  "res://arte/elementos/dron_zapador_spriteframes.tres",
			  "res://arte/elementos/portal_spriteframes.tres",
			  "res://arte/elementos/anclaje_spriteframes.tres"]:
		var sf := load(r) as SpriteFrames
		if sf == null:
			print("FALLO al cargar ", r); fallos += 1; continue
		var det := []
		for a in sf.get_animation_names():
			var n := sf.get_frame_count(a)
			var t = sf.get_frame_texture(a, 0)
			if n == 0 or t == null:
				fallos += 1
				det.append("%s ROTA" % a)
			else:
				det.append("%s:%d" % [a, n])
		print("%-46s %s" % [r.get_file(), ", ".join(det)])
	print("FALLOS: ", fallos)
	quit()
