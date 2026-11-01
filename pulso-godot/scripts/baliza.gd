extends Area2D
## Punto de control y de carga de los niveles grandes.
##
## Un nivel de 90 celdas se hace de una vez: la carga (100 % y 1,6 %/s) dura 62 s
## y reaparecer es volver al principio. Uno enorme no cabe en 62 s ni se puede
## repetir entero cada vez que un laser te coge, asi que cada baliza hace tres
## cosas la primera vez que se pisa:
##   - recarga la carga a tope (la unica fuente de carga, aparte de la terminal
##     y los fragmentos, que dan poco),
##   - pasa a ser el sitio donde se reaparece al morir (nivel.gd), y
##   - es toma de tierra, como la terminal: la estela no prende encima, asi que
##     se puede parar a esperar el hueco de un laser. Es el unico sitio donde el
##     juego deja parar.
## Reusa el dibujo del anclaje (el punto de aparicion): una baliza es un anclaje
## que se activa al pasar.

signal activada

## Cuanta carga devuelve. A tope por defecto: el tramo siguiente se mide contra
## 100 %, no contra "lo que quedara".
@export var carga_devuelta := 100.0

## Donde reaparece el jugador, relativo a la baliza. Es lo mismo que separa al
## marcador de aparicion del dibujo del anclaje en las escenas de nivel.
const REAPARICION := Vector2(0, -14)

var _usada := false


func _ready() -> void:
	add_to_group("baliza")
	$Sprite.play("apagado")
	body_entered.connect(_al_entrar)
	_a_tierra.call_deferred()


## Igual que la terminal: la estela no prende sobre ella, y se ensancha un poco
## para que no puedas morir de pie justo al borde del dibujo.
func _a_tierra() -> void:
	var r := get_tree().get_first_node_in_group("estela") as RejillaEstela
	if r == null:
		return
	var tam: Vector2 = ($Col.shape as RectangleShape2D).size
	var caja := Rect2($Col.global_position - tam * 0.5, tam)
	r.tomar_tierra(caja.grow_individual(16.0, 0.0, 16.0, 16.0))


func punto_aparicion() -> Vector2:
	return global_position + REAPARICION


func usada() -> bool:
	return _usada


func _al_entrar(cuerpo: Node2D) -> void:
	if _usada or not cuerpo.has_method("morir"):
		return
	activar()


func activar() -> void:
	if _usada:
		return
	_usada = true
	$Sprite.play("activa")
	Audio.sonar("terminal", 5.0)
	Efectos.destello(Color(0.21, 0.85, 1.0), 0.3)
	Efectos.chispas(global_position + REAPARICION, Color(0.21, 0.85, 1.0))
	activada.emit()
	await $Sprite.animation_finished
	# si el nivel se reinicio mientras tanto, no se queda encendida
	if _usada:
		$Sprite.play("activo")


## Reinicio completo del nivel (no una muerte): vuelve a estar sin pisar.
func reiniciar() -> void:
	_usada = false
	$Sprite.play("apagado")
