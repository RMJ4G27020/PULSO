extends Node
## La estela debe seguir matando en todas partes MENOS sobre la terminal.
## Se esperan frames entre niveles: si no, el jugador se engancha a la rejilla del anterior.
const CASOS := [
	["n1_ida_y_vuelta", 0.0,    "n1  sobre la terminal", 0],
	["n1_ida_y_vuelta", -300.0, "n1  lejos por el corredor", 1],
	["n2_el_corredor",  0.0,    "n2  sobre la terminal", 0],
	["n2_el_corredor",  -200.0, "n2  lejos por el corredor", 1],
]
var caso := -1
var n: Node2D
var jug: CharacterBody2D
var it: Area2D
var t := 0.0
var paso := 0
var m0 := 0
var fallos := 0

func _ready() -> void:
	# mide el retardo de TSL-04 sin asistencia, no el del personaje y los ajustes
	# de quien juega (con TSL-01 y asistencia, quieto 1,10 s no moria)
	Personajes.forzado = Personajes.BASE
	Guardado.poner_opcion("asistencia", false)
	_siguiente()

func _siguiente() -> void:
	caso += 1
	if caso >= CASOS.size():
		print("FALLOS: %d" % fallos)
		print("PRUEBA ESTELA OK"); get_tree().quit(); return
	if n:
		n.queue_free(); n = null
		for i in 3: await get_tree().process_frame      # que el nivel viejo salga del arbol
	var ruta: String = CASOS[caso][0]
	n = load("res://escenas/niveles/%s.tscn" % ruta).instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador"); it = n.get_node("Interruptor")
	var rejillas := get_tree().get_nodes_in_group("estela").size()
	if rejillas != 1:
		print("  aviso: %d rejillas en el arbol" % rejillas)
	paso = 0; t = 0.0

func _process(d: float) -> void:
	if n == null: return
	t += d
	match paso:
		0:
			if t > 0.4:
				jug.global_position = it.global_position + Vector2(CASOS[caso][1], 2)
				jug.velocity = Vector2.ZERO
				m0 = n._muertes
				paso = 1; t = 0.0
		1:
			if t > 1.2:
				var murio: int = 1 if n._muertes > m0 else 0
				var quiero: int = CASOS[caso][3]
				var ok := murio == quiero
				if not ok: fallos += 1
				print("  %-26s quieto -> murio=%d (esperado %d) %s" % [CASOS[caso][2], murio, quiero, "OK" if ok else "FALLA"])
				paso = 9
				_siguiente()
