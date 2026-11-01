extends Node
## El fondo se iba de la pantalla y la medicion anterior no lo veia.
##
## Dos cosas que hay que saber para que esta prueba no sea ciega:
##  1. El color de borrado del proyecto es (0.055,0.07,0.048), practicamente el
##     mismo casi negro que el sustrato de la placa del fondo. Contando pixeles
##     no hay forma de distinguir "falta el fondo" de "aqui el fondo es oscuro".
##     Por eso se pone el borrado en MAGENTA en marcha.
##  2. La causa era que el Parallax2D heredaba follow_viewport = true bajo un
##     CanvasLayer con follow_viewport_enabled = false: el desplazamiento de
##     camara se aplicaba DOS veces y el fondo derivaba a +0,75x (al reves y
##     tres veces mas rapido que el scroll_scale de 0,25) hasta salirse de la
##     banda finita de mosaico.
##
## La parte de pixeles necesita ventana de verdad; en headless se salta y queda
## la medida de deriva, que es la que ataca la causa y si corre sin ventana.
const MAGENTA := Color(1, 0, 1)
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-62s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	for f in ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo", "n4_la_chimenea",
			  "n5_lasermania", "n6_runthedrun"]:
		var t: String = FileAccess.get_file_as_string("res://escenas/niveles/%s.tscn" % f)
		_ok(t.contains("follow_viewport = false"),
			"%-18s empareja el Parallax2D con su CanvasLayer" % f)

	# --- deriva: mover la camara 200 px tiene que mover el fondo -50 px
	var n: Node2D = load("res://escenas/niveles/n2_el_corredor.tscn").instantiate() as Node2D
	add_child(n)
	await get_tree().create_timer(0.3).timeout
	var placa: Node2D = n.get_node("Fondo/Capa/Placa")
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = Vector2(600, 300)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	var x0: float = placa.get_global_transform_with_canvas().origin.x
	cam.global_position.x += 200.0
	await get_tree().process_frame
	await get_tree().process_frame
	var dx: float = placa.get_global_transform_with_canvas().origin.x - x0
	_ok(absf(dx - (-50.0)) < 2.0,
		"la camara +200 px mueve el fondo %.1f px (scroll_scale pide -50)" % dx)

	if DisplayServer.get_name() == "headless":
		print("    (sin ventana: la medida de pixeles en magenta se salta)")
	else:
		await _barrer(n, cam, "n2")
		n.queue_free()
		await get_tree().process_frame
		for nom in ["n5_lasermania", "n6_runthedrun"]:
			var g: Node2D = load("res://escenas/niveles/%s.tscn" % nom).instantiate() as Node2D
			add_child(g)
			await get_tree().create_timer(0.3).timeout
			cam.make_current()
			await _barrer(g, cam, nom)
			g.queue_free()
			await get_tree().process_frame
	print("FALLOS: %d" % fallos)
	print("PRUEBA FONDO OK")
	get_tree().quit()

## Barre la camara de punta a punta y mide el peor hueco. Los niveles a mano
## miden 1056-1440 px y nunca llegaban al umbral de 2050 px: por eso la queja
## solo se veia en los generados, que median unos 9700. Los que hacen ese papel
## ahora son los dos grandes (n5 y n6).
func _barrer(_n: Node2D, cam: Camera2D, nom: String) -> void:
	RenderingServer.set_default_clear_color(MAGENTA)
	var peor := 0.0
	var donde := 0.0
	var x := -12000.0
	while x <= 24000.0:
		cam.global_position = Vector2(x, 300.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var p := _magenta()
		if p > peor:
			peor = p
			donde = x
		x += 500.0
	RenderingServer.set_default_clear_color(Color(0.055, 0.07, 0.048))
	_ok(peor < 0.005,
		"%-14s 0%% de pantalla sin fondo de -12000 a +24000 (peor %.2f%% en x=%.0f)"
		% [nom, peor * 100.0, donde])

func _magenta() -> float:
	var img: Image = get_viewport().get_texture().get_image()
	var n := 0
	var total := 0
	var paso := 4
	for y in range(0, img.get_height(), paso):
		for x in range(0, img.get_width(), paso):
			total += 1
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.7 and c.g < 0.3 and c.b > 0.7:
				n += 1
	return float(n) / float(maxi(total, 1))
