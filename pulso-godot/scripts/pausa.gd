extends Control
## Menu de pausa. Antes la tecla de pausa te sacaba al menu y perdias el nivel;
## despues existia pero era inalcanzable: abrirlo reiniciaba el nivel, la tecla
## lo abria y lo cerraba en el mismo cuadro, y en movil no habia boton ninguno.
##
## Reglas que salieron de medir el que habia:
##  * Los renglones de accion son de 46 px porque por debajo no se aciertan con
##    el pulgar. Los ajustes pueden ser de 30: se tocan sin prisa.
##  * El volumen son OCHO CELDAS discretas, no un deslizador. Con el pulgar se
##    acierta una celda; arrastrar obliga a mirar el valor.
##  * Cero celdas en la fila de efectos ES el silencio. Asi no gasta una fila
##    propia, que hacia falta: siete filas no caben en 360 px de alto.
##  * Las dos filas que borran la partida piden DOS toques y llevan aire y
##    barra roja delante. Antes estaban a 12 px de "Continuar".
##  * Al reanudar, el velo cae y un pulso cian recorre el borde ANTES de
##    descongelar: en un juego donde tienes 0,35 s, volver de golpe desorienta.

signal continuar
signal reiniciar
signal salir

const CIAN := Color(0.21, 0.85, 1.0)
const ROJO := Color(1.0, 0.32, 0.28)
const HUESO := Color(0.86, 0.93, 0.97)
const APAGADO := Color(0.62, 0.68, 0.72)

const OPCIONES := ["Continuar", "Volumen efectos", "Volumen musica",
	"Accesibilidad", "Reiniciar nivel", "Salir al menu"]
const CLASES := ["accion", "volumen", "volumen", "interruptores", "destructiva", "destructiva"]

## Tres interruptores en UNA fila de 30 px, lado a lado, y no una pagina nueva.
## El menu ya ocupa 302 de 360 px y dos filas mas no cabian; una segunda pagina
## si cabia, pero escondia los ajustes detras de un toque mas y anadia estado de
## navegacion (y un boton atras que tendria que volver a la primera). Asi los
## tres se ven y se cambian de un toque, y la altura del menu no se mueve.
const INTERRUPTORES := ["cerco_fijo", "asistencia", "vibracion"]
const ROTULOS := ["Cerco fijo", "Asistencia", "Vibracion"]
const POR_DEFECTO := [false, false, true]
const ALTOS := [46.0, 30.0, 30.0, 30.0, 46.0, 46.0]
const AIRE := [0.0, 0.0, 0.0, 0.0, 24.0, 0.0]      ## aire EXTRA antes de la fila
const SEPARACION := 10.0
const CELDAS := 8
const CONFIRMA := 2.0                               ## s que dura "confirmar"
const VELO := 0.86

var abierto := false
var _sel := 0
var _filas: Array[Rect2] = []
var _confirmando := -1
var _chip := 0                   ## interruptor enfocado con teclado o mando
var _t_confirma := 0.0

## Lo que tape el menu: el HUD y los mandos. Con el cronometro encendido debajo
## del velo se leia mejor la hora que las propias opciones, y los tres circulos
## cian del mando parecian pulsables y no hacian nada.
var hud: CanvasLayer
var mandos: CanvasLayer

# --- animacion: todo en floats, porque el Control corre con el arbol pausado
var _t_abrir := 0.0
var _t_cerrar := -1.0
var _fuente: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fuente = ThemeDB.fallback_font
	visible = false
	_colocar()
	get_viewport().size_changed.connect(_colocar)

func alto_total() -> float:
	var h := 0.0
	for i in OPCIONES.size():
		h += float(ALTOS[i]) + float(AIRE[i])
		if i > 0:
			h += SEPARACION
	return h

## Ancho proporcional, no 260 px fijos: a 780 px de viewport el bloque de antes
## ocupaba un tercio de la pantalla y quedaba perdido en el centro.
func ancho_panel() -> float:
	return clampf(get_viewport_rect().size.x * 0.46, 240.0, 340.0)

func _colocar() -> void:
	var r: Vector2 = get_viewport_rect().size
	var an := ancho_panel()
	var y: float = maxf(r.y * 0.5 - alto_total() * 0.5 + 8.0, 38.0)
	_filas.clear()
	for i in OPCIONES.size():
		y += float(AIRE[i])
		_filas.append(Rect2(r.x * 0.5 - an * 0.5, y, an, float(ALTOS[i])))
		y += float(ALTOS[i]) + SEPARACION
	queue_redraw()

func abrir() -> void:
	if abierto: return
	abierto = true
	visible = true
	_sel = 0
	_confirmando = -1
	_t_abrir = 0.0
	_t_cerrar = -1.0
	_colocar()
	if hud: hud.visible = false
	if mandos: mandos.visible = false
	get_tree().paused = true
	if Audio.has_method("musica_atenuada"):
		Audio.musica_atenuada(true)
	queue_redraw()

## `inmediato` para reiniciar y para salir: ahi NO puede haber ceremonia. Un
## change_scene_to_file con el arbol pausado deja el nivel siguiente congelado
## y sin forma de salir, que es un bloqueo total.
func cerrar(inmediato: bool = false) -> void:
	if not abierto: return
	abierto = false
	_confirmando = -1
	if hud: hud.visible = true
	if mandos: mandos.visible = true
	if Audio.has_method("musica_atenuada"):
		Audio.musica_atenuada(false)
	if inmediato:
		visible = false
		_t_cerrar = -1.0
		get_tree().paused = false
	else:
		_t_cerrar = 0.0
	queue_redraw()

func alternar() -> void:
	if abierto: _elegir(0)
	else: abrir()

# -------------------------------------------------------------------- ajustes
func celdas_efectos() -> int:
	if Audio.silencio:
		return 0
	return clampi(int(round(Audio.volumen * float(CELDAS))), 0, CELDAS)

func celdas_musica() -> int:
	return clampi(int(round(_vol_musica() * float(CELDAS))), 0, CELDAS)

## El volumen de musica lo crea el autoload Audio aparte del de efectos: quien
## juega en el metro quiere bajar la musica sin perder los avisos. Se lee con
## get/set para no depender de que exista todavia.
func _vol_musica() -> float:
	var v: Variant = Audio.get("volumen_musica")
	return float(v) if v != null else 0.0

func _poner_musica(v: float) -> void:
	Audio.set("volumen_musica", clampf(v, 0.0, 1.0))

func poner_celdas(fila: int, n: int) -> void:
	var c: int = clampi(n, 0, CELDAS)
	if fila == 1:
		# cero celdas ES el silencio: no hace falta una fila propia para el
		Audio.silencio = c == 0
		if c > 0:
			Audio.volumen = float(c) / float(CELDAS)
	elif fila == 2:
		_poner_musica(float(c) / float(CELDAS))

func interruptor(k: int) -> bool:
	return bool(Guardado.opcion(INTERRUPTORES[k], POR_DEFECTO[k]))

## Guarda y ademas avisa a quien lo este usando AHORA: la pausa se abre con el
## nivel en marcha, y reiniciarlo para aplicar un ajuste seria castigar a quien
## lo busca justo porque le cuesta.
func alternar_interruptor(k: int) -> void:
	var v: bool = not interruptor(k)
	Guardado.poner_opcion(INTERRUPTORES[k], v)
	Guardado.guardar()
	match INTERRUPTORES[k]:
		"cerco_fijo":
			var h: Node = get_tree().get_first_node_in_group("hud")
			if h:
				h.set("cerco_fijo", v)
		"asistencia":
			var rej: Node = get_tree().get_first_node_in_group("estela")
			if rej and rej.has_method("poner_asistencia"):
				rej.poner_asistencia(v)
		# la vibracion se lee en el momento de morir, no hace falta avisar
	queue_redraw()

func _caja_chip(f: Rect2, k: int) -> Rect2:
	var hueco := 4.0
	var ancho: float = (f.size.x - 16.0 - hueco * 2.0) / 3.0
	return Rect2(f.position.x + 8.0 + (ancho + hueco) * float(k),
		f.position.y + 4.0, ancho, f.size.y - 8.0)

# ---------------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if not abierto: return
	# la tecla de pausa la consume el menu cuando esta abierto; cuando esta
	# cerrado la ve nivel.gd en _unhandled_input. Asi no se abre y se cierra en
	# el mismo cuadro, que era el motivo de que el menu no llegara a verse.
	if e.is_action_pressed("pausa") or e.is_action_pressed("ui_cancel"):
		_elegir(0)
		get_viewport().set_input_as_handled()
		return
	var p := Vector2.INF
	if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		p = (e as InputEventScreenTouch).position
	elif e is InputEventMouseButton and es_clic(e as InputEventMouseButton):
		p = (e as InputEventMouseButton).position
	elif e is InputEventScreenDrag:
		# arrastrar sobre una fila de volumen la barre: es lo unico que se puede
		# hacer sin levantar el dedo y mirando poco
		var d: Vector2 = (e as InputEventScreenDrag).position
		for i in _filas.size():
			if CLASES[i] == "volumen" and _filas[i].has_point(d):
				_sel = i
				poner_celdas(i, _celda_en(i, d.x))
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		return
	if p == Vector2.INF: return
	for i in _filas.size():
		if _filas[i].has_point(p):
			_sel = i
			if CLASES[i] == "interruptores":
				for k in INTERRUPTORES.size():
					if _caja_chip(_filas[i], k).grow(2.0).has_point(p):
						_chip = k
						alternar_interruptor(k)
				get_viewport().set_input_as_handled()
				return
			if CLASES[i] == "volumen":
				poner_celdas(i, _celda_en(i, p.x))
				queue_redraw()
			else:
				_elegir(i)
			get_viewport().set_input_as_handled()
			return

## Solo el clic izquierdo de un raton DE VERDAD. Un dedo en la pantalla llega
## dos veces: el clic que Godot emula a partir del toque (emulate_mouse_from_touch
## vale true de fabrica) y despues el propio toque. Aceptando los dos, un solo
## toque en una fila que pide confirmar la confirmaba en el acto, y un
## interruptor se encendia y se apagaba a la vez. El emulado se ignora y vale el
## toque. Y la rueda tambien llega como "boton pulsado": dos muescas confirmaban.
static func es_clic(b: InputEventMouseButton) -> bool:
	return b.pressed and b.button_index == MOUSE_BUTTON_LEFT \
		and b.device != InputEvent.DEVICE_ID_EMULATION

func _caja_celdas(i: int) -> Rect2:
	var f: Rect2 = _filas[i]
	var x0: float = f.position.x + f.size.x * 0.52
	return Rect2(x0, f.position.y + f.size.y * 0.5 - 7.0, f.end.x - 14.0 - x0, 14.0)

## Tocar a la IZQUIERDA de la primera celda apaga: es el gesto natural de
## "bajarlo del todo" y da acceso al silencio sin una fila extra.
func _celda_en(i: int, x: float) -> int:
	var c: Rect2 = _caja_celdas(i)
	if x < c.position.x:
		return 0
	var paso: float = c.size.x / float(CELDAS)
	return clampi(int(floor((x - c.position.x) / paso)) + 1, 0, CELDAS)

func _process(d: float) -> void:
	if _t_cerrar >= 0.0:
		_t_cerrar += d
		# 0,10 s de velo + 0,18 s de pulso por el borde superior, y SOLO
		# entonces se descongela
		if _t_cerrar >= 0.28:
			_t_cerrar = -1.0
			visible = false
			get_tree().paused = false
		queue_redraw()
		return
	if not abierto: return
	_t_abrir += d
	if _t_confirma > 0.0:
		_t_confirma = maxf(_t_confirma - d, 0.0)
		if _t_confirma <= 0.0:
			_confirmando = -1
	queue_redraw()
	if Input.is_action_just_pressed("ui_down"):
		_sel = (_sel + 1) % OPCIONES.size()
	if Input.is_action_just_pressed("ui_up"):
		_sel = (_sel - 1 + OPCIONES.size()) % OPCIONES.size()
	if Input.is_action_just_pressed("ui_right"):
		_mover_ajuste(1)
	if Input.is_action_just_pressed("ui_left"):
		_mover_ajuste(-1)
	# Solo ui_accept, no "saltar". La flecha arriba es de las dos acciones, asi
	# que subir de fila ELEGIA la fila nueva en el mismo cuadro: desde "Volumen
	# musica" se subia el volumen de efectos, y desde "Volumen efectos" se
	# llegaba a "Continuar" y la pausa se cerraba sola. Y desde que las teclas se
	# pueden reasignar, cualquier tecla de saltar que fuera tambien de ui_* haria
	# lo mismo. Espacio sigue eligiendo: es de ui_accept de fabrica.
	if Input.is_action_just_pressed("ui_accept"):
		_elegir(_sel)

func _mover_ajuste(paso: int) -> void:
	if CLASES[_sel] == "volumen":
		var n: int = celdas_efectos() if _sel == 1 else celdas_musica()
		poner_celdas(_sel, n + paso)
	elif CLASES[_sel] == "interruptores":
		# izquierda y derecha MUEVEN el foco entre los tres; aceptar los cambia.
		# Si izquierda/derecha los cambiaran, recorrer la fila con el mando iria
		# encendiendo y apagando todo lo que tocara por el camino.
		_chip = clampi(_chip + paso, 0, INTERRUPTORES.size() - 1)

func _elegir(i: int) -> void:
	match CLASES[i]:
		"volumen":
			_mover_ajuste(1)
			return
		"interruptores":
			alternar_interruptor(_chip)
			return
		"destructiva":
			# dos toques: la fila esta a un dedo de "Continuar" y borra la
			# partida sin vuelta atras
			if _confirmando != i:
				_confirmando = i
				_t_confirma = CONFIRMA
				queue_redraw()
				return
	match i:
		0:
			cerrar(); continuar.emit()
		4:
			cerrar(true); reiniciar.emit()
		5:
			cerrar(true); salir.emit()

# --------------------------------------------------------------------- pintar
func _draw() -> void:
	var r: Vector2 = get_viewport_rect().size
	var abre: float = clampf(_t_abrir / 0.12, 0.0, 1.0)
	var velo: float = VELO * abre
	if _t_cerrar >= 0.0:
		velo = VELO * clampf(1.0 - _t_cerrar / 0.10, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.02, 0.03, 0.04, velo))

	if _t_cerrar >= 0.0:
		# pulso de reanudado: recorre el borde superior en 0,18 s. Es un aviso
		# corporal de que el juego vuelve a correr, en el mismo vocabulario que
		# el cerco del HUD.
		var f: float = clampf((_t_cerrar - 0.10) / 0.18, 0.0, 1.0)
		if f > 0.0:
			var an: float = r.x * 0.28
			draw_rect(Rect2(r.x * (1.0 + an / r.x) * f - an, 0.0, an, 4.0),
				Color(CIAN.r, CIAN.g, CIAN.b, 0.85 * (1.0 - f * 0.4)))
		return
	if not abierto:
		return

	# marco diegetico: el juego pasa dentro de una computadora, asi que el menu
	# es un aviso del sistema, no un cartel que dice PAUSA encima del titulo
	draw_rect(Rect2(14.0, 14.0, r.x - 28.0, r.y - 28.0),
		Color(CIAN.r, CIAN.g, CIAN.b, 0.22 * abre), false, 2.0)
	var cab: Vector2 = Vector2(_filas[0].position.x, maxf(_filas[0].position.y - 16.0, 30.0))
	_texto("> SISTEMA EN ESPERA", cab, 15, Color(CIAN.r, CIAN.g, CIAN.b, 0.85 * abre))

	for i in _filas.size():
		# las filas entran 10 px escalonadas: se lee el orden de la lista
		var e: float = clampf((_t_abrir - 0.04 * float(i)) / 0.12, 0.0, 1.0)
		var f: Rect2 = _filas[i]
		f.position.y += 10.0 * (1.0 - e)
		_fila(i, f, e)

func _fila(i: int, f: Rect2, e: float) -> void:
	var activa: bool = i == _sel
	var destructiva: bool = CLASES[i] == "destructiva"
	var confirma: bool = _confirmando == i
	var base: Color = CIAN
	if confirma:
		base = ROJO
	draw_rect(f, Color(base.r, base.g, base.b, (0.16 if activa else 0.06) * e))
	if activa or confirma:
		draw_rect(f, Color(base.r, base.g, base.b, e), false, 2.0)
	if destructiva:
		# barra roja a la izquierda: se ve antes de leer el rotulo
		draw_rect(Rect2(f.position.x, f.position.y, 3.0, f.size.y),
			Color(ROJO.r, ROJO.g, ROJO.b, (1.0 if confirma else 0.55) * e))

	var rotulo: String = OPCIONES[i]
	var col: Color = HUESO if activa else APAGADO
	if destructiva:
		col = Color(APAGADO.r, APAGADO.g, APAGADO.b) if not activa else HUESO
		if confirma:
			rotulo = "confirmar"
			col = ROJO
	if CLASES[i] == "volumen" and i == 1 and celdas_efectos() == 0:
		col = ROJO
		rotulo = OPCIONES[i] + "  (silencio)"
	col.a = e
	if CLASES[i] != "interruptores":
		_texto(rotulo, f.position + Vector2(16.0, f.size.y * 0.68), 16, col)

	if CLASES[i] == "volumen":
		var n: int = celdas_efectos() if i == 1 else celdas_musica()
		var c: Rect2 = _caja_celdas(i)
		c.position.y = f.position.y + f.size.y * 0.5 - 7.0
		var paso: float = c.size.x / float(CELDAS)
		for k in CELDAS:
			var cel := Rect2(c.position.x + paso * float(k) + 2.0, c.position.y,
				paso - 4.0, c.size.y)
			if k < n:
				draw_rect(cel, Color(CIAN.r, CIAN.g, CIAN.b, 0.85 * e))
			else:
				draw_rect(cel, Color(CIAN.r, CIAN.g, CIAN.b, 0.18 * e))
	elif CLASES[i] == "interruptores":
		for k in INTERRUPTORES.size():
			var c: Rect2 = _caja_chip(f, k)
			var on: bool = interruptor(k)
			var foco: bool = activa and k == _chip
			# Encendido = relleno cian con letra oscura; apagado = solo contorno
			# y letra gris. Es el mismo vocabulario que las celdas de volumen,
			# asi que se lee de un vistazo sin rotulo de "si/no".
			if on:
				draw_rect(c, Color(CIAN.r, CIAN.g, CIAN.b, 0.85 * e))
			else:
				draw_rect(c, Color(CIAN.r, CIAN.g, CIAN.b, 0.08 * e))
			draw_rect(c, Color(CIAN.r, CIAN.g, CIAN.b, (1.0 if foco else 0.45) * e),
				false, 2.0 if foco else 1.0)
			var tam := 13
			var txt: String = ROTULOS[k]
			var an: float = _fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			if an > c.size.x - 6.0:
				tam = 11
				an = _fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			var tinta: Color = Color(0.02, 0.05, 0.08, e) if on else Color(APAGADO.r, APAGADO.g, APAGADO.b, e)
			if foco and not on:
				tinta = Color(HUESO.r, HUESO.g, HUESO.b, e)
			var pos := Vector2(c.position.x + (c.size.x - an) * 0.5, c.position.y + c.size.y * 0.72)
			if on:
				draw_string(_fuente, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, tinta)
			else:
				_texto(txt, pos, tam, tinta)

func _texto(s: String, pos: Vector2, tam: int, col: Color) -> void:
	draw_string_outline(_fuente, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4,
		Color(0.02, 0.03, 0.04, 0.85 * col.a))
	draw_string(_fuente, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)
