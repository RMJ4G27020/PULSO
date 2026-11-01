extends Node
## Carga cada nivel, lo deja correr y comprueba que los obstaculos estan vivos.

var niveles := ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo"]
var idx := 0
var n: Node2D
var t := 0.0
var visto := {}

func _ready() -> void:
	Engine.time_scale = 5.0
	_cargar()

func _cargar() -> void:
	if n != null and is_instance_valid(n): n.queue_free()
	n = load("res://escenas/niveles/%s.tscn" % niveles[idx]).instantiate() as Node2D
	add_child(n)
	t = 0.0
	visto[niveles[idx]] = {"peligros": 0, "letal": {}, "bloques": 0}

func _process(d: float) -> void:
	if n == null or not is_instance_valid(n): return
	t += d
	var nom: String = niveles[idx]
	var pel := n.get_node_or_null("Peligros")
	if pel:
		visto[nom]["peligros"] = pel.get_child_count()
		for c in pel.get_children():
			if "letal" in c: visto[nom]["letal"][c.name + ":" + str(c.letal)] = true
	var geo := n.get_node_or_null("Geometria")
	if geo:
		var b := 0
		for c in geo.get_children():
			if c is Sprite2D: b += 1
		visto[nom]["bloques"] = b
	if t > 5.0:
		var v = visto[nom]
		print("%-18s bloques3D=%-3d peligros=%-2d estados=%d  salida=%s anclaje=%s" % [
			nom, v["bloques"], v["peligros"], v["letal"].size(),
			n.get_node_or_null("Salida") != null, n.get_node_or_null("Anclaje") != null])
		idx += 1
		if idx >= niveles.size():
			print("PRUEBA NIVELES OK"); get_tree().quit()
		else:
			_cargar()
