extends Peligro
## Torreta de techo. Gira hacia ti (ese giro es el aviso), espera y dispara.

@export var alcance := 210.0
@export var espera := 1.10
@export var apuntado := 0.50
@export var disparo := 0.35
@export var largo := 150.0
## Oscilador amortiguado: w=15.5 rad/s, zeta=0.48. Se pasa un 18% y se
## asienta en 0.53 s, justo dentro de los 0.5 s que dura el apuntado.
@export var acel_ang := 240.0
@export var freno_ang := 15.0
@export var retroceso := 6.0          ## px que recula el emisor al disparar

var _t := 0.0
var _estado := "reposo"
var _jugador: Node2D
var _dir := Vector2.DOWN
var _ang := PI * 0.5                  ## apuntando hacia abajo
var _vel_ang := 0.0
var _reculada := 0.0

@onready var _col: CollisionShape2D = $ColHaz
@onready var _haz: Polygon2D = $Haz

func _ready() -> void:
	super._ready()
	letal = false
	$Sprite.play("reposo")
	var f := RectangleShape2D.new()
	f.size = Vector2(8, largo)
	_col.shape = f
	_col.disabled = true
	_haz.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0),
									   Vector2(3, largo), Vector2(-3, largo)])
	_haz.color = Color(0.919, 0.0, 0.025, 0.9)
	_haz.visible = false
	_apuntar(Vector2.DOWN)

func reiniciar() -> void:
	_t = 0.0
	_ang = PI * 0.5
	_vel_ang = 0.0
	_reculada = 0.0
	$Sprite.position = Vector2.ZERO
	_estado = "reposo"
	letal = false
	_col.set_deferred("disabled", true)
	_haz.visible = false
	$Sprite.play("reposo")
	_apuntar(Vector2.DOWN)

func _apuntar(d: Vector2) -> void:
	_dir = d.normalized()
	var ang := _dir.angle() - PI * 0.5      # el haz se dibuja hacia +Y
	_col.rotation = ang
	_col.position = _dir * largo * 0.5
	_haz.rotation = ang

func _process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node2D
	var cerca := _jugador != null and global_position.distance_to(_jugador.global_position) < alcance
	_t += delta
	if _estado == "reposo" and cerca and _t >= espera:
		_t = 0.0; _estado = "apunta"; $Sprite.play("apunta")
	# ---- la torreta tiene inercia de giro: no salta al objetivo, acelera
	# hacia el y se pasa un poco antes de asentarse. Ese vaiven ES el aviso.
	if _estado == "apunta" and _jugador != null:
		var objetivo := (_jugador.global_position - global_position).angle()
		var err: float = wrapf(objetivo - _ang, -PI, PI)
		_vel_ang += (err * acel_ang - _vel_ang * freno_ang) * delta
		_ang = wrapf(_ang + _vel_ang * delta, -PI, PI)
		_apuntar(Vector2.from_angle(_ang))
	# ---- retroceso: soltar el haz empuja al emisor hacia atras
	_reculada = move_toward(_reculada, 0.0, 30.0 * delta)
	$Sprite.position = -_dir * _reculada

	match _estado:
		"apunta":
			if _t >= apuntado:
				_t = 0.0; _estado = "dispara"; $Sprite.play("dispara")
				letal = true
				_col.set_deferred("disabled", false)
				_haz.visible = true
				_reculada = retroceso
				chispazo()
				_revisar_dentro()
		"dispara":
			if _t >= disparo:
				_t = 0.0; _estado = "reposo"; $Sprite.play("reposo")
				letal = false
				_col.set_deferred("disabled", true)
				_haz.visible = false
