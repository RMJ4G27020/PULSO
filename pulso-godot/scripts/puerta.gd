extends StaticBody2D
## Compuerta de sector. Cerrada bloquea el paso; la terminal la abre.

var abierta := false

func _ready() -> void:
	cerrar()

func cerrar() -> void:
	abierta = false
	$Sprite.play("cerrada")
	$Col.set_deferred("disabled", false)

func abrir() -> void:
	if abierta:
		return
	abierta = true
	Audio.sonar("puerta")
	$Sprite.play("abriendo")
	$Col.set_deferred("disabled", true)
	await $Sprite.animation_finished
	if abierta:
		$Sprite.play("abierta")
