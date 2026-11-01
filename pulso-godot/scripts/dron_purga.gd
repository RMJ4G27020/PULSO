extends Peligro
## Patrulla un tramo. Si te ve, te persigue a velocidad constante y no se rinde.
## Mas lento que tu corriendo, mas rapido que tu dudando.

@export var recorrido := Vector2(120, 0)
@export var vel_patrulla := 46.0
@export var vel_alerta := 118.0
@export var vista := 190.0
@export var aceleracion := 110.0      ## px/s2. A 46 px/s frena en 9.6 px, y como
                                      ## el giro se pide a 4, se pasa 5.6 px del extremo
@export var inclinacion := 24.0       ## grados que se ladea a maxima aceleracion
@export var flotacion := 2.6          ## amplitud del cabeceo al sostenerse

var _a: Vector2
var _b: Vector2
var _hacia_b := true
var _alerta := false
var _jugador: Node2D
var _vel := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	super._ready()
	_a = global_position
	_b = _a + recorrido
	$Sprite.play("patrulla")

func reiniciar() -> void:
	global_position = _a
	_hacia_b = true
	_alerta = false
	_vel = Vector2.ZERO
	$Sprite.rotation = 0.0
	$Sprite.play("patrulla")

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node2D
	if _jugador != null and not _alerta and global_position.distance_to(_jugador.global_position) < vista:
		_alerta = true
		$Sprite.play("alerta")
		chispazo(Color(1.0, 0.3, 0.25), 320.0)      # te ha visto: que se note
	# ---- a donde QUERRIA ir
	var deseada := Vector2.ZERO
	if _alerta and _jugador != null:
		var d := _jugador.global_position - global_position
		deseada = d.normalized() * vel_alerta if d.length() > 4.0 else Vector2.ZERO
	else:
		var meta := _b if _hacia_b else _a
		var d := meta - global_position
		if d.length() < 4.0:
			_hacia_b = not _hacia_b
			meta = _b if _hacia_b else _a
			d = meta - global_position
		deseada = d.normalized() * vel_patrulla

	# ---- pero tiene masa: la velocidad solo puede cambiar tan deprisa.
	# De aqui sale solo que se pase de largo al final de la patrulla y que
	# tarde en arrancar cuando te ve, sin tener que programar ninguna de las dos.
	var cambio := deseada - _vel
	var tope := aceleracion * delta
	if cambio.length() > tope:
		cambio = cambio.normalized() * tope
	_vel += cambio
	global_position += _vel * delta

	# ---- un cuadricoptero SOLO acelera ladeandose: el empuje sale del rotor,
	# asi que para empujar de lado tiene que inclinarse. No es adorno.
	var a := cambio.x / maxf(tope, 0.001)          # -1 .. 1
	var meta_rot := deg_to_rad(-inclinacion * a)
	$Sprite.rotation = lerp_angle($Sprite.rotation, meta_rot, minf(1.0, 9.0 * delta))

	# ---- cabeceo de sustentacion: nada que se sostiene en el aire esta quieto.
	# Solo el sprite: si moviera el cuerpo, el area de dano daria saltos.
	_t += delta
	$Sprite.position.y = sin(_t * 3.1) * flotacion

	if absf(_vel.x) > 6.0:
		$Sprite.flip_h = _vel.x < 0.0
