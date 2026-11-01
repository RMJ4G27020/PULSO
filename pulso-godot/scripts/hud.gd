extends Control
## El HUD entero en UN solo Control que se pinta en _draw().
##
## Por que un Control y no nodos sueltos en cada .tscn: antes habia seis nodos
## repetidos en los cinco niveles (30 en total) y cualquier retoque habia que
## hacerlo cinco veces. Ahora el .tscn del nivel solo tiene un CanvasLayer vacio.
##
## Por que sin Tweens: en un movil con GL Compatibility, crear y destruir un
## Tween por cada rombo y por cada tramo de barra es un goteo de basura por
## cuadro. Todo el estado de animacion son floats y Arrays de float que avanzan
## en _process, y se pide UN solo queue_redraw por cuadro.
##
## La idea de fondo: en PULSO la camara va clavada al personaje, asi que el ojo
## del jugador esta SIEMPRE en el centro de la pantalla y su vision periferica
## es el marco del viewport. Por eso el aviso importante (queda poca carga) no
## es un piloto en una esquina sino un CERCO en el borde, y la urgencia se
## codifica en FRECUENCIA, que se lee sin enfocar y sin distinguir colores.

# ------------------------------------------------------------------- paleta
const CIAN := Color(0.21, 0.85, 1.0)
const LIMA := Color(0.78, 0.95, 0.31)
const ROJO := Color(1.0, 0.32, 0.28)
const AMBAR := Color(1.0, 0.65, 0.2)
const TINTA := Color(0.02, 0.03, 0.04, 0.85)      ## contorno de las letras
const HUESO := Color(0.86, 0.93, 0.97)

# ------------------------------------------------------------- geometria fija
## Todo lo que no esta aqui va anclado al borde del viewport, que cambia de 640
## a 780 px en moviles 19,5:9 y 20:9.
const BARRA := Rect2(14.0, 12.0, 168.0, 14.0)
const MARCO := Rect2(12.0, 10.0, 172.0, 18.0)
const CIFRA_X := 190.0
const CIFRA_Y := 25.0                  ## linea base de los segundos restantes
const TAM_CIFRA := 15
const ROMBO_0 := Vector2(23.0, 62.0)   ## centro del primer rombo
const ROMBO_PASO := 24.0
const ROMBO_W := 16.0
const ROMBO_H := 18.0
const TAM_RELOJ := 15
const RELOJ_Y := 24.0
const RELOJ_MARGEN := 14.0
const BANDA_TEXTO := 49.0              ## linea base de titulo y estado (banda 34..52)
const TAM_TITULO := 22
const TAM_ESTADO := 15
const CHEVRON_W := 13.0
const CHEVRON_H := 22.0
const CHEVRON_MARGEN := 26.0
const LIBRE := 120.0                   ## cuadro central intocable: ahi esta el personaje

## Tope duro de parpadeo por seguridad fotosensible. Nada del HUD sube de aqui.
const HZ_TOPE := 2.6
const CERCO_DENTRO := 22.0             ## hasta donde llega el degradado hacia dentro

const TITULO_VISIBLE := 2.2
const TITULO_FUNDE := 0.8
const ESTADO_VISIBLE := 1.0
const POP := 0.28
const FANTASMA := 0.35
const SUBIDA := 0.40

# ------------------------------------------------------------------- entradas
var _tiempo := 0.0
var _par := 0.0
var _carga := 100.0
var _frag := 0
var _frag_total := 0
var _estado := ""
var _titulo := ""
var _muertes := 0
var _objetivo := Vector2.INF
var _a_la_salida := false

## consumo de carga por segundo: lo necesita el fantasma para distinguir la
## fuga (el goteo constante) de la maniobra (un impulso, un pulso)
var consumo := 1.6
## Opcion de accesibilidad: sustituye el latido por grosor y color constantes.
var cerco_fijo := false

var _jugador: Node2D
var _rejilla: RejillaEstela

# ------------------------------------------------- estado de animacion (floats)
var _t := 0.0                          ## reloj propio del HUD
var _fase := 0.0                       ## fase normalizada del latido del cerco
var _carga_previa := 100.0
var _fantasma_w := 0.0
var _fantasma_t := 0.0
var _subida_w := 0.0
var _subida_t := 0.0
var _frag_previo := 0
var _pop: Array[float] = []            ## uno por rombo
var _onda := -1.0
var _t_titulo := 0.0
var _t_estado := 0.0
var _estado_previo := ""
var _alfa_reloj := 0.55
var _par_pasado := false
var _t_quietud := 0.0
var _celda_aviso := Vector2i(-99999, -99999)
var _viaje := -1.0                     ## el chevron cruzando el borde al abrirse la puerta
var _salida_previa := false
var _chevron_previo := Vector2.ZERO

var _fuente: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fuente = ThemeDB.fallback_font
	add_to_group("hud")        # el menu de pausa le cambia "cerco fijo" en caliente
	cerco_fijo = bool(Guardado.opcion("cerco_fijo", false))
	get_viewport().size_changed.connect(queue_redraw)

## El nivel le pasa el jugador y la rejilla para el aviso de quietud. Es
## opcional: sin ellos el HUD pinta igual, solo se queda sin ese aviso.
func enlazar(jugador: Node2D, rejilla: Node2D) -> void:
	_jugador = jugador
	_rejilla = rejilla as RejillaEstela
	if _jugador and "consumo" in _jugador:
		consumo = float(_jugador.consumo)

## Una sola llamada por cuadro desde nivel.gd. El HUD deriva el resto solo.
func actualizar(tiempo: float, par: float, carga: float, frag: int, frag_total: int,
		estado: String, titulo: String, muertes: int,
		objetivo: Vector2, a_la_salida: bool = false) -> void:
	_tiempo = tiempo
	_par = par
	_carga = carga
	_frag = frag
	_frag_total = frag_total
	_estado = estado
	_titulo = titulo
	_muertes = muertes
	_objetivo = objetivo
	_a_la_salida = a_la_salida

# ------------------------------------------------------------------ funciones
## Frecuencia del latido del cerco. Crece al bajar la carga y NUNCA pasa de
## HZ_TOPE: por encima de ~3 Hz el parpadeo entra en terreno fotosensible.
func hz_cerco(carga: float) -> float:
	if carga > 40.0:
		return 0.0
	return clampf(remap(carga, 40.0, 0.0, 0.4, HZ_TOPE), 0.4, HZ_TOPE)

## Color y grosor del cerco por tramos. Devuelve [color, grosor, alfa_min, alfa_max].
func tramo_cerco(carga: float) -> Array:
	if carga > 40.0:
		return [CIAN, 2.0, 0.10, 0.10]
	if carga > 25.0:
		return [AMBAR, 3.0, 0.13, 0.28]
	if carga > 10.0:
		return [ROJO, 4.0, 0.19, 0.42]
	return [ROJO, 6.0, 0.31, 0.70]

## Latido: sube en 0,06 s y cae el resto del periodo. Es un latido, no una
## respiracion: una senoide no se lee como urgencia.
func _latido(f: float, hz: float) -> float:
	if hz <= 0.0:
		return 0.0
	var sub: float = clampf(0.06 * hz, 0.02, 0.6)
	if f < sub:
		return f / sub
	return clampf(1.0 - (f - sub) / (1.0 - sub), 0.0, 1.0)

## El cronometro se rellena con U+2007 FIGURE SPACE, no con el espacio ASCII.
## La fuente SI es tabular (los diez digitos miden lo mismo); lo que bailaba 12
## px era el relleno de "%5.1f", porque el espacio ASCII es la mitad de ancho.
func texto_cronometro(t: float, par: float) -> String:
	return ("%5.1f /%3.0f" % [t, par]).replace(" ", " ")

func texto_segundos(carga: float) -> String:
	return "%.0f s" % (maxf(carga, 0.0) / maxf(consumo, 0.001))

## El aviso de quietud NO salta sobre toma de tierra: ahi el juego te PIDE
## pararte. El mismo canal ensena las dos mitades de la regla.
func aviso_quietud(edad: float, en_tierra: bool) -> bool:
	return (not en_tierra) and edad > 0.20

func _ancho_carga(carga: float) -> float:
	return BARRA.size.x * clampf(carga, 0.0, 100.0) / 100.0

func _back(x: float) -> float:
	## TRANS_BACK / EASE_OUT a mano, para no crear un Tween por rombo
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

# --------------------------------------------------------------------- cajas
## Las mismas funciones que usa _draw() para colocar cada pieza. Las pruebas
## leen de aqui, asi que no hay dos juegos de numeros que se puedan desincronizar.
func caja_barra() -> Rect2:
	return MARCO

func caja_cifra() -> Rect2:
	var an: float = _fuente.get_string_size(texto_segundos(_carga),
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_CIFRA).x
	return Rect2(CIFRA_X, CIFRA_Y - float(TAM_CIFRA), an, float(TAM_CIFRA) + 4.0)

func caja_rombos() -> Rect2:
	## el ancho NO depende de cuantos llevas: los vacios ocupan lo mismo que los
	## llenos, asi que la fila no crece al recoger uno
	if _frag_total <= 0:
		return Rect2()
	var an: float = ROMBO_PASO * float(_frag_total - 1) + ROMBO_W
	return Rect2(ROMBO_0.x - ROMBO_W * 0.5, ROMBO_0.y - ROMBO_H * 0.5, an, ROMBO_H)

func caja_cronometro() -> Rect2:
	var s := texto_cronometro(_tiempo, _par)
	var an: float = _fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_RELOJ).x
	var r: Vector2 = get_viewport_rect().size
	return Rect2(r.x - RELOJ_MARGEN - an, RELOJ_Y - float(TAM_RELOJ), an, float(TAM_RELOJ) + 4.0)

func _caja_texto(s: String, tam: int) -> Rect2:
	if s == "":
		return Rect2()
	var r: Vector2 = get_viewport_rect().size
	var an: float = _fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return Rect2(r.x * 0.5 - an * 0.5, BANDA_TEXTO - float(tam), an, float(tam) + 5.0)

func caja_titulo() -> Rect2:
	if _t_titulo >= TITULO_VISIBLE + TITULO_FUNDE or _titulo == "":
		return Rect2()
	return _caja_texto(_titulo, TAM_TITULO)

func caja_estado() -> Rect2:
	if not _estado_visible():
		return Rect2()
	return _caja_texto(_estado, TAM_ESTADO)

func _estado_visible() -> bool:
	return _estado != "" and _t_estado < ESTADO_VISIBLE and _alfa_titulo() < 0.05

func caja_chevron() -> Rect2:
	if _objetivo == Vector2.INF:
		return Rect2()
	var c: Vector2 = _punto_chevron()
	return Rect2(c - Vector2(CHEVRON_W, CHEVRON_H) * 0.5, Vector2(CHEVRON_W, CHEVRON_H))

## Todas las cajas pintadas, para que una prueba pueda exigir que ninguna caiga
## en el cuadro central donde esta el personaje.
func cajas() -> Array[Rect2]:
	var a: Array[Rect2] = []
	for c in [caja_barra(), caja_cifra(), caja_rombos(), caja_cronometro(),
			  caja_titulo(), caja_estado(), caja_chevron()]:
		if c.size.x > 0.0 or c.size.y > 0.0:
			a.append(c)
	return a

func caja_libre() -> Rect2:
	var r: Vector2 = get_viewport_rect().size
	return Rect2(r * 0.5 - Vector2(LIBRE, LIBRE) * 0.5, Vector2(LIBRE, LIBRE))

# --------------------------------------------------------------------- ciclo
func _process(delta: float) -> void:
	_t += delta
	var hz := hz_cerco(_carga)
	_fase = fmod(_fase + delta * maxf(hz, 0.0), 1.0)

	# --- fantasma del gasto: distingue la fuga (goteo) de la maniobra
	var baja: float = _carga_previa - _carga
	if delta > 0.0 and baja > consumo * delta * 1.5:
		_fantasma_w = _ancho_carga(_carga_previa)
		_fantasma_t = FANTASMA
	elif _carga > _carga_previa + 0.0001:
		_subida_w = _ancho_carga(_carga_previa)
		_subida_t = SUBIDA
	_carga_previa = _carga
	_fantasma_t = maxf(_fantasma_t - delta, 0.0)
	_subida_t = maxf(_subida_t - delta, 0.0)

	# --- rombos
	if _pop.size() != _frag_total:
		_pop.resize(_frag_total)
		for i in _pop.size():
			_pop[i] = 0.0
	if _frag > _frag_previo:
		for i in range(_frag_previo, mini(_frag, _pop.size())):
			_pop[i] = POP
		_onda = 0.0
	elif _frag < _frag_previo:
		_onda = -1.0
	_frag_previo = _frag
	for i in _pop.size():
		_pop[i] = maxf(_pop[i] - delta, 0.0)
	if _onda >= 0.0:
		_onda += delta
		if _onda > 1.0:
			_onda = -1.0

	# --- titulo y estado
	_t_titulo += delta
	if _estado != _estado_previo:
		_estado_previo = _estado
		_t_estado = 0.0
	else:
		_t_estado += delta

	# --- cronometro: al pasarse del par se apaga UNA vez. Nada de rojo: el
	# rojo de este juego significa "te mueres", no "vas lento".
	if not _par_pasado and _par > 0.0 and _tiempo > _par:
		_par_pasado = true
	if _par_pasado:
		_alfa_reloj = maxf(_alfa_reloj - delta * 0.5, 0.30)

	# --- aviso de quietud
	_t_quietud = maxf(_t_quietud - delta, 0.0)
	if _rejilla and _jugador and _jugador.get("vivo") == true:
		var celda: Vector2i = _rejilla.celda_de(_jugador.global_position + Vector2(0, 15))
		var edad: float = _rejilla.edad_de(celda)
		if edad >= 0.0 and aviso_quietud(edad, _rejilla.en_tierra(celda)):
			if celda != _celda_aviso:
				_celda_aviso = celda
				_t_quietud = 0.15
		elif edad < 0.0:
			_celda_aviso = Vector2i(-99999, -99999)

	# --- el chevron cruza el borde cuando se abre la puerta: unica ceremonia
	if _a_la_salida != _salida_previa:
		_salida_previa = _a_la_salida
		if _a_la_salida:
			_viaje = 0.0
	if _viaje >= 0.0:
		_viaje += delta / 0.45
		if _viaje >= 1.0:
			_viaje = -1.0

	queue_redraw()

func reiniciar_animacion() -> void:
	_t_titulo = 0.0
	_par_pasado = false
	_alfa_reloj = 0.55
	_onda = -1.0
	_frag_previo = 0
	_fantasma_t = 0.0
	_subida_t = 0.0
	_t_quietud = 0.0
	_celda_aviso = Vector2i(-99999, -99999)
	for i in _pop.size():
		_pop[i] = 0.0

func _alfa_titulo() -> float:
	if _titulo == "":
		return 0.0
	if _t_titulo <= TITULO_VISIBLE:
		return 1.0
	return clampf(1.0 - (_t_titulo - TITULO_VISIBLE) / TITULO_FUNDE, 0.0, 1.0)

# --------------------------------------------------------------------- pintar
func _draw() -> void:
	var r: Vector2 = get_viewport_rect().size
	_pintar_cerco(r)
	_pintar_barra()
	_pintar_rombos()
	_pintar_cronometro(r)
	_pintar_chevron()
	_pintar_textos(r)

func _marco(r: Vector2, dentro: float, ancho: float, c: Color) -> void:
	if c.a <= 0.003 or ancho <= 0.0:
		return
	var w: float = r.x - dentro * 2.0
	draw_rect(Rect2(dentro, dentro, w, ancho), c)
	draw_rect(Rect2(dentro, r.y - dentro - ancho, w, ancho), c)
	var h: float = r.y - (dentro + ancho) * 2.0
	draw_rect(Rect2(dentro, dentro + ancho, ancho, h), c)
	draw_rect(Rect2(r.x - dentro - ancho, dentro + ancho, ancho, h), c)

## La alfa que tiene el cerco AHORA. Sirve para exigir en una prueba que con
## "cerco fijo" no cambie entre cuadros: es una opcion de accesibilidad y no
## vale con que "se llame a la funcion".
func alfa_cerco() -> float:
	var tr: Array = tramo_cerco(_carga)
	if cerco_fijo:
		# accesibilidad: sin latido. Se conservan el grosor y el color, que ya
		# dicen la urgencia sin parpadear.
		return (float(tr[2]) + float(tr[3])) * 0.5
	return lerpf(float(tr[2]), float(tr[3]), _latido(_fase, hz_cerco(_carga)))

func _pintar_cerco(r: Vector2) -> void:
	var tr: Array = tramo_cerco(_carga)
	var col: Color = tr[0]
	var grosor: float = tr[1]
	var a: float = alfa_cerco()
	_marco(r, 0.0, grosor, Color(col.r, col.g, col.b, a))
	# degradado hacia dentro solo cuando aprieta de verdad, y hasta 22 px: mas
	# adentro taparia un peligro que entre por el lateral
	if _carga <= 10.0:
		var pasos := 6
		for i in pasos:
			var d0: float = grosor + (CERCO_DENTRO - grosor) * float(i) / float(pasos)
			var d1: float = grosor + (CERCO_DENTRO - grosor) * float(i + 1) / float(pasos)
			_marco(r, d0, d1 - d0,
				Color(col.r, col.g, col.b, a * (1.0 - float(i + 1) / float(pasos))))
	# el aviso de quietud va por el MISMO canal pero fuera de esa cadencia:
	# blanco-cian, un solo latido de 0,15 s
	if _t_quietud > 0.0:
		var q: float = _t_quietud / 0.15
		_marco(r, 0.0, 3.0, Color(0.7, 0.97, 1.0, 0.55 * q))

func _pintar_barra() -> void:
	draw_rect(MARCO, Color(0.03, 0.05, 0.06, 0.78))
	var w: float = _ancho_carga(_carga)
	var col: Color = ROJO if _carga < 25.0 else CIAN
	# fantasma: el area quemada por la maniobra, retrayendose al valor nuevo
	if _fantasma_t > 0.0 and _fantasma_w > w:
		var p: float = 1.0 - _fantasma_t / FANTASMA
		var borde: float = lerpf(_fantasma_w, w, p * p * (3.0 - 2.0 * p))
		draw_rect(Rect2(BARRA.position.x + w, BARRA.position.y, maxf(borde - w, 0.0),
			BARRA.size.y), Color(ROJO.r, ROJO.g, ROJO.b, 0.55 * _fantasma_t / FANTASMA))
	draw_rect(Rect2(BARRA.position, Vector2(w, BARRA.size.y)), col)
	# lo recien ganado entra en lima y se funde a cian: se ve DONDE entro
	if _subida_t > 0.0 and w > _subida_w:
		var f: float = _subida_t / SUBIDA
		draw_rect(Rect2(BARRA.position.x + _subida_w, BARRA.position.y,
			w - _subida_w, BARRA.size.y), Color(LIMA.r, LIMA.g, LIMA.b, f))
	# la cifra de segundos: ESTE es el aviso de carga baja, no el color. Al 3%
	# antes eran 3,5 px rojos en una esquina que nadie puede mirar.
	_texto(texto_segundos(_carga), Vector2(CIFRA_X, CIFRA_Y), TAM_CIFRA, col)

func _rombo(centro: Vector2, escala: float, lleno: bool) -> void:
	## el fragmento del mundo es un rombo (Polygon2D), asi que el icono tiene
	## que ser la MISMA forma. Dibujado como poligono y no como glifo porque la
	## fuente del proyecto no tiene U+25C6 ni U+25C7: en Android es un tofu.
	var w: float = ROMBO_W * 0.5 * escala
	var h: float = ROMBO_H * 0.5 * escala
	var p := PackedVector2Array([
		centro + Vector2(0.0, -h), centro + Vector2(w, 0.0),
		centro + Vector2(0.0, h), centro + Vector2(-w, 0.0)])
	if lleno:
		draw_colored_polygon(p, LIMA)
	else:
		var cerrado := p.duplicate()
		cerrado.append(p[0])
		draw_polyline(cerrado, Color(LIMA.r, LIMA.g, LIMA.b, 0.45), 2.0)

func _pintar_rombos() -> void:
	for i in _frag_total:
		var centro := Vector2(ROMBO_0.x + ROMBO_PASO * float(i), ROMBO_0.y)
		var escala := 1.0
		if i < _pop.size() and _pop[i] > 0.0:
			escala = lerpf(1.45, 1.0, _back(1.0 - _pop[i] / POP))
		elif i >= _frag and _onda >= 0.0:
			# onda por los que faltan, escalonada: dice cuantos quedan sin texto
			var f: float = _onda - 0.04 * float(i - _frag)
			if f > 0.0 and f < 0.25:
				escala = 1.0 + 0.12 * sin(f / 0.25 * PI)
		_rombo(centro, escala, i < _frag)

func _pintar_cronometro(r: Vector2) -> void:
	var s := texto_cronometro(_tiempo, _par)
	var an: float = _fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_RELOJ).x
	_texto(s, Vector2(r.x - RELOJ_MARGEN - an, RELOJ_Y), TAM_RELOJ,
		Color(HUESO.r, HUESO.g, HUESO.b, _alfa_reloj))

func _punto_chevron() -> Vector2:
	var r: Vector2 = get_viewport_rect().size
	var p: Vector2 = get_viewport().get_canvas_transform() * _objetivo
	var c: Vector2 = r * 0.5
	var d: Vector2 = p - c
	if absf(d.x) >= absf(d.y):
		return Vector2(CHEVRON_MARGEN if d.x < 0.0 else r.x - CHEVRON_MARGEN,
			clampf(p.y, 40.0, r.y - 40.0))
	return Vector2(clampf(p.x, 40.0, r.x - 40.0),
		CHEVRON_MARGEN if d.y < 0.0 else r.y - CHEVRON_MARGEN)

func _pintar_chevron() -> void:
	# falla a invisible: en un generado raro sin objetivo, mejor nada que una
	# flecha apuntando al vacio
	if _objetivo == Vector2.INF:
		return
	var r: Vector2 = get_viewport_rect().size
	var p: Vector2 = get_viewport().get_canvas_transform() * _objetivo
	var centro: Vector2 = _punto_chevron()
	var col: Color = LIMA if _a_la_salida else CIAN
	if _viaje >= 0.0:
		# la unica ceremonia del HUD: al abrirse la puerta el chevron cruza el
		# borde de lado a lado cambiando de cian a lima
		centro = _chevron_previo.lerp(centro, _viaje)
		col = CIAN.lerp(LIMA, _viaje)
	else:
		_chevron_previo = centro
	var dist: float = (p - r * 0.5).length()
	col.a = clampf(remap(dist, 200.0, 600.0, 0.70, 0.25), 0.25, 0.70)
	var d: Vector2 = (p - r * 0.5).normalized()
	if d == Vector2.ZERO:
		d = Vector2.RIGHT
	var lado: Vector2 = d.orthogonal()
	var punta: Vector2 = centro + d * (CHEVRON_W * 0.5)
	var base: Vector2 = centro - d * (CHEVRON_W * 0.5)
	draw_line(base + lado * (CHEVRON_H * 0.5), punta, col, 3.0)
	draw_line(base - lado * (CHEVRON_H * 0.5), punta, col, 3.0)

## Contorno antes del relleno: las cuatro etiquetas eran blanco puro sin
## contorno sobre la placa base, y con la aberracion de la muerte encima no se
## leian. Asi no hace falta un theme_override en cinco ficheros.
func _texto(s: String, pos: Vector2, tam: int, col: Color) -> void:
	if s == "":
		return
	draw_string_outline(_fuente, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4,
		Color(TINTA.r, TINTA.g, TINTA.b, TINTA.a * col.a))
	draw_string(_fuente, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)

func _pintar_textos(r: Vector2) -> void:
	var a := _alfa_titulo()
	if a > 0.01:
		# deriva 6 px hacia arriba al desvanecerse: se aparta, no se apaga
		var caja := _caja_texto(_titulo, TAM_TITULO)
		_texto(_titulo, Vector2(caja.position.x, BANDA_TEXTO - 6.0 * (1.0 - a)),
			TAM_TITULO, Color(HUESO.r, HUESO.g, HUESO.b, a))
	elif _estado_visible():
		# el estado sube a la banda de arriba. Abajo (y=316..338) lo tapaban los
		# botones de saltar e impulso justo cuando hacia falta leerlo.
		var f: float = clampf((ESTADO_VISIBLE - _t_estado) / 0.25, 0.0, 1.0)
		var ce := _caja_texto(_estado, TAM_ESTADO)
		_texto(_estado, Vector2(ce.position.x, BANDA_TEXTO), TAM_ESTADO,
			Color(HUESO.r, HUESO.g, HUESO.b, 0.85 * f))
