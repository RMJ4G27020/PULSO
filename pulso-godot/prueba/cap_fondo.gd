extends Node
const SALIDA := "user://capfondo"
var n: Node2D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	n = load("res://escenas/niveles/n3_el_nudo.tscn").instantiate() as Node2D
	add_child(n)
	var cam := Camera2D.new(); cam.zoom = Vector2(1, 1)
	cam.position = Vector2(700, 620); add_child(cam); cam.make_current()
	var fondo := n.get_node_or_null("Fondo/Capa/Placa") as AnimatedSprite2D
	print("nodo de fondo: %s   reproduciendo: %s   animacion: %s   cuadros: %d"
		% [fondo != null, fondo.is_playing() if fondo else false,
		   fondo.animation if fondo else "-",
		   fondo.sprite_frames.get_frame_count("placa") if fondo else 0])
	for i in 20: await get_tree().process_frame
	await _tirar("a")
	var c0: int = fondo.frame
	while fondo.frame == c0:
		await get_tree().process_frame
	for i in 3: await get_tree().process_frame
	await _tirar("b")
	print("paso del cuadro %d al %d" % [c0, fondo.frame])
	print("CAPTURAS LISTAS")
	get_tree().quit()

func _tirar(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SALIDA, nom])
