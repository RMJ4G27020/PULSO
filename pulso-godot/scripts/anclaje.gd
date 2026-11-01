extends Node2D
## Punto de aparicion. Marca donde reapareces; no guarda partida.

func _ready() -> void:
	$Sprite.play("apagado")

func activar() -> void:
	$Sprite.play("activa")
	await $Sprite.animation_finished
	$Sprite.play("activo")
