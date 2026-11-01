extends Control
## La pantalla CONTROLES del menu principal: ver las teclas y cambiarlas.
##
## Vive dentro de MenuPrincipal y se pinta entera en _draw(), como el menu, la
## pausa y el HUD. El panel va a la DERECHA, de 0,33 a 0,97 del ancho: TSL-04
## esta en el hueco de la izquierda y sigue viendose detras.
##
## Toda la logica de que tecla va donde esta en scripts/teclas.gd. Aqui solo se
## decide que se ve y como se pide: esta pantalla no puede dejar el mapa mal
## porque no lo toca nunca directamente.
##
## Reglas que salieron de lo que podia ir mal:
##  * La tecla que se pulsa para asignar se TRAGA: no puede ademas mover el
##    foco, cerrar la pantalla ni volver a empezar la escucha. Por eso la escucha
##    va en _input (el evento llega antes que el sondeo de _process) y el cuadro
##    en que se captura no se navega (_tragar).
##  * La escucha nunca se queda colgada: Esc la cancela, un toque o un clic la
##    cancelan, y a los 5 s se cancela sola sin cambiar nada.
##  * Ningun parpadeo pasa de 2 Hz (el tope del HUD es 2,6 por seguridad
##    fotosensible).

signal cerrado

const CIAN := Color(0.21, 0.85, 1.0)
const MAGENTA := Color(0.89, 0.29, 0.78)
const AMBAR := Color(1.0, 0.72, 0.24)
const ROJO := Color(1.0, 0.32, 0.28)
const LIMA := Color(0.78, 0.95, 0.31)
const HUESO := Color(0.86, 0.93, 0.97)
const APAGADO := Color(0.62, 0.68, 0.72)
const RELLENO := Color(0.07, 0.10, 0.15, 0.92)     ## el del panel del menu

const TAM_TITULO := 15
const TAM_ROTULO := 15
const TAM_TECLA := 13
const TAM_TECLA_MIN := 11
const TAM_PIE := 11

## Filas: las 7 acciones que se cambian, la pausa (que se ve pero no se toca) y
## Restaurar. La pausa no recibe el foco: navegar hasta ella y no poder hacer
## nada seria una fila trampa.
const FILA_PAUSA := 7
const FILA_RESTAURAR := 8

const ESCUCHA := 5.0           ## s maximos esperando una tecla
const CONFIRMA := 2.0          ## s que dura "pulsa otra vez" en Restaurar
const AVISO := 2.5             ## s que se queda un aviso en el pie
const MARCA := 2.0             ## s de la barra ambar en la fila que perdio una tecla
const DESTELLO := 0.40         ## s del destello lima de la tecla recien puesta
const RECHAZO := 0.25          ## s del contorno rojo y la sacudida

var abierto := false
var fila := 0
var hueco := 0
var escuchando := false
var aviso := ""                ## lo ultimo que se le dijo al jugador
var tipo_aviso := ""           ## "bien", "ambar" o "rojo"

var _t := 0.0
var _t_abrir := 0.0
var _t_escucha := 0.0
var _t_confirma := 0.0
var _t_aviso := 0.0
var _t_marca := 0.0
var _marca := ""               ## accion que perdio o cambio una tecla
var _t_rechazo := 0.0
var _destellos: Dictionary = {}       ## "accion:hueco" -> s que le quedan
## El cuadro en que entro una tecla por _input no se navega en _process. Sin
## esto, asignar la flecha abajo movia ademas el foco una fila, y el Esc que
## cancela la escucha cerraba tambien la pantalla.
var _tragar := false
var _fuente: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fuente = ThemeDB.fallback_font
	visible = false
	Teclas.cambiadas.connect(queue_redraw)


func abrir() -> void:
	if abierto:
		return
	abierto = true
	visible = true
	fila = 0
	hueco = 0
	escuchando = false
	_t_abrir = 0.0
	_t_confirma = 0.0
	_t_aviso = 0.0
	aviso = ""
	# el Intro que abre la pantalla no puede ademas empezar una escucha
	_tragar = true
	queue_redraw()


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	escuchando = false
	cerrado.emit()


# -------------------------------------------------------------------- cajas
## Las mismas funciones dibujan y las lee la prueba: no hay dos juegos de
## numeros. Todo en fracciones del viewport, que pasa de 640 a 780 de ancho en
## moviles 19,5:9 y 20:9; el alto es siempre 360.
func _v() -> Vector2:
	return get_viewport_rect().size


func caja_panel() -> Rect2:
	var v := _v()
	return Rect2(v.x * 0.33, v.y * 0.03, v.x * 0.64, v.y * 0.94)


func caja_fila(i: int) -> Rect2:
	var v := _v()
	var p := caja_panel()
	return Rect2(p.position.x + v.x * 0.0125, p.position.y + v.y * 0.075 + float(i) * v.y * 0.0833,
		v.x * 0.615, v.y * 0.075)


## Las ranuras van pegadas a la derecha de la fila; la columna de la izquierda
## es para el nombre de la accion.
func caja_ranura(i: int, k: int) -> Rect2:
	var v := _v()
	var f := caja_fila(i)
	var an := v.x * 0.10
	var hu := v.x * 0.00625
	var x := f.end.x - v.x * 0.0125 - float(Teclas.MAX - k) * an - float(Teclas.MAX - 1 - k) * hu
	return Rect2(x, f.position.y + 3.0, an, f.size.y - 6.0)


func caja_restaurar() -> Rect2:
	var v := _v()
	var ult := caja_fila(FILA_PAUSA)
	return Rect2(ult.position.x, ult.end.y + v.y * 0.033, ult.size.x, ult.size.y)


## La linea del pie: ayuda de teclas, o el aviso de lo que acaba de pasar.
func caja_pie() -> Rect2:
	var v := _v()
	var p := caja_panel()
	var x := p.position.x + v.x * 0.025
	return Rect2(x, p.end.y - 20.0, p.end.x - v.x * 0.025 - x, 16.0)


func accion_de(i: int) -> String:
	if i >= 0 and i < Teclas.ACCIONES.size():
		return Teclas.ACCIONES[i]
	if i == FILA_PAUSA:
		return "pausa"
	return ""


# -------------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if not abierto:
		return
	if escuchando:
		_escuchar(e)
		return
	var tecla := e as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		var c := Teclas.codigo(tecla)
		# Supr en PC, Retroceso en Mac (alli la tecla "delete" es Retroceso)
		if c == KEY_DELETE or c == KEY_BACKSPACE:
			_quitar()
			_tragado()
		return
	var p := _punto(e)
	if p != Vector2.INF:
		_tocar(p)
		_tragado()


func _escuchar(e: InputEvent) -> void:
	# Durante la escucha se traga toda tecla, tambien sueltas y ecos: la suelta
	# del Intro que la empezo llega despues, y no puede contar como tecla. Lo que
	# NO marca el cuadro es mover el raton: la cuenta atras de 5 s se pararia
	# mientras la mano esta en el raton, y la escucha dejaria de acabar sola.
	if e is InputEventKey:
		get_viewport().set_input_as_handled()
	if _punto(e) != Vector2.INF:
		_tragado()
		_cancelar_escucha("Cancelado")
		return
	var tecla := e as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	_tragado()
	if tecla.keycode == KEY_ESCAPE or tecla.physical_keycode == KEY_ESCAPE:
		_cancelar_escucha("Cancelado")
		return
	# Por posicion fisica: si el jugador cambia la distribucion del teclado, la
	# tecla sigue en el mismo sitio de la mano. Algunos teclados virtuales y
	# escritorios remotos no la mandan (vale 0), y esas no se aceptan.
	var cod := int(tecla.physical_keycode)
	escuchando = false
	var a := accion_de(fila)
	var r: Array = Teclas.asignar(a, hueco, cod)
	if bool(r[0]):
		_destellos["%s:%d" % [a, hueco]] = DESTELLO
		var otra: String = r[2]
		if otra != "":
			_marca = otra
			_t_marca = MARCA
			_avisar(String(r[1]), "ambar")
		else:
			_avisar("%s: %s" % [Teclas.CORTOS[a], Teclas.nombre_codigo(cod)], "bien")
	else:
		_rechazar(String(r[1]) if String(r[1]) != "" else "Esa tecla no se puede asignar")


func _tragado() -> void:
	_tragar = true
	get_viewport().set_input_as_handled()


func _punto(e: InputEvent) -> Vector2:
	if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		return (e as InputEventScreenTouch).position
	if e is InputEventMouseButton and _es_clic(e as InputEventMouseButton):
		return (e as InputEventMouseButton).position
	return Vector2.INF


## Solo el clic izquierdo de un raton DE VERDAD. Un dedo en la pantalla llega
## dos veces: el clic que Godot emula a partir del toque (emulate_mouse_from_touch
## vale true de fabrica) y despues el propio toque. Aceptando los dos, un solo
## toque en una fila que pide confirmar la confirmaba en el acto, y un
## interruptor se encendia y se apagaba a la vez. El emulado se ignora y vale el
## toque. Y la rueda tambien llega como "boton pulsado": dos muescas confirmaban.
## (La misma regla que en scripts/pausa.gd.)
func _es_clic(b: InputEventMouseButton) -> bool:
	return b.pressed and b.button_index == MOUSE_BUTTON_LEFT \
		and b.device != InputEvent.DEVICE_ID_EMULATION


## Con raton o dedo: tocar una tecla la elige y se pone a escuchar; tocar fuera
## del panel es volver. No hace falta en un movil (sin teclado no hay nada que
## asignar), pero en un portatil con pantalla tactil o con raton se espera.
func _tocar(p: Vector2) -> void:
	if not caja_panel().has_point(p):
		cerrar()
		return
	for i in Teclas.ACCIONES.size():
		for k in Teclas.MAX:
			if caja_ranura(i, k).grow(2.0).has_point(p) and k <= Teclas.de(accion_de(i)).size():
				fila = i
				hueco = k
				_empezar_escucha()
				return
		if caja_fila(i).has_point(p):
			fila = i
			hueco = mini(hueco, _huecos_navegables(i) - 1)
			return
	if caja_restaurar().has_point(p):
		fila = FILA_RESTAURAR
		_elegir_restaurar()


func _process(d: float) -> void:
	_t += d
	_t_abrir += d
	_t_aviso = maxf(_t_aviso - d, 0.0)
	_t_marca = maxf(_t_marca - d, 0.0)
	_t_rechazo = maxf(_t_rechazo - d, 0.0)
	_t_confirma = maxf(_t_confirma - d, 0.0)
	for c in _destellos.keys():
		_destellos[c] = float(_destellos[c]) - d
		if float(_destellos[c]) <= 0.0:
			_destellos.erase(c)
	if not abierto:
		return
	queue_redraw()
	if _tragar:
		_tragar = false
		return
	if escuchando:
		_t_escucha -= d
		if _t_escucha <= 0.0:
			_cancelar_escucha("Sin cambios: no llego ninguna tecla")
		return

	if Input.is_action_just_pressed("ui_cancel"):
		cerrar()
		return
	if Input.is_action_just_pressed("ui_down"):
		_mover_fila(1)
	elif Input.is_action_just_pressed("ui_up"):
		_mover_fila(-1)
	elif Input.is_action_just_pressed("ui_right"):
		hueco = mini(hueco + 1, _huecos_navegables(fila) - 1)
	elif Input.is_action_just_pressed("ui_left"):
		hueco = maxi(hueco - 1, 0)
	elif Input.is_action_just_pressed("ui_accept"):
		if fila == FILA_RESTAURAR:
			_elegir_restaurar()
		else:
			_empezar_escucha()


## Las teclas que tiene mas el hueco vacio para anadir, sin pasar de 3.
func _huecos_navegables(i: int) -> int:
	if i == FILA_RESTAURAR:
		return 1
	return mini(Teclas.de(accion_de(i)).size() + 1, Teclas.MAX)


## Arriba y abajo dan la vuelta por las 7 acciones y Restaurar, saltandose la
## pausa. El hueco enfocado se conserva si la fila nueva lo tiene.
func _mover_fila(paso: int) -> void:
	var orden: Array[int] = []
	for i in Teclas.ACCIONES.size():
		orden.append(i)
	orden.append(FILA_RESTAURAR)
	var pos := maxi(orden.find(fila), 0)
	fila = orden[(pos + paso + orden.size()) % orden.size()]
	hueco = mini(hueco, _huecos_navegables(fila) - 1)
	_t_confirma = 0.0


func _empezar_escucha() -> void:
	if fila < 0 or fila >= Teclas.ACCIONES.size():
		return
	escuchando = true
	_t_escucha = ESCUCHA
	_t_aviso = 0.0


func _cancelar_escucha(texto: String) -> void:
	escuchando = false
	_avisar(texto, "")


func _quitar() -> void:
	if fila >= Teclas.ACCIONES.size():
		return
	var r: Array = Teclas.quitar(accion_de(fila), hueco)
	if bool(r[0]):
		hueco = mini(hueco, _huecos_navegables(fila) - 1)
		_avisar(String(r[1]), "bien")
	elif String(r[1]) != "":
		_rechazar(String(r[1]))


## Dos pulsaciones, como las filas que borran en la pausa: restaurar deshace
## todo lo que el jugador haya configurado y no tiene vuelta atras.
func _elegir_restaurar() -> void:
	if Teclas.es_de_fabrica():
		_avisar("Ya esta todo de fabrica", "")
		return
	if _t_confirma <= 0.0:
		_t_confirma = CONFIRMA
		return
	_t_confirma = 0.0
	Teclas.restaurar()
	hueco = 0
	_avisar("Teclas de fabrica restauradas", "bien")


func _avisar(texto: String, tipo: String) -> void:
	aviso = texto
	tipo_aviso = tipo
	_t_aviso = AVISO if texto != "" else 0.0


func _rechazar(texto: String) -> void:
	_t_rechazo = RECHAZO
	_avisar(texto, "rojo")


# ------------------------------------------------------------------- pintar
func _draw() -> void:
	if not abierto:
		return
	var v := _v()
	var p := caja_panel()
	draw_rect(p, RELLENO, true)
	draw_rect(p, MAGENTA, false, 1.0)
	var e := v.x * 0.026                           # refuerzos de esquina del menu
	for q in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(p.size.x, 0), Vector2(-1, 1)],
			[Vector2(0, p.size.y), Vector2(1, -1)], [Vector2(p.size.x, p.size.y), Vector2(-1, -1)]]:
		var a: Vector2 = p.position + q[0]
		var dd: Vector2 = q[1]
		draw_line(a, a + Vector2(e * dd.x, 0), MAGENTA, 2.0)
		draw_line(a, a + Vector2(0, e * dd.y), MAGENTA, 2.0)

	# cabecera: titulo a la izquierda, y a la derecha donde esta lo demas
	var x0 := p.position.x + v.x * 0.025
	var base := v.y * 0.08
	_texto("> CONTROLES", Vector2(x0, base), TAM_TITULO, Color(CIAN, 0.85))
	var nota := "Volumen y accesibilidad: en la pausa"
	var an_nota := _ancho(nota, TAM_PIE)
	_texto(nota, Vector2(p.end.x - v.x * 0.025 - an_nota, base), TAM_PIE, Color(APAGADO, 0.8))
	var y_filete := v.y * 0.094
	draw_line(Vector2(x0, y_filete), Vector2(p.end.x - v.x * 0.025, y_filete),
		Color(MAGENTA, 0.55), 1.0)

	for i in Teclas.ACCIONES.size() + 1:
		_dibujar_fila(i)
	_dibujar_restaurar()
	_dibujar_pie()


## Las filas entran escalonadas: 0,04 s entre una y otra, 0,12 s cada una,
## subiendo 10 px. Es la misma entrada que la de la pausa.
func _entrada(i: int) -> float:
	return clampf((_t_abrir - 0.04 * float(i)) / 0.12, 0.0, 1.0)


func _dibujar_fila(i: int) -> void:
	var f := caja_fila(i)
	var ent := _entrada(i)
	f.position.y += (1.0 - ent) * 10.0
	var a := ent * (0.55 if i == FILA_PAUSA else 1.0)
	var foco := i == fila and i != FILA_PAUSA
	var accion := accion_de(i)

	if foco:
		draw_rect(f, Color(MAGENTA, 0.16 * a), true)
		draw_rect(f, Color(MAGENTA, a), false, 2.0)
	else:
		draw_rect(f, Color(CIAN, 0.06 * a), true)
	if accion == _marca and _t_marca > 0.0:
		draw_rect(Rect2(f.position, Vector2(3.0, f.size.y)), Color(AMBAR, a * _t_marca / MARCA), true)

	var col := HUESO if foco else APAGADO
	_texto(Teclas.ROTULOS[accion], Vector2(f.position.x + _v().x * 0.025, f.position.y + f.size.y * 0.68),
		TAM_ROTULO, Color(col, a))

	var teclas := Teclas.de(accion)
	for k in Teclas.MAX:
		var r := caja_ranura(i, k)
		r.position.y += (1.0 - ent) * 10.0
		var enfocada := foco and k == hueco
		if enfocada and _t_rechazo > 0.0:
			# sacudida amortiguada: dice "no" sin tapar nada con un dialogo
			r.position.x += sin(_t * 60.0) * 3.0 * (_t_rechazo / RECHAZO)
		if i == FILA_PAUSA:
			if k == 0 and teclas.size() > 0:
				_ranura_tecla(r, Teclas.codigo(teclas[0]), false, a, false)
			elif k == 1:
				_texto_centrado("fija", r, TAM_TECLA_MIN, Color(APAGADO, a))
			continue
		if enfocada and escuchando:
			_ranura_escucha(r, a)
		elif k < teclas.size():
			_ranura_tecla(r, Teclas.codigo(teclas[k]), enfocada, a, Teclas.hueco_cambiado(accion, k))
			var clave := "%s:%d" % [accion, k]
			if _destellos.has(clave):
				draw_rect(r, Color(LIMA, float(_destellos[clave]) / DESTELLO * a), false, 2.0)
		elif k == teclas.size():
			# el hueco para anadir una tecla mas
			draw_rect(r, Color(CIAN, (0.45 if enfocada else 0.18) * a), false, 2.0 if enfocada else 1.0)
			if enfocada:
				_texto_centrado("+", r, TAM_TECLA, Color(HUESO, a))
				_estela_borde(r, a)
		else:
			draw_rect(r, Color(CIAN, 0.08 * a), false, 1.0)
		if enfocada and _t_rechazo > 0.0:
			draw_rect(r.grow(1.0), Color(ROJO, _t_rechazo / RECHAZO * a), false, 2.0)


func _ranura_tecla(r: Rect2, cod: int, enfocada: bool, a: float, cambiada: bool) -> void:
	draw_rect(r, Color(CIAN, (0.16 if enfocada else 0.08) * a), true)
	draw_rect(r, Color(CIAN, (1.0 if enfocada else 0.45) * a), false, 2.0 if enfocada else 1.0)
	if Teclas.es_flecha(cod):
		_flecha(r.get_center(), cod, Color(HUESO, a))
	else:
		_texto_centrado(Teclas.nombre_codigo(cod), r, TAM_TECLA, Color(HUESO, a))
	if cambiada:
		# un cuadradito lima: esta no es la de fabrica
		draw_rect(Rect2(r.end.x - 5.0, r.position.y + 2.0, 3.0, 3.0), Color(LIMA, a), true)
	if enfocada:
		_estela_borde(r, a)


## Esperando tecla: un guion que parpadea a 2 Hz y una barra que se gasta en
## los 5 s que quedan. La barra es lo que dice que esto acaba solo.
func _ranura_escucha(r: Rect2, a: float) -> void:
	draw_rect(r, Color(CIAN, 0.22 * a), true)
	draw_rect(r, Color(CIAN, a), false, 2.0)
	var parpadeo := 0.35 + 0.65 * absf(sin(_t * TAU))
	_texto_centrado("_", r, TAM_TECLA, Color(HUESO, a * parpadeo))
	var resto := clampf(_t_escucha / ESCUCHA, 0.0, 1.0)
	draw_rect(Rect2(r.position.x, r.end.y + 1.0, r.size.x * resto, 2.0), Color(CIAN, a), true)


## Las flechas se DIBUJAN: la fuente del juego no tiene U+2190-2193, y en
## Android saldria un cuadrado (la misma trampa que obligo a dibujar los rombos
## del HUD).
func _flecha(c: Vector2, cod: int, col: Color) -> void:
	var dir := Vector2.LEFT
	match cod:
		KEY_RIGHT: dir = Vector2.RIGHT
		KEY_UP: dir = Vector2.UP
		KEY_DOWN: dir = Vector2.DOWN
	var lado := Vector2(-dir.y, dir.x)
	var punta := c + dir * 3.5
	var atras := c - dir * 3.5
	draw_line(atras + lado * 4.5, punta, col, 2.0)
	draw_line(atras - lado * 4.5, punta, col, 2.0)


func _dibujar_restaurar() -> void:
	var r := caja_restaurar()
	var ent := _entrada(FILA_RESTAURAR)
	r.position.y += (1.0 - ent) * 10.0
	var n := Teclas.cambios()
	var a := ent * (1.0 if n > 0 else 0.55)
	var foco := fila == FILA_RESTAURAR
	var confirmando := _t_confirma > 0.0
	if foco:
		draw_rect(r, Color(MAGENTA, 0.16 * a), true)
		draw_rect(r, Color(ROJO if confirmando else MAGENTA, a), false, 2.0)
		_estela_borde(r, a)
	else:
		draw_rect(r, Color(CIAN, 0.06 * a), true)
	draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(ROJO, (1.0 if confirmando else 0.55) * a), true)
	var txt := "Pulsa otra vez para confirmar" if confirmando else "Restaurar teclas de fábrica"
	var col := ROJO if confirmando else (HUESO if foco else APAGADO)
	_texto(txt, Vector2(r.position.x + _v().x * 0.025, r.position.y + r.size.y * 0.68), TAM_ROTULO, Color(col, a))
	var cuenta := "todo de fábrica" if n == 0 else ("1 cambio" if n == 1 else "%d cambios" % n)
	var an := _ancho(cuenta, TAM_PIE)
	_texto(cuenta, Vector2(r.end.x - 16.0 - an, r.position.y + r.size.y * 0.66), TAM_PIE, Color(APAGADO, a))


## El pie dice lo que acaba de pasar, y si no ha pasado nada, que teclas sirven
## aqui. Las teclas van en un recuadro, que es como se lee "esto es una tecla".
func _dibujar_pie() -> void:
	var r := caja_pie()
	var y := r.position.y + 12.0
	if _t_aviso > 0.0 and aviso != "":
		var col := HUESO
		match tipo_aviso:
			"bien": col = LIMA
			"ambar": col = AMBAR
			"rojo": col = ROJO
		_texto(aviso, Vector2(r.position.x, y), TAM_PIE, Color(col, clampf(_t_aviso / 0.3, 0.0, 1.0)))
		return
	_pie_partes(r, partes_pie(escuchando, fila == FILA_RESTAURAR,
		DisplayServer.is_touchscreen_available()))


## Lo que dice el pie cuando no hay aviso. Con pantalla tactil se anade que
## tocar fuera vuelve: funcionaba, pero no lo decia nada, y en un telefono es
## la unica salida que hay (no hay Esc). La prueba mide que todas caben.
func partes_pie(escucha: bool, en_restaurar: bool, tactil: bool) -> Array:
	var partes: Array = []
	if escucha:
		partes = [["", "Pulsa una tecla para %s" % Teclas.CORTOS[accion_de(fila)]],
			["Esc", "cancelar"]]
	elif en_restaurar:
		partes = [["Intro", "restaurar"], ["Esc", "volver"]]
	else:
		partes = [["Intro", "cambiar"], ["Supr", "quitar"], ["Esc", "volver"]]
	if tactil and not escucha:
		partes.append(["", "o toca fuera"])
	return partes


## Lo que ocupa una linea de pie, con los recuadros de las teclas.
func ancho_partes(partes: Array) -> float:
	var x := 0.0
	for par in partes:
		if String(par[0]) != "":
			x += _ancho(String(par[0]), TAM_PIE) + 8.0 + 5.0
		x += _ancho(String(par[1]), TAM_PIE) + 16.0
	return x - 16.0


func _pie_partes(r: Rect2, partes: Array) -> void:
	var x := r.position.x
	var y := r.position.y + 12.0
	for par in partes:
		var tecla: String = par[0]
		var texto: String = par[1]
		if tecla != "":
			var an := _ancho(tecla, TAM_PIE) + 8.0
			draw_rect(Rect2(x, y - 11.0, an, 14.0), Color(APAGADO, 0.6), false, 1.0)
			_texto(tecla, Vector2(x + 4.0, y), TAM_PIE, HUESO)
			x += an + 5.0
		_texto(texto, Vector2(x, y), TAM_PIE, APAGADO)
		x += _ancho(texto, TAM_PIE) + 16.0


# ---------------------------------------------------------------- utilidades
func _ancho(t: String, tam: int) -> float:
	return _fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


func _texto(t: String, pos: Vector2, tam: int, col: Color) -> void:
	draw_string(_fuente, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)


## Centrado en la caja; si no cabe a 13 px baja a 11, y si aun no cabe se corta
## con "..." en vez de salirse de la ranura.
func _texto_centrado(t: String, r: Rect2, tam: int, col: Color) -> void:
	var tm := tam
	if _ancho(t, tm) > r.size.x - 6.0:
		tm = TAM_TECLA_MIN
	var s := t
	while _ancho(s, tm) > r.size.x - 6.0 and s.length() > 2:
		s = s.substr(0, s.length() - 2) + "."
	var an := _ancho(s, tm)
	draw_string(_fuente, Vector2(r.get_center().x - an * 0.5, r.position.y + r.size.y * 0.72),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, tm, col)


## La estela que recorre el borde de lo enfocado: el mismo gesto que la opcion
## activa del menu principal y que la estela del juego.
func _estela_borde(r: Rect2, a: float) -> void:
	var per := 2.0 * (r.size.x + r.size.y)
	var largo := per * 0.22
	var d := fposmod(_t * per * 0.85, per)
	var pasos := 16
	for i in pasos:
		var t := d + largo * (float(i) / pasos)
		draw_circle(_punto_borde(r, fposmod(t, per)), 1.3,
			Color(1, 1, 1, 0.85 * (1.0 - float(i) / pasos) * a))


func _punto_borde(r: Rect2, d: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	if d < w: return r.position + Vector2(d, 0)
	d -= w
	if d < h: return r.position + Vector2(w, d)
	d -= h
	if d < w: return r.position + Vector2(w - d, h)
	d -= w
	return r.position + Vector2(0, h - d)
