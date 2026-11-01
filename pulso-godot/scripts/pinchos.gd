extends Peligro
## Puas fijas. No se apagan nunca: se rodean.

func _ready() -> void:
	super._ready()
	$Sprite.play("pinchos")
