extends CanvasLayer
## Fundido a negro entre niveles. Antes el cambio era un corte seco.
##
## El lenguaje visual ya existia en el juego: scripts/cine.gd funde la intro con
## un ColorRect $Negro. Esto es lo mismo, sacado a una escena para que cualquier
## nivel lo monte en una linea.
##
## No usa Tween a proposito: el nodo corre en ALWAYS para que el fundido siga
## con el arbol pausado, y un float movido en _process se comporta igual en
## headless (donde las pruebas miden) que con ventana.

@onready var _negro: ColorRect = $Negro

var _alfa := 0.0
var _destino := 0.0
var _vel := 0.0

func _ready() -> void:
	_negro.color.a = _alfa

## Cierra a negro. Al terminar, `opaco()` vale true: ese es el momento de
## cambiar de escena, no antes.
func a_negro(dur: float = 0.6) -> void:
	_destino = 1.0
	_vel = 1.0 / maxf(dur, 0.001)

## Abre desde negro. Se llama al entrar en un nivel, asi que empieza tapado.
func desde_negro(dur: float = 0.35) -> void:
	_alfa = 1.0
	_destino = 0.0
	_vel = 1.0 / maxf(dur, 0.001)
	if _negro:
		_negro.color.a = _alfa

func alfa() -> float:
	return _alfa

func opaco() -> bool:
	return _alfa >= 0.999

func _process(delta: float) -> void:
	if is_equal_approx(_alfa, _destino):
		return
	_alfa = move_toward(_alfa, _destino, _vel * delta)
	if _negro:
		_negro.color.a = _alfa
