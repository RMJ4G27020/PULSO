extends Node
## Comprueba la cadena completa: interruptor -> puerta -> portal -> siguiente nivel.

var n: Node2D
var idx := 0
var niveles := ["n1_ida_y_vuelta", "n2_el_corredor", "n3_el_nudo"]
var fase := 0
var t := 0.0
var reg := []

func _ready() -> void:
	Engine.time_scale = 4.0
	_cargar()

func _cargar() -> void:
	if n != null and is_instance_valid(n): n.queue_free()
	var nom: String = niveles[idx]
	n = load("res://escenas/niveles/%s.tscn" % nom).instantiate() as Node2D
	add_child(n)
	t = 0.0; fase = 0

func _process(d: float) -> void:
	if n == null or not is_instance_valid(n): return
	t += d
	var nom: String = niveles[idx]
	var pu = n.get_node_or_null("Puerta")
	var it = n.get_node_or_null("Interruptor")
	if fase == 0 and t > 0.6:
		var cerrada: bool = pu != null and not pu.abierta
		it.activar()                                  # tocar la terminal
		fase = 1
		reg.append([nom, cerrada])
	elif fase == 1 and t > 1.6:
		var abierta: bool = pu != null and pu.abierta
		var carga: float = n._jugador.carga
		var geo = n.get_node("Geometria")
		var bloques := 0
		for c in geo.get_children(): if c is Sprite2D: bloques += 1
		var pel = n.get_node_or_null("Peligros")
		print("%-16s puerta_cerrada_al_inicio=%s  abre_al_tocar=%s  carga=%.0f  bloques=%d  peligros=%d" % [
			nom, reg[-1][1], abierta, carga, bloques, pel.get_child_count() if pel else 0])
		idx += 1
		if idx >= niveles.size():
			print("ORDEN en nivel.gd: %d entradas" % n.ORDEN.size())
			print("PRUEBA FLUJO OK"); get_tree().quit()
		else:
			_cargar()
