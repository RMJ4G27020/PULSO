extends SceneTree
func _init():
	var t := load("res://arte/laminas/prueba.svg") as Texture2D
	if t == null:
		print("SVG NO CARGA")
	else:
		print("SVG OK  %dx%d  clase=%s" % [t.get_width(), t.get_height(), t.get_class()])
	quit()
