extends Control
## Menu principal de PULSO. Sigue el boceto del GDD: logotipo de neon, panel
## de cuatro opciones, la activa recorrida por una estela, y SALIR con
## retencion de 3 s para que no se cierre por accidente con el mando.
##
## Se usa con teclado, con raton y CON EL DEDO. Hasta ahora solo leia teclado:
## en un telefono sin teclado no habia forma de pulsar JUGAR, que en un juego
## para Google Play es no poder jugar.
##  * Tocar una fila la elige (y TSL-04 la mira); levantar el dedo SOBRE ELLA la
##    activa. Si el dedo se va de la fila antes de levantarlo, no pasa nada: es
##    la forma de arrepentirse que tiene una pantalla tactil.
##  * SALIR se mantiene con el dedo igual que con la tecla: 3 s.
##  * El boton atras de Android cierra el panel abierto; en el menu, la primera
##    vez lleva a SALIR y avisa, y la segunda sale.

const OPCIONES := ["JUGAR", "OPCIONES", "CREDITOS", "SALIR"]
const PRIMERA := "res://escenas/CineIntro.tscn"   ## cinematica -> nivel 1
const RETENCION := 3.0
## Filas de 46 px: la medida que ya se midio para la pausa ("por debajo no se
## aciertan con el pulgar"). Median 25, que con teclado daba igual. Van en px y
## no en fraccion del alto: el alto logico es 360 en un movil, pero en pantallas
## mas altas que 16:9 (tablets 4:3) stretch expand lo hace CRECER, y lo que
## tiene que medir lo mismo es el blanco del pulgar, no su parte de pantalla.
const FILA_ALTO := 46.0
const FILA_HUECO := 5.0
const PANEL_MARGEN := 10.0
const ATRAS := 2.0               ## s para volver a pulsar atras y salir

## Lo que TSL-04 dice mientras te vas: "adios" en ASCII, un byte por letra. Es
## su idioma, porque vive dentro de una computadora, y ademas es lo unico que
## puede "decir" un personaje que no habla en todo el juego. La prueba de
## interfaz lo descodifica y comprueba que de verdad pone eso: un bit mal puesto
## aqui no se ve, pero la despedida diria otra cosa.
const ADIOS_BITS := ["01100001", "01100100", "01101001", "01101111", "01110011"]
const ADIOS_TEXTO := "adios"

const CIAN := Color(0.21, 0.85, 1.0)
const MAGENTA := Color(0.89, 0.29, 0.78)
const AMBAR := Color(1.0, 0.72, 0.24)
const TINTA := Color(0.92, 0.94, 0.88)
const FONDO := Color(0.031, 0.055, 0.086)

var sel := 0
var _t := 0.0
var _reten := 0.0
## "", "niveles", "controles" o "creditos". Es el UNICO estado: las pantallas
## de niveles y de controles se abren y se cierran mirando esto, asi que no
## pueden quedar abiertas con el menu creyendo que no lo estan.
var _panel := ""
var _destello := 0.0
var _prox_destello := 4.0

## La escena 3D vive en un CanvasLayer con layer = -1, no como hijo de este
## Control: un CanvasItem se dibuja ANTES que sus hijos, asi que colgada aqui
## dentro taparia todo lo que pinta _draw(). Con capa negativa queda detras por
## construccion, igual que el Fondo de los niveles.
var _mundo: Node3D
var _controles: Control
var _niveles: Control

## El dedo (o el raton) que manda: cual es (su index, o -2 el raton; -1 si no
## hay ninguno), en que fila empezo y si sigue encima de ella. Solo manda UNO:
## un segundo dedo apoyado no puede activar nada a medias. Y manda el primero
## que toca, sea cual sea su numero: en Android el index es el del sistema, y
## con el pulgar todavia en la pantalla al volver de un nivel, el que toca
## JUGAR es el 1, no el 0.
var _dedo_indice := -1
var _dedo_fila := -1
var _dedo_dentro := false
var _t_atras := 0.0
## Para las pruebas: a false, salir solo lo apunta y no cierra el juego.
var cerrar_de_verdad := true
var salio := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_medir_filas)
	_mundo = get_node_or_null("Escena3D/Marco/Vista/Mundo") as Node3D
	_controles = get_node_or_null("Controles") as Control
	if _controles != null:
		_controles.cerrado.connect(_al_cerrar_controles)
	_niveles = get_node_or_null("Niveles") as Control
	if _niveles != null:
		_niveles.cerrado.connect(_cerrar_panel)
	if _mundo != null:
		_medir_filas()
		_mundo.mirar_opcion(sel, OPCIONES.size())
	# la musica cuelga del autoload, asi que arranca aqui y sobrevive a todos
	# los change_scene_to_file: reiniciarla en cada nivel cortaria el tema justo
	# en el portal, que es donde el fundido quiere continuidad
	if Audio.has_method("poner_musica"):
		Audio.poner_musica("circuito")

func _process(delta: float) -> void:
	_t += delta
	_prox_destello -= delta
	if _prox_destello <= 0.0:
		_destello = 0.15
		_prox_destello = randf_range(4.0, 7.0)
	_destello = maxf(_destello - delta, 0.0)
	_t_atras = maxf(_t_atras - delta, 0.0)

	# La pantalla de controles manda sobre toda la entrada mientras esta
	# abierta: aqui no se sondea nada, o la tecla que el jugador esta asignando
	# (Espacio, Esc, una flecha) haria ademas lo suyo en el menu.
	_sincronizar(_controles, "controles")
	_sincronizar(_niveles, "niveles")
	if _panel == "controles" or _panel == "niveles":
		queue_redraw()
		return

	if _panel != "":
		# Creditos se cierra con Esc, Intro o la tecla de pausa, y ya no con
		# "saltar": desde que las teclas se reasignan, saltar puede ser cualquier
		# cosa, y ui_accept/ui_cancel no cambian nunca.
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept") \
				or Input.is_action_just_pressed("pausa"):
			_cerrar_panel()
		queue_redraw()
		return

	# navegacion vertical con las acciones de interfaz, que no se reasignan
	var antes := sel
	if Input.is_action_just_pressed("ui_down"):
		sel = (sel + 1) % OPCIONES.size()
	if Input.is_action_just_pressed("ui_up"):
		sel = (sel - 1 + OPCIONES.size()) % OPCIONES.size()
	# cambiar de opcion MUEVE EL MUNDO, no solo el resaltado: el paralaje entre
	# las placas cercanas y las lejanas es lo que se lee como profundidad
	if sel != antes and _mundo != null:
		_mundo.mirar_opcion(sel, OPCIONES.size())

	# SALIR se mantiene con la tecla o con el dedo encima. Si el dedo se sale de
	# la fila, se suelta: igual que levantar la tecla.
	var mantiene := Input.is_action_pressed("ui_accept") or (_dedo_fila == 3 and _dedo_dentro)
	if sel == 3 and mantiene:
		_reten += delta
		if _reten >= RETENCION:
			_salir()
	else:
		_reten = 0.0
		if Input.is_action_just_pressed("ui_accept"):
			_activar()
	# TSL-04 acompana los 3 s de retencion con su despedida: te mira, niega y se
	# encoge. Va por fuera del if para que al soltar reciba el 0 y se deshaga.
	if _mundo != null and _mundo.has_method("despedida"):
		_mundo.despedida(_reten / RETENCION)
	queue_redraw()

func _activar() -> void:
	# lo que estuviera pulsando deja de contar: si no, un clic mantenido sobre
	# SALIR mientras el teclado abre otro panel seguiria "manteniendo" SALIR
	_soltar_dedo()
	# que TSL-04 acuse el golpe: hace su reaccion de esa opcion, mas grande
	if _mundo != null and _mundo.has_method("confirmar"):
		_mundo.confirmar()
	match sel:
		0:
			# La primera vez, JUGAR es la intro y el nivel 1, como siempre: un
			# selector con un solo nivel abierto seria un paso de mas. En cuanto
			# hay algo pasado, JUGAR abre NIVELES, y la intro esta alli como
			# "Desde el principio".
			if _niveles != null and Guardado.nivel_desbloqueado(2):
				_panel = "niveles"
			else:
				get_tree().change_scene_to_file(PRIMERA)
		1: _panel = "controles"
		2: _panel = "creditos"
	# La pantalla se abre en ESTE cuadro y no en el siguiente: el menu ya ha
	# dejado de pintarse (su _draw sale si hay panel), y esperar al _process
	# siguiente dejaba un cuadro sin nada encima del 3D.
	_sincronizar(_controles, "controles")
	_sincronizar(_niveles, "niveles")

func _al_cerrar_controles() -> void:
	_cerrar_panel()

## Abre o cierra una pantalla segun _panel, para que nunca discrepen.
func _sincronizar(p: Control, nombre: String) -> void:
	if p == null:
		return
	if _panel == nombre and not p.abierto:
		p.abrir()
	elif _panel != nombre and p.abierto:
		p.cerrar()

func _cerrar_panel() -> void:
	_panel = ""
	if _mundo != null and _mundo.has_method("mirar_opcion"):
		_mundo.mirar_opcion(sel, OPCIONES.size())   # vuelve a fijarse en la fila

func _salir() -> void:
	salio = true
	if cerrar_de_verdad:
		get_tree().quit()

## TSL-04 mira a la fila elegida con dos numeros: donde cae la primera y cuanto
## baja cada una, en fracciones de media pantalla. Se le dan medidos de las
## filas de verdad, cada vez que cambia el tamano, y no copiados a mano: en una
## tablet 4:3 el alto pasa de 360 a 480 y unos numeros fijos le hacian mirar a
## otra fila.
func _medir_filas() -> void:
	if _mundo == null or not _mundo.has_method("medir_filas"):
		return
	var medio := size.y * 0.5
	if medio <= 0.0:
		return
	var a := caja_fila(0).get_center().y
	var b := caja_fila(1).get_center().y
	_mundo.medir_filas(a / medio - 1.0, (b - a) / medio)

func _soltar_dedo() -> void:
	_dedo_indice = -1
	_dedo_fila = -1
	_dedo_dentro = false

func _elegir_fila(i: int) -> void:
	if i < 0 or i == sel:
		return
	sel = i
	_reten = 0.0
	if _mundo != null:
		_mundo.mirar_opcion(sel, OPCIONES.size())

# --------------------------------------------------------------------- cajas
## La geometria, una sola vez: la usan _draw() y la entrada tactil, y la prueba
## la lee. Asi no hay dos juegos de numeros que se puedan separar.
func caja_panel() -> Rect2:
	var v := size
	var pw := v.x * 0.26
	var n := float(OPCIONES.size())
	var ph := PANEL_MARGEN * 2.0 + FILA_ALTO * n + FILA_HUECO * (n - 1.0)
	# Empieza en 0,345 del alto y no en 0,46: con filas de 46 px el panel mide
	# 219 y desde 0,46 se salia por abajo. Debajo del logotipo (que acaba hacia
	# 0,33) y por encima del borde (acaba en 343 de 360).
	return Rect2(v.x * 0.5 - pw * 0.5, v.y * 0.345, pw, ph)

func caja_fila(i: int) -> Rect2:
	var p := caja_panel()
	return Rect2(p.position.x + p.size.x * 0.08,
		p.position.y + PANEL_MARGEN + float(i) * (FILA_ALTO + FILA_HUECO),
		p.size.x * 0.84, FILA_ALTO)

## Que fila hay bajo un punto. La zona que se toca es mas ancha que la fila
## dibujada (todo el ancho del panel) y llega a la mitad del hueco entre filas:
## un pulgar que cae en el borde o entre dos filas cuenta, en vez de no hacer
## nada.
func fila_en(p: Vector2) -> int:
	var panel := caja_panel()
	for i in OPCIONES.size():
		var f := caja_fila(i)
		var zona := Rect2(panel.position.x, f.position.y - FILA_HUECO * 0.5,
			panel.size.x, f.size.y + FILA_HUECO)
		if zona.has_point(p):
			return i
	return -1

# ------------------------------------------------------------ dedo y raton
## Solo el clic izquierdo de un raton de verdad. El clic que Godot emula a
## partir de cada toque (DEVICE_ID_EMULATION) se ignora porque el toque ya
## llega por su cuenta: aceptando los dos, cada toque contaba doble, el mismo
## fallo que tenia la pausa. La rueda no cuenta.
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_pulsar(t.index, t.position)
		else:
			_levantar(t.index, t.position, t.canceled)
	elif e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT or b.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if b.pressed:
			_pulsar(-2, b.position)
		else:
			_levantar(-2, b.position, false)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _dedo_indice:
			_arrastre(d.position)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		var m := (e as InputEventMouseMotion).position
		if _dedo_indice == -2:
			_arrastre(m)
		elif _dedo_indice == -1 and _panel == "":
			# con raton, pasar por encima elige, como en cualquier menu de PC
			_elegir_fila(fila_en(m))

func _pulsar(indice: int, p: Vector2) -> void:
	# las pantallas de controles y de niveles atienden lo suyo, toques incluidos
	if _panel == "controles" or _panel == "niveles" or _dedo_indice != -1:
		return
	if _panel != "":
		# creditos: un toque en cualquier sitio vuelve
		_cerrar_panel()
		get_viewport().set_input_as_handled()
		return
	var i := fila_en(p)
	_dedo_indice = indice
	_dedo_fila = i
	_dedo_dentro = i >= 0
	_elegir_fila(i)
	if i >= 0:
		get_viewport().set_input_as_handled()

## La suelta SIEMPRE libera el dedo, haya el panel que haya: si no, una suelta
## que llegaba con un panel abierto dejaba el dedo "puesto" en SALIR y, al
## volver al menu, la retencion contaba sola hasta cerrar el juego.
func _levantar(indice: int, p: Vector2, cancelado: bool) -> void:
	if indice != _dedo_indice:
		return
	var era := _dedo_fila
	var dentro := _dedo_dentro
	_soltar_dedo()
	# Un toque CANCELADO no es levantar el dedo: Android lo manda cuando el
	# sistema se queda el toque (la palma, el boton de encendido, una llamada),
	# con la ultima posicion. Tomarlo como suelta activaba la fila que hubiera ahi.
	if cancelado or _panel != "":
		return
	var i := fila_en(p)
	# Se activa al LEVANTAR el dedo, y solo si se levanta sobre la misma fila en
	# que empezo. SALIR no: SALIR se mantiene, no se toca.
	if era >= 0 and era == i and dentro and era != 3:
		sel = era
		_activar()
	# JUGAR cambia de escena y el menu sale del arbol en el acto: ya no hay
	# viewport al que avisar
	if i >= 0 and is_inside_tree():
		get_viewport().set_input_as_handled()

func _arrastre(p: Vector2) -> void:
	_dedo_dentro = _dedo_fila >= 0 and fila_en(p) == _dedo_fila

## El boton atras de Android. Con quit_on_go_back a false (project.godot) le
## llega al juego en vez de cerrar la aplicacion de golpe.
func _notification(que: int) -> void:
	# Al perder el foco (entra una llamada, se baja la persiana) la suelta del
	# dedo puede no llegar nunca: lo que hubiera pulsado deja de contar, y SALIR
	# no puede seguir llenandose mientras el jugador esta en otra cosa.
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT or que == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_soltar_dedo()
		_reten = 0.0
		return
	if que != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _panel == "controles" and _controles != null:
		_controles.cerrar()
		return
	if _panel == "niveles" and _niveles != null:
		_niveles.cerrar()
		return
	if _panel != "":
		_cerrar_panel()
		return
	# En el menu, atras es salir, como en cualquier aplicacion de Android. Pero
	# no a la primera: SALIR existe con retencion para que no se cierre por
	# accidente, y un atras pulsado sin querer cerraria el juego igual.
	if _t_atras > 0.0:
		_salir()
		return
	_t_atras = ATRAS
	_elegir_fila(3)

func _draw() -> void:
	var v := size
	var c := v * 0.5
	# NO se pinta fondo aqui. Detras hay una escena 3D de verdad (Escena3D, en
	# un CanvasLayer con layer = -1) y este relleno opaco la tapaba entera: el
	# menu se veia exactamente igual que antes de montarla. Lo mismo con el
	# resplandor en capas que habia aqui, que era un degradado falso para
	# simular profundidad; ahora la profundidad es real y sobra.
	#
	# Queda un velo muy tenue SOLO detras del panel de opciones, porque el
	# texto tiene que leerse sobre lo que se mueva por detras.
	# Aqui no se pinta NADA de fondo. Detras hay una escena 3D de verdad
	# (Escena3D, en un CanvasLayer con layer = -1) y cualquier relleno a
	# pantalla completa la tapa entera: asi estaba, y por eso el menu se veia
	# igual que antes de montarla. El panel de opciones ya pinta su propio
	# fondo al 92%, que es lo unico que hace falta para que el texto se lea.
	# polvo lento
	for i in range(26):
		var px := fposmod(i * 97.3 + _t * (6.0 + i % 5), v.x)
		var py := fposmod(i * 53.7 + _t * 3.0, v.y)
		draw_circle(Vector2(px, py), 1.0 + (i % 3) * 0.4, Color(0.6, 0.85, 1.0, 0.10))

	# con niveles o controles abiertos no va el logotipo: sus paneles ocupan del
	# 3 al 97% del alto y lo taparian a medias
	if _panel == "controles" or _panel == "niveles":
		return

	var f := ThemeDB.fallback_font
	# ------------------------------------------------------------- logotipo
	var brillo := 1.0 if _destello <= 0.0 else 0.35
	var titulo := "PULSO"
	var tam := int(v.y * 0.17)
	var an := f.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var pos := Vector2(c.x - an * 0.5, v.y * 0.30)
	for capa in range(3):                     # halo: tres pasadas cada vez mas tenues
		var a := 0.10 * (3 - capa) * brillo
		draw_string_outline(f, pos, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
			6 + capa * 5, Color(CIAN.r, CIAN.g, CIAN.b, a))
	draw_string_outline(f, pos, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 3,
		Color(CIAN.r, CIAN.g, CIAN.b, 0.9 * brillo))
	draw_string(f, pos, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
		Color(0.85, 0.98, 1.0, brillo))

	if _panel != "":
		_dibujar_panel(v, f)
		return

	# ---------------------------------------------------------------- menu
	var panel := caja_panel()
	var pw := panel.size.x
	var ph := panel.size.y
	var p0 := panel.position
	draw_rect(Rect2(p0, Vector2(pw, ph)), Color(0.07, 0.10, 0.15, 0.92), true)
	draw_rect(Rect2(p0, Vector2(pw, ph)), MAGENTA, false, 1.0)
	var e := pw * 0.10                        # refuerzos de esquina
	for q in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(pw, 0), Vector2(-1, 1)],
			  [Vector2(0, ph), Vector2(1, -1)], [Vector2(pw, ph), Vector2(-1, -1)]]:
		var a: Vector2 = p0 + q[0]
		var d: Vector2 = q[1]
		draw_line(a, a + Vector2(e * d.x, 0), MAGENTA, 2.0)
		draw_line(a, a + Vector2(0, e * d.y), MAGENTA, 2.0)

	var tam_op := int(FILA_ALTO * 0.40)
	for i in OPCIONES.size():
		var r := caja_fila(i)
		var activo := i == sel
		if activo:
			draw_rect(r, MAGENTA, true)
			_estela_borde(r)
		else:
			draw_rect(r, MAGENTA * Color(1, 1, 1, 0.55), false, 1.0)
		var col := FONDO if activo else TINTA
		var to := f.get_string_size(OPCIONES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_op)
		draw_string(f, r.position + Vector2((r.size.x - to.x) * 0.5, r.size.y * 0.5 + tam_op * 0.36),
			OPCIONES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_op, col)
		if i == 3:
			_anillo_retencion(Vector2(r.end.x + 14.0, r.get_center().y), 10.0, f)
			if _t_atras > 0.0:
				# el aviso del boton atras, junto a SALIR, que es a donde ha llevado
				var aviso := "Atrás otra vez para salir"
				draw_string(f, Vector2(r.end.x + 32.0, r.get_center().y + 4.0), aviso,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(AMBAR.r, AMBAR.g, AMBAR.b, clampf(_t_atras / 0.3, 0.0, 1.0)))

	_dibujar_adios(v, f)

	var pie := "v1.0  -  Jose Gpe Rico Moreno"
	draw_string(f, Vector2(v.x * 0.05, v.y * 0.955), pie, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(v.y * 0.032), Color(0.45, 0.55, 0.42))

## La despedida, debajo de TSL-04, mientras se mantiene SALIR. Los bits salen
## uno a uno como si los estuviera transmitiendo, el ultimo parpadea porque es
## el que se esta escribiendo, y en cuanto un byte se completa aparece debajo la
## letra que dice: asi se lee aunque no sepas binario. Los unos van encendidos y
## los ceros apagados, que es la misma idea que las celdas de carga del HUD.
##
## Termina de escribirse al 92% de la retencion, no al 100%: si acabara justo al
## cerrarse el juego, nadie llegaria a leer la ultima letra.
func _dibujar_adios(v: Vector2, f: Font) -> void:
	var t: float = clampf(_reten / RETENCION, 0.0, 1.0)
	if t <= 0.0:
		return
	var total: int = ADIOS_BITS.size() * 8
	var vistos: int = int(ceil(float(total) * clampf(t / 0.92, 0.0, 1.0)))
	var tam: int = int(v.y * 0.021)
	var paso: float = f.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var an_byte: float = paso * 8.0
	var hueco: float = paso * 0.95
	var ancho: float = ADIOS_BITS.size() * an_byte + (ADIOS_BITS.size() - 1) * hueco
	# Centrado bajo el personaje, en la mitad izquierda. El sitio esta apretado
	# entre el panel de opciones (que empieza en 0,37 de ancho) y el pie de la
	# version (0,955 de alto): por eso va estrecho, a 0,20 y no a 0,225, y por
	# eso las letras caben encima del pie y no debajo.
	var x0: float = v.x * 0.20 - ancho * 0.5
	var y0: float = v.y * 0.80
	var entra: float = clampf(t * 6.0, 0.0, 1.0)      # no aparece de golpe
	var n := 0
	for b in ADIOS_BITS.size():
		var bx: float = x0 + float(b) * (an_byte + hueco)
		var cad: String = ADIOS_BITS[b]
		for i in 8:
			if n < vistos:
				var uno: bool = cad[i] == "1"
				var a: float = entra
				if n == vistos - 1:
					a *= 0.35 + 0.65 * absf(sin(_t * 12.0))   # el que se escribe
				var col := Color(CIAN.r, CIAN.g, CIAN.b, a) if uno \
					else Color(0.34, 0.52, 0.60, a * 0.75)
				var ch: String = cad[i]
				var w: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
				draw_string(f, Vector2(bx + float(i) * paso + (paso - w) * 0.5, y0),
					ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)
			n += 1
		if vistos >= (b + 1) * 8:
			var letra: String = ADIOS_TEXTO[b]
			var tl: int = int(v.y * 0.045)
			var wl: float = f.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tl).x
			draw_string(f, Vector2(bx + (an_byte - wl) * 0.5, y0 + v.y * 0.052),
				letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tl, Color(TINTA.r, TINTA.g, TINTA.b, entra))


func _estela_borde(r: Rect2) -> void:
	## una estela recorre el borde de la opcion activa: mismo lenguaje que el juego
	var per := 2.0 * (r.size.x + r.size.y)
	var largo := per * 0.22
	var d := fposmod(_t * per * 0.85, per)
	var pasos := 22
	for i in pasos:
		var t := d + largo * (float(i) / pasos)
		var p := _punto_borde(r, fposmod(t, per))
		var a := 0.85 * (1.0 - float(i) / pasos)
		draw_circle(p, 1.6, Color(1, 1, 1, a))

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

func _anillo_retencion(centro: Vector2, radio: float, f: Font) -> void:
	var frac := clampf(_reten / RETENCION, 0.0, 1.0)
	draw_arc(centro, radio, 0, TAU, 24, Color(AMBAR.r, AMBAR.g, AMBAR.b, 0.30), 1.5)
	if frac > 0.0:
		draw_arc(centro, radio, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, AMBAR, 2.0)
	draw_string(f, centro + Vector2(-radio * 0.55, radio * 0.42), "3s",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(radio * 0.9), AMBAR)

func _dibujar_panel(v: Vector2, f: Font) -> void:
	# Solo creditos: los controles tienen su propia pantalla (scripts/controles.gd).
	# La lista de teclas que habia aqui era texto fijo y ademas se salia por
	# abajo: su ultima linea caia en y = 389 de 360.
	var volver := "Toca para volver" if DisplayServer.is_touchscreen_available() else "Esc para volver"
	var lineas: Array[String] = ["PULSO", "", "Diseno, arte y codigo",
		"Jose Gpe Rico Moreno", "", "Godot Engine  -  Blender", "", volver]
	var tam := int(v.y * 0.045)
	var y := v.y * 0.50
	for l in lineas:
		var an := f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(f, Vector2(v.x * 0.5 - an * 0.5, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)
		y += tam * 1.45
