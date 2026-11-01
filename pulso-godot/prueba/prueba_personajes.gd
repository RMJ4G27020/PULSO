extends Node
## Los personajes jugables (scripts/personajes.gd).
##
## Lo que mas importa no es que cada uno sea distinto, sino la REGLA: ninguno
## puede saltar menos, correr menos ni caer mas deprisa que TSL-04, porque los
## niveles (a mano y generados) estan medidos con su fisica. Un personaje con
## menos alcance se encontraria saltos imposibles.
##
## El progreso se pone EN MEMORIA y el archivo real se copia al empezar y se
## devuelve al final; el personaje se fuerza con Personajes.forzado, que no se
## guarda nunca.

var fallos := 0
var _habia := false
var _copia := PackedByteArray()
var _acabado := false


func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-66s %s" % [txt, "OK" if c else "FALLA"])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func():
		_ok(false, "la prueba termina sola")
		_fin())
	_habia = FileAccess.file_exists(Guardado.RUTA)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Guardado.RUTA)
	Personajes.forzado = ""
	_regla_del_alcance()
	_desbloqueos()
	_eleccion_invalida()
	await _en_el_jugador()
	await _en_la_estela()
	await _en_un_nivel()
	await _en_todos()
	await _en_el_selector()
	_fin()


func _progreso(max_nivel: int, frags := {}) -> void:
	Guardado._datos = {"max_nivel": max_nivel, "tiempos": {}, "fragmentos": frags,
		"opciones": {}}


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ------------------------------------------------------------------ la regla
func _regla_del_alcance() -> void:
	var base: Node = load("res://escenas/Jugador.tscn").instantiate()
	# lo que da alcance: no puede bajar
	var no_baja := ["velocidad", "altura_salto", "impulso_vel", "impulso_dur", "coyote", "buffer"]
	# lo que lo quita si sube: no se puede tocar
	var fijo := ["gravedad", "factor_caida", "caida_maxima"]
	var bien := true
	var motivo := ""
	for id in Personajes.DATOS:
		var cambios: Dictionary = Personajes.DATOS[id]["jugador"]
		for k in cambios:
			if not (k in base):
				bien = false
				motivo = "%s cambia '%s', que no existe en jugador.gd" % [id, k]
			elif k in no_baja and float(cambios[k]) < float(base.get(k)):
				bien = false
				motivo = "%s baja %s (%.2f < %.2f)" % [id, k, float(cambios[k]), float(base.get(k))]
			elif k in fijo:
				bien = false
				motivo = "%s toca %s" % [id, k]
	base.free()
	_ok(bien, "ningun personaje tiene menos alcance que TSL-04%s" %
		("" if bien else " (" + motivo + ")"))
	# y cada uno cambia algo: si no, seria TSL-04 con otro color
	var distintos := true
	for id in Personajes.DATOS:
		if id == Personajes.BASE:
			continue
		var d: Dictionary = Personajes.DATOS[id]
		if (d["jugador"] as Dictionary).is_empty() and is_equal_approx(float(d["retardo"]), 0.35) \
				and is_equal_approx(float(d["duracion"]), 3.0):
			distintos = false
	_ok(distintos, "cada personaje juega distinto de TSL-04")

	# UNA ventaja y UN coste: sin pega seria TSL-04 con mas cosas. Lo que cuenta
	# como pega es lo que se siente de verdad. La duracion de la estela NO
	# cuenta: correr o aterrizar sobre la propia estela la vuelve a marcar, asi
	# que casi nunca pega (y TSL-01 la tenia como su unica pega, que no existia).
	var pegas := {"consumo": 1, "coste_impulso": 1, "coste_pulso": 1, "coste_adherencia": 1,
		"impulso_espera": 1}
	var sin_pega := ""
	for id in Personajes.DATOS:
		if id == Personajes.BASE:
			continue
		var cambios2: Dictionary = Personajes.DATOS[id]["jugador"]
		var pega := false
		var b2: Node = load("res://escenas/Jugador.tscn").instantiate()
		for k in pegas:
			if cambios2.has(k) and float(cambios2[k]) > float(b2.get(k)):
				pega = true
		b2.free()
		if not pega:
			sin_pega = id
	_ok(sin_pega == "", "cada personaje tiene una pega que se siente%s" %
		("" if sin_pega == "" else " (%s no la tiene)" % sin_pega))

	# La carga: una terminal da 15 y los fragmentos son opcionales, asi que a
	# ritmo de par la carga de cada TRAMO de un nivel (entre una baliza y la
	# siguiente, que recarga a tope) tiene que caber en 100 + 15. Con 2,4 %/s
	# TSL-02 pedia 139 % en el nivel 3 y ni a ritmo de par llegaba.
	var b4: Node = load("res://escenas/Jugador.tscn").instantiate()
	var tabla: Array = load("res://scripts/selector.gd").get("NIVELES")
	var carga_bien := true
	var carga_motivo := ""
	for id in Personajes.DATOS:
		var c4: Dictionary = Personajes.DATOS[id]["jugador"]
		var vel := float(c4.get("velocidad", b4.get("velocidad")))
		var cons := float(c4.get("consumo", b4.get("consumo")))
		for fila in tabla:
			var gasto := float(fila[2]) / float(fila[3]) * (float(b4.get("velocidad")) / vel) * cons
			if gasto > 115.0:
				carga_bien = false
				carga_motivo = "%s en '%s': %.0f %%" % [id, fila[1], gasto]
	b4.free()
	_ok(carga_bien, "a ritmo de par, la carga alcanza en todos los niveles%s" %
		("" if carga_bien else " (" + carga_motivo + ")"))

	# La pared: una celda se cruza deslizando en 16/deslizar s, y tiene que ser
	# MENOS que lo que tarda en encenderse, o resbalar por una pared mata. Con
	# TSL-04 es 0,348 contra 0,35 (de ahi que su deslizar sea 46 y no 45).
	var b3: Node = load("res://escenas/Jugador.tscn").instantiate()
	var pared_bien := true
	var pared_motivo := ""
	for id in Personajes.DATOS:
		var c3: Dictionary = Personajes.DATOS[id]["jugador"]
		var desliz := float(c3.get("deslizar", b3.get("deslizar")))
		var ret := float(Personajes.DATOS[id]["retardo"])
		if float(RejillaEstela.CELDA) / desliz >= ret:
			pared_bien = false
			pared_motivo = "%s: %.3f s por celda contra %.2f s de retardo" % [id,
				float(RejillaEstela.CELDA) / desliz, ret]
	b3.free()
	_ok(pared_bien, "ninguno muere resbalando por una pared%s" %
		("" if pared_bien else " (" + pared_motivo + ")"))


func _desbloqueos() -> void:
	_progreso(1)
	_ok(Personajes.desbloqueado("tsl04") and not Personajes.desbloqueado("tsl01")
		and not Personajes.desbloqueado("tsl02") and not Personajes.desbloqueado("tsl03"),
		"al empezar, solo TSL-04")
	_progreso(4)
	_ok(Personajes.desbloqueado("tsl01") and not Personajes.desbloqueado("tsl02"),
		"pasado el nivel 3 (el final), despierta TSL-01")
	_progreso(5)
	_ok(Personajes.desbloqueado("tsl02"), "pasado el nivel 4, TSL-02")
	_progreso(5, {"1": 3, "2": 3, "3": 3, "4": 2})
	_ok(not Personajes.desbloqueado("tsl03"), "con 11 fragmentos, TSL-03 sigue dormida")
	_progreso(5, {"1": 3, "2": 3.0, "3": 3, "4": 3})
	_ok(Personajes.desbloqueado("tsl03"), "con los 12, despierta (aunque el JSON los de como 3.0)")


func _eleccion_invalida() -> void:
	_progreso(5)
	Guardado.poner_opcion("personaje", "tsl01")
	_ok(Personajes.actual() == "tsl01", "el elegido manda")
	Guardado.poner_opcion("personaje", "tsl99")
	_ok(Personajes.actual() == Personajes.BASE, "uno que no existe: TSL-04")
	_progreso(2)
	Guardado.poner_opcion("personaje", "tsl01")
	_ok(Personajes.actual() == Personajes.BASE, "uno todavia cerrado: TSL-04")
	# TSL-02 y TSL-03 aun no tienen arte: no se ofrecen aunque esten abiertos
	_progreso(5, {"1": 3, "2": 3, "3": 3, "4": 3})
	for id in ["tsl02", "tsl03"]:
		Guardado.poner_opcion("personaje", id)
		if not Personajes.disponible(id):
			_ok(Personajes.actual() == Personajes.BASE and not (id in Personajes.elegibles()),
				"%s sin arte todavia: no se ofrece y se juega con TSL-04" % id)
	_ok(Personajes.elegibles()[0] == Personajes.BASE, "TSL-04 siempre es elegible y va primera")
	# el forzado manda sobre el progreso: en una partida nueva, un bot lanzado
	# con PULSO_PERSONAJE tiene que correr con ese, no con TSL-04 a escondidas
	_progreso(1)
	Personajes.forzado = "tsl01"
	_ok(Personajes.actual() == "tsl01" and not Personajes.desbloqueado("tsl01"),
		"forzado: TSL-01 se juega aunque la partida este en el nivel 1")
	Personajes.forzado = "tsl99"
	Personajes._avisado = true          # el aviso es a proposito: que no ensucie la salida
	_ok(Personajes.actual() == Personajes.BASE, "forzado a uno que no existe: TSL-04")
	Personajes.forzado = ""


# -------------------------------------------------------------- aplicarlos
func _en_el_jugador() -> void:
	_progreso(5)
	Personajes.forzado = "tsl01"
	var j: CharacterBody2D = load("res://escenas/Jugador.tscn").instantiate()
	add_child(j)
	await _cuadros(1)
	var sf: SpriteFrames = (j.get_node("Sprite") as AnimatedSprite2D).sprite_frames
	_ok(j.personaje == "tsl01" and is_equal_approx(j.consumo, 1.3),
		"TSL-01 gasta 1,3 %%/s de carga (%.2f)" % j.consumo)
	_ok(is_equal_approx(j.coste_impulso, 5.0), "y su impulso cuesta 5 %% (%.1f)" % j.coste_impulso)
	_ok(sf != null and sf.resource_path == Personajes.DATOS["tsl01"]["hojas"],
		"y se ve con sus hojas ambar")
	_ok(is_equal_approx(j.velocidad, 220.0) and is_equal_approx(j._v_salto, sqrt(2.0 * 980.0 * 115.0)),
		"corre y salta como TSL-04")
	j.queue_free()
	Personajes.forzado = Personajes.BASE
	var b: CharacterBody2D = load("res://escenas/Jugador.tscn").instantiate()
	add_child(b)
	await _cuadros(1)
	_ok(is_equal_approx(b.consumo, 1.6) and is_equal_approx(b.coste_impulso, 3.0)
		and (b.get_node("Sprite") as AnimatedSprite2D).sprite_frames.resource_path
		== Personajes.DATOS["tsl04"]["hojas"], "y TSL-04 sigue siendo la de siempre")
	b.queue_free()
	await _cuadros(1)


func _en_la_estela() -> void:
	Guardado.poner_opcion("asistencia", false)
	Personajes.forzado = "tsl01"
	var r := Node2D.new()
	r.set_script(load("res://scripts/rejilla_estela.gd"))
	add_child(r)
	await _cuadros(1)
	_ok(is_equal_approx(r.retardo, 0.55) and is_equal_approx(r.duracion, 5.0),
		"la estela de TSL-01 se enciende a los 0,55 s y dura 5")
	var c := Vector2i(9000, 9000)
	r.limpiar()
	r.marcar(c, 0.0)
	_ok(not r.mata(c, 0.50) and r.mata(c, 0.56) and r.mata(c, 4.9) and not r.mata(c, 5.0),
		"y mata exactamente de 0,55 a 5 s")
	_ok(r.color_cinta == Personajes.DATOS["tsl01"]["color"] and r.hojas_estela.contains("ambar"),
		"con su cinta y sus laminas ambar")
	r.poner_asistencia(true)
	_ok(is_equal_approx(r.retardo, 1.10), "la asistencia DOBLA el suyo: 1,10 s (%.2f)" % r.retardo)
	r.queue_free()
	Personajes.forzado = Personajes.BASE
	var b := Node2D.new()
	b.set_script(load("res://scripts/rejilla_estela.gd"))
	add_child(b)
	await _cuadros(1)
	b.poner_asistencia(false)
	var con_asist: float = 0.0
	b.poner_asistencia(true)
	con_asist = b.retardo
	_ok(is_equal_approx(con_asist, RejillaEstela.RETARDO_ASISTIDO) and is_equal_approx(b.duracion, 3.0),
		"y con TSL-04 la asistencia sigue dando 0,70 s y la estela 3 s")
	b.queue_free()
	await _cuadros(1)


func _en_un_nivel() -> void:
	_progreso(5)
	Personajes.forzado = "tsl01"
	var n: Node2D = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate()
	add_child(n)
	await get_tree().create_timer(0.3, true, false, true).timeout
	var j: Node = n.get_node("Jugador")
	var rej: Node = get_tree().get_first_node_in_group("estela")
	_ok(j.personaje == "tsl01" and is_equal_approx(rej.retardo_base, 0.55),
		"dentro de un nivel de verdad, jugador y estela son de TSL-01")
	_ok(is_equal_approx(n._hud.consumo, 1.3),
		"y el HUD calcula la fuga de carga con su consumo (%.2f)" % n._hud.consumo)
	n.queue_free()
	Personajes.forzado = ""
	await _cuadros(2)


## Lo mismo para cada personaje de la tabla, sin repetir lo de TSL-01: todo lo
## que dice DATOS tiene que llegar al jugador y a la estela de verdad.
func _en_todos() -> void:
	_progreso(5, {"1": 3, "2": 3, "3": 3, "4": 3})
	var con_arte := 0
	for id in Personajes.ORDEN:
		if not Personajes.disponible(id):
			continue
		con_arte += 1
		Personajes.forzado = id
		var d: Dictionary = Personajes.DATOS[id]
		var j: CharacterBody2D = load("res://escenas/Jugador.tscn").instantiate()
		add_child(j)
		var r := Node2D.new()
		r.set_script(load("res://scripts/rejilla_estela.gd"))
		add_child(r)
		await _cuadros(1)
		var bien: bool = j.personaje == id
		var que := ""
		for k in d["jugador"]:
			if not is_equal_approx(float(j.get(k)), float(d["jugador"][k])):
				bien = false
				que = "%s %s=%s" % [id, k, str(j.get(k))]
		var sf: SpriteFrames = (j.get_node("Sprite") as AnimatedSprite2D).sprite_frames
		_ok(bien and sf.resource_path == d["hojas"],
			"%s: jugador con lo que dice su ficha y sus hojas%s" % [id, "" if que == "" else " (" + que + ")"])
		_ok(is_equal_approx(j._v_salto, sqrt(2.0 * j.gravedad * j.altura_salto)),
			"%s: la velocidad de salto sigue a su altura (%.1f px)" % [id, j.altura_salto])
		_ok(is_equal_approx(r.retardo_base, float(d["retardo"])) and is_equal_approx(r.duracion, float(d["duracion"]))
			and r.color_cinta == d["color"] and r.hojas_estela == d["estela"],
			"%s: la estela, con su retardo, su duracion, su cinta y sus laminas" % id)
		# alcance: lo que se mide, no lo que dice la tabla
		_ok(j.velocidad >= 220.0 and j.altura_salto >= 115.0 and j.impulso_vel >= 340.0
			and j.impulso_dur >= 0.18 and j.gravedad == 980.0 and j.factor_caida == 1.6
			and j.caida_maxima == 520.0, "%s: no tiene menos alcance que TSL-04" % id)
		j.queue_free()
		r.queue_free()
		await _cuadros(1)
	Personajes.forzado = ""
	_ok(con_arte == Personajes.ORDEN.size(), "los cuatro tienen arte (%d de %d)" % [con_arte, Personajes.ORDEN.size()])


func _en_el_selector() -> void:
	var s: Control = Control.new()
	s.set_script(load("res://scripts/selector.gd"))
	add_child(s)
	s.cambiar_de_verdad = false
	await _cuadros(1)
	_progreso(2)
	s.abrir()
	s._ciclar(1)
	_ok(Personajes.actual() == Personajes.BASE and s.aviso == "Pasa el nivel 3 para despertar a TSL-01",
		"con un solo personaje, cambiar dice como despertar el siguiente")
	_progreso(4)
	s._ciclar(1)
	_ok(Personajes.actual() == "tsl01" and String(Guardado.opcion("personaje", "")) == "tsl01",
		"con TSL-01 despierta, cambiar la elige y la guarda")
	_ok(s.aviso == "TSL-01: estela lenta; impulso caro", "y dice su rasgo (\"%s\")" % s.aviso)
	s._ciclar(1)
	_ok(Personajes.actual() == Personajes.BASE, "y la siguiente vuelta, otra vez TSL-04")
	# con todo despierto, cambiar da la vuelta por los cuatro en su orden
	_progreso(5, {"1": 3, "2": 3, "3": 3, "4": 3})
	Guardado.poner_opcion("personaje", Personajes.BASE)
	var lista: Array[String] = Personajes.elegibles()
	var vuelta: Array[String] = []
	for i in lista.size():
		s._ciclar(1)
		vuelta.append(Personajes.actual())
	var esperada: Array[String] = []
	for i in lista.size():
		esperada.append(lista[(i + 1) % lista.size()])
	_ok(vuelta == esperada and lista.size() >= 2, "con todo despierto, la vuelta es %s" % str(esperada))
	s._ciclar(-1)
	_ok(Personajes.actual() == lista[lista.size() - 1], "y hacia atras desde TSL-04 se llega a la ultima")
	_progreso(4)
	Guardado.poner_opcion("personaje", "tsl01")
	# el retrato: una sola hoja, la de reposo, y no las doce del personaje
	for id in Personajes.elegibles():
		var rt: Texture2D = s._retrato(id)
		_ok(rt is AtlasTexture and (rt as AtlasTexture).atlas.resource_path.ends_with("tsl04_reposo.png")
			and (rt as AtlasTexture).region == Rect2(0, 0, 288, 288),
			"el retrato de %s sale de la hoja de reposo, cuadro 0" % id)
	# las cajas del personaje
	var pers: Rect2 = s.caja_personaje()
	var vol: Rect2 = s.caja_volver()
	_ok(pers.size.y >= 46.0 and (s.caja_panel() as Rect2).encloses(pers) and pers.end.x <= vol.position.x,
		"el personaje se toca con el pulgar, cabe y no pisa Volver")
	s.queue_free()
	await _cuadros(1)


func _fin() -> void:
	if _acabado:
		return
	_acabado = true
	Personajes.forzado = ""
	if _habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_copia)
			fa.close()
	else:
		DirAccess.remove_absolute(Guardado.RUTA)
	Guardado.cargar()
	print("FALLOS: %d" % fallos)
	print("PRUEBA PERSONAJES OK")
	get_tree().quit()
