extends Node
## Capturas del HUD a los dos anchos: 640 (16:9) y 780 (19,5:9 con estiramiento
## expand). Desde que el HUD es un solo Control que se pinta en _draw(), lo que
## se comprueba aqui es que sus CAJAS se recolocan; los numeros finos los mide
## prueba/hud.tscn, que puede usar SubViewports.
const SALIDA := "user://caphud"
var n: Node2D
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-56s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await get_tree().create_timer(0.5).timeout
	n = load("res://escenas/niveles/n3_el_nudo.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.4).timeout
	var jug: CharacterBody2D = n.get_node("Jugador")
	var cam := Camera2D.new(); cam.zoom = Vector2.ONE
	add_child(cam); cam.position = jug.global_position + Vector2(120, -40); cam.make_current()

	for tam in [Vector2i(1280, 720), Vector2i(2340, 1080)]:
		DisplayServer.window_set_size(tam)
		await get_tree().create_timer(0.4).timeout
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var h: Control = n._hud
		var reloj: Rect2 = h.caja_cronometro()
		_ok(absf(reloj.end.x - (vp.x - 14.0)) < 2.0,
			"a %.0f de ancho el cronometro queda pegado a la derecha (borde %.0f de %.0f)"
			% [vp.x, reloj.end.x, vp.x])
		var est: Rect2 = h.caja_estado()
		_ok(est.size.x == 0.0 or (est.position.x >= 8.0 and est.end.x <= vp.x - 8.0),
			"y el estado no se sale (%.0f..%.0f de %.0f)" % [est.position.x, est.end.x, vp.x])
		await _tirar("hud_%d" % int(vp.x))

	# y con la puerta abierta, para ver el otro mensaje
	if n.get_node_or_null("Interruptor"):
		n.get_node("Interruptor").activar()
		await get_tree().create_timer(1.2).timeout
		await _tirar("hud_puerta")
	print("FALLOS: %d" % fallos)
	print("CAPTURAS HUD OK")
	get_tree().quit()

func _tirar(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SALIDA, nom])
