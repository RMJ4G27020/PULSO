extends SceneTree
func _init():
	for n in ["v1a","v5b","v8a","escritorioa"]:
		var t := load("res://arte/laminas/%s.svg" % n) as Texture2D
		print("%-12s %s" % [n, "NO CARGA" if t == null else "%dx%d" % [t.get_width(), t.get_height()]])
	quit()
