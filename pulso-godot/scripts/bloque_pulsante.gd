extends Peligro
## Bloque rojo con ciclo de 2 s. Solo mata encendido, y avisa antes.

@export var apagado := 0.90
@export var aviso := 0.35
@export var encendido := 0.75
@export var desfase := 0.0     ## para que no laten todos a la vez

var _t := 0.0
var _estado := "apagado"

func _ready() -> void:
	super._ready()
	_t = desfase
	letal = false
	$Sprite.play("apagado")

func reiniciar() -> void:
	_t = desfase
	_estado = "apagado"
	letal = false
	$Sprite.play("apagado")

func _process(delta: float) -> void:
	_t += delta
	var ciclo := apagado + aviso + encendido
	var f: float = fmod(_t, ciclo)
	var nuevo := "apagado"
	if f >= apagado + aviso:
		nuevo = "encendido"
	elif f >= apagado:
		nuevo = "aviso"
	if nuevo != _estado:
		_estado = nuevo
		$Sprite.play(nuevo)
		letal = nuevo == "encendido"
		if letal:
			chispazo()
			_revisar_dentro()
