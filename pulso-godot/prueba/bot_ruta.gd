extends Node
## Bot de ruta para los niveles GRANDES. Corre hacia la derecha y salta en los
## bordes, como el de prueba/prueba_bot.gd, y ademas:
##   - salta los pinchos que tenga delante,
##   - acciona la terminal al llegar (el bot la cruzaria corriendo; una persona
##     se para 0,45 s encima, y aqui se llama a activar() de golpe),
##   - y, si es PACIENTE, espera a que un laser le deje pasar: antes de cruzar un
##     haz mira en que punto de su ciclo esta y, si va a estar encendido cuando
##     llegue, retrocede un poco. No se puede parar (la estela mata), pero ir y
##     volver dentro de unas celdas deja marcar de nuevo las mismas celdas.
## Con el paciente, "pasa" significa que todo laser del nivel deja un hueco por
## el que cabe un jugador que corra a 220 px/s.

## segundos de juego que se aguanta el boton de salto (la subida entera dura 0,48 s;
## en ticks no vale, porque la prueba sube los ticks por segundo para ir mas deprisa)
const RETEN := 0.55
## cuanto antes de llegar al haz se decide, y la holgura que se exige de ciclo
const HOLGURA_ANTES := 0.30
const HOLGURA_DESPUES := 0.35
const FRENTE := 150.0                  ## hasta donde mira un laser por delante

var n: Node2D
var jug: CharacterBody2D
var paciente := false
var activo := false
var llegada := false
var x_max := -99999.0
var muertes := 0
var esperas := 0                       ## ticks que ha estado esperando a un laser
var saltos := 0
var murio_en: Array = []               ## donde murio (x), para saber en que tramo
var t := 0.0
var _reten := 0.0
var _lasers: Array = []
var _pinchos: Array = []
var _terminal_hecha := false


func iniciar(nivel: Node2D, paciente_: bool) -> void:
	n = nivel
	jug = n.get_node("Jugador")
	paciente = paciente_
	for p in get_tree().get_nodes_in_group("peligro"):
		var s: Script = p.get_script()
		var ruta := String(s.resource_path) if s != null else ""
		if ruta.ends_with("laser.gd"):
			_lasers.append(p)
		elif ruta.ends_with("pinchos.gd"):
			_pinchos.append(p)
	jug.murio.connect(func():
		muertes += 1
		murio_en.append(jug.global_position.x)
		if muertes <= 6:
			print("      murio %d en x=%.0f y=%.0f t=%.1f" % [muertes, jug.global_position.x,
				jug.global_position.y, t]))
	var sal := n.get_node_or_null("Salida")
	if sal:
		sal.alcanzado.connect(func(): llegada = true)
	activo = true


func _rumbo(d: float) -> void:
	Input.action_release("mover_izq" if d > 0.0 else "mover_der")
	Input.action_press("mover_der" if d > 0.0 else "mover_izq")


func parar() -> void:
	activo = false
	for a in ["mover_der", "mover_izq", "saltar"]:
		Input.action_release(a)


func _solido(a: Vector2, b: Vector2) -> bool:
	var p := PhysicsRayQueryParameters2D.create(a, b)
	p.exclude = [jug.get_rid()]
	return not get_viewport().world_2d.direct_space_state.intersect_ray(p).is_empty()


func _borde() -> bool:
	var d: Vector2 = jug.global_position + Vector2(26.0, 0)
	return not _solido(d, d + Vector2(0, 36))


## Segundos hasta que el laser esta encendido (0 si ya lo esta) y cuanto dura.
func _estado_laser(l: Node) -> Vector2:
	var ciclo: float = l.reposo + l.carga + l.disparo
	var f: float = fmod(l._t, ciclo)
	var enciende: float = l.reposo + l.carga
	if f >= enciende:
		return Vector2(0.0, ciclo - f)             # encendido ahora, y lo que le queda
	return Vector2(enciende - f, l.disparo)        # se enciende dentro de...


## Cierto si llegando a su haz dentro de `llega` s no hay peligro.
func _pasa(l: Node, llega: float) -> bool:
	var ciclo: float = l.reposo + l.carga + l.disparo
	var f: float = fmod(l._t + llega, ciclo)
	var enciende: float = l.reposo + l.carga
	# lo que hay que evitar: encendido entre llega - ANTES y llega + DESPUES
	for dt in [-HOLGURA_ANTES, 0.0, HOLGURA_DESPUES]:
		var g: float = fmod(l._t + llega + dt + ciclo * 4.0, ciclo)
		if g >= enciende:
			return false
	return f < enciende


func _physics_process(d: float) -> void:
	if not activo:
		return
	t += d
	if not jug.vivo:
		_reten = 0.0
		Input.action_release("saltar")
		return
	x_max = maxf(x_max, jug.global_position.x)
	var px: float = jug.global_position.x
	# la terminal: al llegar a ella, se acciona
	var inter: Area2D = n.get_node_or_null("Interruptor")
	# solo por la x: en n5 la terminal esta en una repisa sobre el pasillo y el bot
	# no sube a ella; lo que se prueba es la ruta, no ese salto
	if inter != null and not _terminal_hecha and absf(px - inter.global_position.x) < 24.0:
		_terminal_hecha = true
		inter.activar()

	if _reten > 0.0:
		_rumbo(1.0)
		_reten -= d
		if _reten <= 0.0:
			Input.action_release("saltar")
		return
	if not jug.is_on_floor():
		if not jug.is_on_wall():
			_rumbo(1.0)
		return

	# --- en el suelo
	var b := _borde()
	var muro := jug.is_on_wall()
	var salto := b or muro or _pincho_delante()

	if paciente:
		var l: Node = _laser_delante(px)
		if l != null:
			var dist: float = l.global_position.x - px
			# al saltar, el haz se cruza a velocidad de vuelo; en el suelo, andando
			var llega: float = maxf(dist, 0.0) / float(jug.velocidad)
			if salto and (b or muro):
				llega += 0.0
			if not _pasa(l, llega):
				# esperar: alejarse del borde o del haz, y volver a acercarse
				esperas += 1
				if b or dist < 96.0:
					_rumbo(-1.0)
				else:
					_rumbo(1.0)
				return
	_rumbo(1.0)
	if salto:
		Input.action_press("saltar")
		_reten = RETEN
		saltos += 1


func _pincho_delante() -> bool:
	for p in _pinchos:
		if not is_instance_valid(p):
			continue
		var dx: float = p.global_position.x - jug.global_position.x
		var dy: float = absf(p.global_position.y - jug.global_position.y)
		if dx > 0.0 and dx < 56.0 and dy < 40.0:
			return true
	return false


## El laser mas cercano por delante, a menos de FRENTE px y a una altura que
## importa (el haz cae sobre la fila del jugador o debajo de ella).
func _laser_delante(px: float) -> Node:
	var mejor: Node = null
	var md := 1.0e9
	for l in _lasers:
		if not is_instance_valid(l):
			continue
		var dx: float = l.global_position.x - px
		if dx > -4.0 and dx < FRENTE and dx < md:
			var y0: float = l.global_position.y + 16.0
			var y1: float = y0 + 16.0 * float(l.largo_celdas)
			# el haz alcanza al jugador si su altura cae dentro del haz (con margen)
			if jug.global_position.y > y0 - 24.0 and jug.global_position.y < y1 + 64.0:
				md = dx
				mejor = l
	return mejor
