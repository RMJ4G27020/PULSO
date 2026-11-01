extends Peligro
## Emisor mas haz. Ciclo: reposo -> carga (avisa) -> dispara (mata).
## El haz se repite en vertical hasta el largo que se le diga.

@export var largo_celdas := 6
@export var reposo := 1.20
@export var carga := 0.50
@export var disparo := 0.80
@export var desfase := 0.0

const CELDA := 16.0
var _t := 0.0
var _estado := "reposo"
var _haces: Array[AnimatedSprite2D] = []

func _ready() -> void:
	super._ready()
	_t = desfase
	letal = false
	$Sprite.play("reposo")
	var sf: SpriteFrames = load("res://arte/elementos/laser_haz_spriteframes.tres")
	for i in largo_celdas:
		var h := AnimatedSprite2D.new()
		h.sprite_frames = sf
		h.scale = Vector2(0.3333, 0.3333)
		h.position = Vector2(0, CELDA * (i + 1))
		h.play("haz")
		h.visible = false
		add_child(h)
		_haces.append(h)
	var col: CollisionShape2D = $ColHaz
	var forma := RectangleShape2D.new()
	forma.size = Vector2(7, CELDA * largo_celdas)
	col.shape = forma
	col.position = Vector2(0, CELDA * largo_celdas * 0.5 + CELDA * 0.5)
	col.disabled = true

func reiniciar() -> void:
	_t = desfase
	_estado = "reposo"
	letal = false
	$Sprite.play("reposo")
	$ColHaz.set_deferred("disabled", true)
	for h in _haces:
		h.visible = false

func _process(delta: float) -> void:
	_t += delta
	var ciclo := reposo + carga + disparo
	var f: float = fmod(_t, ciclo)
	var nuevo := "reposo"
	if f >= reposo + carga:
		nuevo = "dispara"
	elif f >= reposo:
		nuevo = "carga"
	if nuevo != _estado:
		_estado = nuevo
		$Sprite.play(nuevo)
		var on := nuevo == "dispara"
		letal = on
		$ColHaz.set_deferred("disabled", not on)
		for h in _haces:
			h.visible = on
		if on:
			chispazo()
			_revisar_dentro()
