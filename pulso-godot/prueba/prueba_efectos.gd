extends Node
## Comprueba que los efectos se disparan y se disuelven solos.

var n: Node2D
var jug: CharacterBody2D
var t := 0.0
var reg := {}
var hecho := false

func _ready() -> void:
	n = load("res://escenas/niveles/n2_el_corredor.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")

func _process(d: float) -> void:
	t += d
	var f: float = Efectos._mat.get_shader_parameter("fuerza")
	var a: float = Efectos._destello.color.a
	var cam := get_viewport().get_camera_2d()
	reg["aberracion_max"] = maxf(reg.get("aberracion_max", 0.0), f)
	reg["destello_max"] = maxf(reg.get("destello_max", 0.0), a)
	if cam: reg["sacudida_max"] = maxf(reg.get("sacudida_max", 0.0), cam.offset.length())
	reg["escala_tiempo_min"] = minf(reg.get("escala_tiempo_min", 1.0), Engine.time_scale)
	if not hecho and t > 1.0:
		hecho = true
		jug.morir()
	if t > 4.0:
		print("destello pico   %.2f" % reg.get("destello_max", 0))
		print("sacudida pico   %.2f px" % reg.get("sacudida_max", 0))
		print("aberracion pico %.4f" % reg.get("aberracion_max", 0))
		print("time_scale min  %.2f  (congelacion)" % reg.get("escala_tiempo_min", 1))
		print("al final -> destello %.2f  aberracion %.4f  time_scale %.2f" % [
			Efectos._destello.color.a, Efectos._mat.get_shader_parameter("fuerza"), Engine.time_scale])
		print("chispas emitidas: %s" % Efectos._chispas.amount)
		print("PRUEBA EFECTOS OK")
		get_tree().quit()
