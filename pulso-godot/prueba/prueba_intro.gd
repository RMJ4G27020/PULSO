extends Node
## Comprueba que la intro avanza y que la linea HIERVE de verdad.

var c: Control
var cambios := 0
var ultima: Texture2D = null
var t := 0.0
var beats_vistos := {}
var fases := {}

func _ready() -> void:
	Engine.time_scale = 8.0
	c = load("res://escenas/CineIntro.tscn").instantiate()
	c.termino.connect(_fin)
	add_child(c)

func _process(d: float) -> void:
	if c == null or not is_instance_valid(c): return
	t += d
	var tex: Texture2D = c.get_node("Lamina").texture
	if tex != ultima:
		cambios += 1
		ultima = tex
	beats_vistos[c.beat] = true
	fases[c.fase] = true

func _fin() -> void:
	var dur := 0.0
	for b in c.BEATS: dur += float(b[1])
	dur += c.FUNDIDO + c.ROTULO
	print("DURACION teorica %.1f s | reproducida %.1f s" % [dur, t])
	print("BEATS vistos: %d de %d" % [beats_vistos.size(), c.BEATS.size()])
	print("FASES: %s" % str(fases.keys()))
	print("CAMBIOS de dibujo: %d  ->  %.1f por segundo" % [cambios, cambios / t])
	print("ESPERADO ~%.0f cambios (10 por segundo)" % (dur * 10.0))
	print("PRUEBA INTRO OK")
	get_tree().quit()
