extends Node
## Con expand, en una pantalla 20:9 se ve mas ancho. Los mandos tienen que
## recolocarse solos o el boton de saltar se queda en mitad de la pantalla.
func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var esc: Node = load("res://escenas/Tactil.tscn").instantiate()
	add_child(esc)
	var m: Control = esc.get_node("Mandos")
	await get_tree().create_timer(0.2).timeout
	for tam in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(2400, 1080)]:
		DisplayServer.window_set_size(tam)
		await get_tree().create_timer(0.35).timeout
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var b: Vector2 = m._botones["saltar"]
		var margen: float = vp.x - b.x
		print("  ventana %-11s -> viewport %5.0fx%-5.0f  saltar a %5.1f px del borde  %s"
			% [str(tam.x) + "x" + str(tam.y), vp.x, vp.y, margen,
			   "OK" if abs(margen - 54.0) < 1.0 else "MAL COLOCADO"])
	# En headless la ventana no se puede redimensionar de verdad, asi que lo de
	# arriba mide siempre el mismo viewport. Para ver los DOS anchos que importan
	# (640 del 16:9 y 780 del 20:9 estirado) se monta el menu de pausa y el HUD
	# dentro de SubViewports, que si se pueden fijar.
	for ancho in [640, 780]:
		var sv := SubViewport.new()
		sv.size = Vector2i(ancho, 360)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var pa: Node = load("res://escenas/Pausa.tscn").instantiate()
		sv.add_child(pa)
		var hu: Node = load("res://escenas/Hud.tscn").instantiate()
		sv.add_child(hu)
		await get_tree().process_frame
		await get_tree().process_frame
		var menu: Control = pa.get_node("Menu")
		var hud: Control = hu.get_node("Panel")
		hud.actualizar(1.0, 40.0, 100.0, 0, 3, "", "", 0, Vector2.INF)
		var an: float = menu.ancho_panel()
		var esperado: float = clampf(float(ancho) * 0.46, 240.0, 340.0)
		print("  viewport %3d  ->  panel de pausa %5.1f px  alto %5.1f  cronometro a %5.1f  %s"
			% [ancho, an, menu.alto_total(), hud.caja_cronometro().end.x,
			   "OK" if absf(an - esperado) < 0.5 else "MAL"])
		print("      el panel cabe en alto: %s   el cronometro sigue pegado al borde: %s"
			% ["OK" if menu.alto_total() <= 340.0 else "MAL",
			   "OK" if absf(hud.caja_cronometro().end.x - (float(ancho) - 14.0)) < 2.0 else "MAL"])
		sv.queue_free()
		await get_tree().process_frame
	print("PRUEBA ASPECTO OK")
	get_tree().quit()
