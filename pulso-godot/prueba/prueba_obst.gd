extends Node
## Instancia cada obstaculo y comprueba que su mecanica funciona de verdad.

var obs := {}
var registro := {}
var t := 0.0

func _ready() -> void:
	Engine.time_scale = 6.0
	var jug: Node2D = load("res://escenas/Jugador.tscn").instantiate()
	jug.position = Vector2(300, 0)
	add_child(jug)
	jug.vivo = false      # que no caiga por gravedad durante la prueba
	var i := 0
	for n in ["Pinchos", "BloquePulsante", "LaserEmisor", "DronPurga", "DronZapador", "Portal", "Anclaje"]:
		var o = load("res://escenas/obstaculos/%s.tscn" % n).instantiate()
		o.position = Vector2(60 + i * 70, 0)
		add_child(o)
		obs[n] = o
		registro[n] = {"anims": {}, "letal": {}}
		i += 1

func _process(d: float) -> void:
	t += d
	for n in obs:
		var o = obs[n]
		if not is_instance_valid(o): continue
		var sp = o.get_node_or_null("Sprite")
		if sp: registro[n]["anims"][sp.animation] = true
		if "letal" in o: registro[n]["letal"][o.letal] = true
	if t > 9.0:
		print("--- MECANICAS ---")
		var fallos := 0
		for n in registro:
			var a: Array = registro[n]["anims"].keys()
			var l: Array = registro[n]["letal"].keys()
			var ok := true
			if n in ["BloquePulsante", "LaserEmisor", "DronZapador"] and l.size() < 2:
				ok = false      # tiene que alternar letal/no letal
			if n in ["BloquePulsante", "LaserEmisor", "DronZapador"] and a.size() < 3:
				ok = false
			if n == "DronPurga" and a.size() < 2:
				ok = false      # tres estados
			if not ok: fallos += 1
			print("%-15s animaciones=%s  letal=%s  %s" % [n, str(a), str(l), "OK" if ok else "FALLA"])
		print("FALLOS: %d" % fallos)
		print("PRUEBA OBSTACULOS OK")
		get_tree().quit()
