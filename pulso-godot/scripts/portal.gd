extends Area2D
## La salida del nivel.

signal alcanzado

func _ready() -> void:
	$Sprite.play("portal")
	body_entered.connect(func(c): if c.has_method("morir"): alcanzado.emit())
