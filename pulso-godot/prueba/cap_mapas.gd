extends Node
## Mapa de cada nivel entero, para el README: el nivel en un SubViewport con una
## camara que lo encuadra completo. Con ventana:
##   Godot --path . prueba/capmapas.tscn
## Salen en user://mapas.

const SALIDA := "user://mapas"
const NIVELES := ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo", "n4_la_chimenea",
	"n5_lasermania", "n6_runthedrun"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	Personajes.forzado = Personajes.BASE
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit())
	for nom in NIVELES:
		await _mapa(nom)
	Personajes.forzado = ""
	print("LISTO en " + ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()


func _mapa(nom: String) -> void:
	var n: Node2D = load("res://escenas/niveles/%s.tscn" % nom).instantiate()
	# los limites, de la geometria
	var caja := Rect2()
	var primero := true
	for c in n.get_node("Geometria").get_children():
		if c is CollisionShape2D:
			var tam: Vector2 = (c.shape as RectangleShape2D).size
			var r := Rect2(c.position - tam * 0.5, tam)
			caja = r if primero else caja.merge(r)
			primero = false
	caja = caja.grow_individual(48, 160, 48, 48)
	var ancho := 3200.0 if caja.size.x > 4000.0 else 1800.0
	var alto := ceilf(ancho * caja.size.y / caja.size.x)
	var vista := SubViewport.new()
	vista.size = Vector2i(int(ancho), int(alto))
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vista)
	vista.add_child(n)
	await get_tree().process_frame
	await get_tree().process_frame
	# fuera lo que no es el nivel: HUD, mandos, pausa, fundido, y el fondo, que con
	# la camara tan alejada solo cubria una parte
	for c in n.get_children():
		if c is CanvasLayer:
			c.visible = false
	var j: Node = n.get_node("Jugador")
	(j.get_node("Camara") as Camera2D).enabled = false
	var cam := Camera2D.new()
	cam.position = caja.get_center()
	cam.zoom = Vector2.ONE * (ancho / caja.size.x)
	n.add_child(cam)
	cam.make_current()
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vista.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [SALIDA, nom])
	print(nom, " ", img.get_size())
	vista.queue_free()
	await get_tree().process_frame
