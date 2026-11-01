extends CharacterBody2D
## TSL-04. Cifras del GDD: 180 px/s, salto de 62 px, impulso de 0.18 s sin estela.

signal murio
signal carga_cambiada(valor: float)

## animaciones que no se pueden interrumpir hasta que terminan
const UNICAS := ["aparicion", "aterrizaje", "impulso", "muerte", "victoria", "giro"]

@export var velocidad := 220.0        ## subida con los niveles abiertos: 7 celdas de hueco
@export var aceleracion := 1400.0
@export var frenado := 1800.0
@export var altura_salto := 115.0      ## 7.2 celdas: hace falta para huecos de 4x el personaje
@export var gravedad := 980.0
@export var factor_caida := 1.6
@export var caida_maxima := 520.0
@export var coyote := 0.10
@export var buffer := 0.12
@export var impulso_vel := 340.0
@export var impulso_dur := 0.18
@export var impulso_espera := 0.9
@export var gracia := 1.1              ## segundos invulnerable al reaparecer
@export var deslizar := 46.0          ## velocidad de caida pegado a la pared
@export var consumo := 1.6            ## % de carga por segundo
@export var coste_impulso := 3.0
@export var coste_pulso := 25.0
@export var coste_adherencia := 1.0   ## % por segundo pegado

var carga := 100.0
var vivo := true
## Cual de las cuatro celdas es (scripts/personajes.gd). Lo decide _ready.
var personaje := Personajes.BASE
var mirando := 1.0
var pegado := false

var _t_coyote := 0.0
var _t_buffer := 0.0
var _t_impulso := 0.0
var _t_espera := 0.0
var _en_aire := false
var _bloqueo := ""
var _celda_previa := Vector2i(-99999, -99999)

@onready var _v_salto: float = sqrt(2.0 * gravedad * altura_salto)
@onready var _sprite: AnimatedSprite2D = $Sprite
var _t_gracia := 0.0
var _celebrando := false
var _rejilla: RejillaEstela

func _ready() -> void:
	# El personaje elegido cambia algunos numeros y la hoja de animaciones. El
	# impulso del salto se recalcula: _v_salto se saco antes, con la altura de
	# fabrica, y TSL-02 salta mas.
	personaje = Personajes.aplicar_jugador(self)
	_v_salto = sqrt(2.0 * gravedad * altura_salto)
	_sprite.play("reposo")
	_rejilla = get_tree().get_first_node_in_group("estela") as RejillaEstela
	_sprite.animation_finished.connect(_al_terminar_animacion)

# ---------------------------------------------------------------- animaciones
func _reproducir(nombre: String) -> void:
	if nombre in UNICAS:
		_bloqueo = nombre
		_sprite.play(nombre)
	elif _bloqueo == "" and _sprite.animation != nombre:
		_sprite.play(nombre)

func _al_terminar_animacion() -> void:
	if _sprite.animation != "muerte":     # la muerte se queda en el ultimo cuadro
		_bloqueo = ""

func _animar() -> void:
	_sprite.flip_h = mirando < 0.0
	var nueva := "reposo"
	if pegado:
		nueva = "adherencia"
	elif not is_on_floor():
		nueva = "caida" if velocity.y > 0.0 else "salto"
	elif absf(velocity.x) > 12.0:
		nueva = "correr"
	elif carga < 25.0:
		nueva = "carga_baja"
	_reproducir(nueva)

func celebrar() -> void:
	# la ceremonia de salida deja al personaje quieto sobre el portal mas de
	# los 0,35 s del RETARDO, asi que sin esto se mata con su propia estela
	# justo en la victoria
	_celebrando = true
	_t_gracia = maxf(_t_gracia, 3.0)
	_reproducir("victoria")
	Efectos.destello(Color(0.78, 0.95, 0.31), 0.55)
	Efectos.chispas(global_position, Color(0.78, 0.95, 0.31))

# ---------------------------------------------------------------------- ciclo
func reiniciar(donde: Vector2) -> void:
	global_position = donde
	velocity = Vector2.ZERO
	carga = 100.0
	vivo = true
	pegado = false
	_t_impulso = 0.0
	_t_espera = 0.0
	_en_aire = false
	_bloqueo = ""
	_celda_previa = Vector2i(-99999, -99999)
	_celebrando = false
	_t_gracia = gracia
	if _rejilla:
		_rejilla.limpiar()
	carga_cambiada.emit(carga)
	_reproducir("aparicion")

func _physics_process(delta: float) -> void:
	if not vivo:
		return

	if _t_gracia > 0.0:
		# parpadea mientras es invulnerable, para que se vea que lo es
		_t_gracia = maxf(_t_gracia - delta, 0.0)
		# celebrando NO se parpadea: la gracia de la ceremonia esta solo para
		# que la estela no lo mate quieto sobre el portal, no es invulnerabilidad
		# que haya que anunciar
		if not _celebrando:
			modulate.a = 0.45 + 0.55 * absf(sin(_t_gracia * 22.0))
		if _t_gracia == 0.0:
			modulate.a = 1.0

	# el reloj de la rejilla, no el de pared: si el jugador marcase con
	# Time.get_ticks_msec() y la rejilla dibujase con el suyo, en cuanto se
	# pausa (o time_scale es 0) las dos mitades se desincronizan y la celda
	# recien pisada aparece ya encendida
	var ahora: float = _rejilla.reloj if _rejilla else 0.0
	_gastar(consumo * delta)
	_t_espera = maxf(_t_espera - delta, 0.0)

	if _t_impulso > 0.0:
		# durante el impulso no se registra estela: ese hueco es la herramienta del juego
		_t_impulso -= delta
		velocity = Vector2(impulso_vel * mirando, 0.0)
		move_and_slide()
		_reproducir("impulso")
		_estela(ahora, false, global_position + Vector2(0, 15))
		return

	_mover(delta)
	if pegado:
		_gastar(coste_adherencia * delta)
		# las paredes tambien guardan estela: cada una sirve una vez
		_estela(ahora, true, global_position + Vector2(-get_wall_normal().x * 15.0, 0))
	else:
		_estela(ahora, is_on_floor() and not _sobre_libre(), global_position + Vector2(0, 15))
	_animar()

func _mover(delta: float) -> void:
	var eje := Input.get_axis("mover_izq", "mover_der")
	if eje != 0.0:
		var nuevo_lado := signf(eje)
		if nuevo_lado != mirando and is_on_floor():
			_reproducir("giro")      # pivota antes de arrancar en el otro sentido
		mirando = nuevo_lado
		velocity.x = move_toward(velocity.x, velocidad * eje, aceleracion * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, frenado * delta)

	var en_suelo := is_on_floor()
	# el aterrizaje NO pisa a la aparicion: nacer y tocar suelo son el mismo
	# suceso. La aparicion se coloca una celda por encima del suelo, asi que sin
	# esto la animacion de entrada duraba UN cuadro y no se veia nunca.
	if en_suelo and _en_aire and _bloqueo != "aparicion":
		_reproducir("aterrizaje")
		Audio.sonar("aterrizaje", randf_range(-1.5, 1.5))
	_en_aire = not en_suelo

	# adherencia: pegado a la pared y deslizando
	pegado = (not en_suelo) and is_on_wall_only() and velocity.y > 0.0 and eje != 0.0
	if pegado:
		velocity.y = minf(velocity.y, deslizar)
		mirando = -signf(get_wall_normal().x)

	if en_suelo:
		_t_coyote = coyote
	else:
		_t_coyote = maxf(_t_coyote - delta, 0.0)
		if not pegado:
			var g := gravedad * (factor_caida if velocity.y > 0.0 else 1.0)
			velocity.y = minf(velocity.y + g * delta, caida_maxima)

	if Input.is_action_just_pressed("saltar"):
		_t_buffer = buffer
	else:
		_t_buffer = maxf(_t_buffer - delta, 0.0)

	if _t_buffer > 0.0 and pegado:
		velocity = Vector2(get_wall_normal().x * velocidad * 1.1, -_v_salto)
		mirando = signf(get_wall_normal().x)
		_t_buffer = 0.0
		pegado = false
		Audio.sonar("salto", 2.0)
	elif _t_buffer > 0.0 and _t_coyote > 0.0:
		velocity.y = -_v_salto
		_t_buffer = 0.0
		_t_coyote = 0.0
		# un poco de tono al azar: repetido identico cansa en dos minutos
		Audio.sonar("salto", randf_range(-1.0, 1.0))
	elif Input.is_action_just_released("saltar") and velocity.y < 0.0:
		velocity.y *= 0.45      # salto de altura variable

	if Input.is_action_just_pressed("impulso") and _t_espera <= 0.0:
		_t_impulso = impulso_dur
		_t_espera = impulso_espera
		_gastar(coste_impulso)
		Audio.sonar("impulso")

	if Input.is_action_just_pressed("pulso") and carga > coste_pulso:
		_gastar(coste_pulso)
		if _rejilla:
			_rejilla.limpiar()

	move_and_slide()

# ----------------------------------------------------------------- la estela
func _sobre_libre() -> bool:
	## las plataformas moviles no registran estela: son la unica superficie segura
	for i in get_slide_collision_count():
		var o = get_slide_collision(i).get_collider()
		if o is Node and (o as Node).is_in_group("sin_estela"):
			return true
	return false

func _estela(ahora: float, marcando: bool, punto: Vector2) -> void:
	if _rejilla == null:
		return
	var celda := _rejilla.celda_de(punto)
	if celda != _celda_previa:
		if marcando:
			_rejilla.marcar(celda, ahora)
		_celda_previa = celda
		_rejilla.purgar(ahora)
	elif marcando and not _rejilla.tiene(celda):
		_rejilla.marcar(celda, ahora)
	if _rejilla.mata(celda, ahora):
		morir()

# ------------------------------------------------------------------- la carga
func _gastar(cantidad: float) -> void:
	carga = clampf(carga - cantidad, 0.0, 100.0)
	carga_cambiada.emit(carga)
	if carga <= 0.0:
		morir()

func cargar(cantidad: float) -> void:
	carga = clampf(carga + cantidad, 0.0, 100.0)
	carga_cambiada.emit(carga)

func morir() -> void:
	if not vivo or _t_gracia > 0.0:
		return
	vivo = false
	Audio.sonar("muerte")
	velocity = Vector2.ZERO
	_bloqueo = ""
	_reproducir("muerte")
	# las chispas son del color de quien muere; las de TSL-04, las de siempre
	if personaje == Personajes.BASE:
		Efectos.muerte(global_position)
	else:
		Efectos.muerte(global_position, (Personajes.dato(personaje, "color") as Color).lightened(0.4))
	murio.emit()
