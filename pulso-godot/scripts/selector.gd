extends Control
## La pantalla NIVELES del menu principal: elegir nivel con lo que ya se ha
## ganado a la vista.
##
## El progreso se guardaba desde el principio (nivel maximo, mejor tiempo y
## fragmentos de cada nivel) y ninguna pantalla lo ensenaba: JUGAR empezaba
## SIEMPRE por la intro y el nivel 1, asi que quien ya habia llegado a la
## chimenea tenia que volver a pasar tres niveles para verla. Esta pantalla es
## donde ese progreso por fin sirve para algo.
##
## La primera vez no sale: sin progreso, JUGAR sigue llevando a la intro (lo
## decide menu.gd). Un selector con un solo nivel abierto es un paso de mas.
##
## Se pinta entera en _draw(), como el menu, CONTROLES y la pausa, y se maneja
## igual que el menu: teclado, raton y dedo, con las mismas reglas (un solo dedo
## manda, se activa al LEVANTAR sobre la misma tarjeta, el clic que Godot emula
## de cada toque se ignora y la rueda no hace nada).

signal cerrado

const CIAN := Color(0.21, 0.85, 1.0)
const MAGENTA := Color(0.89, 0.29, 0.78)
const ROJO := Color(1.0, 0.32, 0.28)
const LIMA := Color(0.78, 0.95, 0.31)
const HUESO := Color(0.86, 0.93, 0.97)
const APAGADO := Color(0.62, 0.68, 0.72)
const RELLENO := Color(0.07, 0.10, 0.15, 0.92)     ## el del panel del menu

const INTRO := "res://escenas/CineIntro.tscn"
const FINAL := "res://escenas/CineFinal.tscn"
## Los niveles hechos a mano: escena, nombre y par. El nombre y el par estan
## tambien en cada .tscn (titulo, par) y en nivel.gd (ORDEN); se copian aqui
## para no cargar seis niveles enteros solo para leer dos campos, y
## prueba/selector comprueba que siguen casando con las escenas. El cuarto campo
## son los TRAMOS de carga: uno mas que las balizas del nivel (los grandes se
## hacen por tramos, y entre una baliza y la siguiente la carga empieza a tope).
const NIVELES: Array = [
	["res://escenas/niveles/n1_ida_y_vuelta.tscn", "Ida y vuelta", 40.0, 1],
	["res://escenas/niveles/n2_el_corredor.tscn", "El corredor", 52.0, 1],
	["res://escenas/niveles/n3_el_nudo.tscn", "El nudo", 66.0, 1],
	["res://escenas/niveles/n4_la_chimenea.tscn", "La chimenea", 58.0, 1],
	["res://escenas/niveles/n5_lasermania.tscn", "Lasermania", 110.0, 6],
	["res://escenas/niveles/n6_runthedrun.tscn", "Runthedrun", 75.0, 5],
]
const FRAGMENTOS := 3          ## cada nivel a mano tiene tres
## Lo que se puede enfocar, en orden: las 6 tarjetas, los dos botones de
## historia y Volver. DESDE_PRINCIPIO es NIVELES.size() (prueba/selector lo
## comprueba: no se puede escribir como constante).
const DESDE_PRINCIPIO := 6
const VER_FINAL := 7
const VOLVER := 8
## Con que celda se juega (scripts/personajes.gd), abajo a la izquierda de Volver.
const PERSONAJE := 9
const ELEMENTOS := 10
## Lo que tarda en entrar la pantalla. En ese rato no se aceptan toques: un doble
## toque en JUGAR abria la pantalla con el primero y, con el segundo, jugaba el
## nivel que quedaba debajo del dedo, antes de que se vieran las tarjetas.
const ENTRADA := 0.3

const RECHAZO := 0.25          ## s del contorno rojo y la sacudida
const AVISO := 2.5             ## s que se queda un aviso en el pie

var abierto := false
## "rojo" para lo que no se puede, "" para lo demas (el rasgo de un personaje)
var tipo_aviso := ""
var _retratos: Dictionary = {}        ## personaje -> su primer cuadro de reposo
## Al enfocar una tarjeta, se apunta: arriba desde los botones vuelve a ella, se
## haya llegado a los botones con flechas, con el raton o con el dedo.
var foco := 0:
	set(v):
		foco = v
		if v < DESDE_PRINCIPIO:
			_ultima_tarjeta = v
var _ultima_tarjeta := 0
## El que se rechazo: el contorno rojo y la sacudida son SUYOS, no del que tenga
## el foco despues (si no, saltaban a una tarjeta abierta al moverse).
var _rechazado := -1
var aviso := ""
## Para las pruebas: a false, elegir solo apunta a donde iria y no cambia de
## escena (cambiar de escena se lleva la prueba por delante).
var cambiar_de_verdad := true
var destino := ""

var _t := 0.0
var _t_abrir := 0.0
var _t_aviso := 0.0
var _t_rechazo := 0.0
var _tragar := false
## el puntero que manda: su index (-2 el raton, -1 ninguno) y donde empezo
var _dedo_indice := -1
var _dedo_en := -1
var _fuente: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fuente = ThemeDB.fallback_font
	visible = false


func abrir() -> void:
	if abierto:
		return
	abierto = true
	visible = true
	# el foco empieza en el nivel mas alto abierto: es a donde casi siempre se
	# vuelve, y asi elegir "seguir" es un Intro
	foco = 0
	for n in range(NIVELES.size(), 0, -1):
		if Guardado.nivel_desbloqueado(n):
			foco = n - 1
			break
	_t_abrir = 0.0
	_t_aviso = 0.0
	aviso = ""
	_soltar_dedo()
	# el Intro que abre la pantalla no puede ademas elegir un nivel
	_tragar = true
	queue_redraw()


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	_soltar_dedo()
	cerrado.emit()


# --------------------------------------------------------------- que hay
func abierto_elemento(i: int) -> bool:
	if i < NIVELES.size():
		return Guardado.nivel_desbloqueado(i + 1)
	if i == VER_FINAL:
		# el final va despues del nivel 3: se ve en cuanto se ha pasado
		return Guardado.nivel_desbloqueado(4)
	return true                     # desde el principio, Volver y el personaje


func motivo_cerrado(i: int) -> String:
	if i < NIVELES.size():
		return "Completa el nivel %d para abrirlo" % i
	if i == VER_FINAL:
		return "Completa el nivel 3 para verlo"
	return ""


static func texto_tiempo(t: float) -> String:
	return "%.1f s" % t if t > 0.0 else "--"


# -------------------------------------------------------------------- cajas
## Las mismas funciones dibujan, atienden al dedo y las lee la prueba. Panel a
## todo el ancho: cinco tarjetas con nombre, tiempo y fragmentos no caben en el
## tercio derecho que usa CONTROLES.
func _v() -> Vector2:
	return get_viewport_rect().size


func caja_panel() -> Rect2:
	var v := _v()
	return Rect2(v.x * 0.03, v.y * 0.03, v.x * 0.94, v.y * 0.94)


## Las tarjetas miden 0,55 del alto: en 360 son 198 px, muy por encima de los
## 46 que hacen falta para el pulgar. El ancho se reparte entre las seis.
func caja_tarjeta(i: int) -> Rect2:
	var v := _v()
	var p := caja_panel()
	var margen := v.x * 0.025
	var hueco := 6.0
	var an := (p.size.x - margen * 2.0 - hueco * float(NIVELES.size() - 1)) / float(NIVELES.size())
	return Rect2(p.position.x + margen + float(i) * (an + hueco), p.position.y + v.y * 0.098,
		an, v.y * 0.55)


## Los dos botones de historia, de 46 px, a media anchura cada uno.
func caja_boton(i: int) -> Rect2:
	var v := _v()
	var p := caja_panel()
	var margen := v.x * 0.025
	var hueco := 8.0
	var an := (p.size.x - margen * 2.0 - hueco) * 0.5
	var y := caja_tarjeta(0).end.y + 8.0
	var x := p.position.x + margen + (0.0 if i == DESDE_PRINCIPIO else an + hueco)
	return Rect2(x, y, an, 46.0)


## Volver, abajo a la derecha, de 46 px. Antes la unica salida con el dedo era
## "tocar fuera", y fuera del panel solo quedan 11 px arriba y abajo y 19 a los
## lados: un blanco que no se acierta con el pulgar.
func caja_volver() -> Rect2:
	var v := _v()
	var p := caja_panel()
	var an := v.x * 0.20
	return Rect2(p.end.x - v.x * 0.025 - an, caja_boton(DESDE_PRINCIPIO).end.y + 4.0, an, 46.0)


## El personaje, en la misma fila que Volver y a su izquierda. Empieza pasado el
## 30% del ancho para no pisar el pie, donde caben la ayuda y el aviso mas largo.
func caja_personaje() -> Rect2:
	var v := _v()
	var p := caja_panel()
	var vol := caja_volver()
	var x := p.position.x + v.x * 0.025 + v.x * 0.30
	return Rect2(x, vol.position.y, vol.position.x - 8.0 - x, 46.0)


func caja(i: int) -> Rect2:
	if i == VOLVER:
		return caja_volver()
	if i == PERSONAJE:
		return caja_personaje()
	return caja_boton(i) if i >= DESDE_PRINCIPIO else caja_tarjeta(i)


func caja_pie() -> Rect2:
	var v := _v()
	var p := caja_panel()
	var x := p.position.x + v.x * 0.025
	return Rect2(x, p.end.y - 20.0, p.end.x - v.x * 0.025 - x, 16.0)


## Lo que responde al dedo. La fila de abajo (personaje y Volver) llega hasta
## el borde de la pantalla: en 360 de alto el panel acaba 11 px antes, y un
## toque algo por debajo del boton, donde el pulgar cae de verdad, cerraba la
## pantalla en vez de pulsarlo.
func caja_toque(i: int) -> Rect2:
	var r := caja(i).grow(2.0)
	if i == VOLVER or i == PERSONAJE:
		r.size.y = maxf(_v().y - r.position.y, r.size.y)
	return r


func elemento_en(p: Vector2) -> int:
	for i in ELEMENTOS:
		if caja_toque(i).has_point(p):
			return i
	return -1


# -------------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if not abierto:
		return
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
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION \
			and _dedo_indice == -1:
		# con raton, pasar por encima enfoca, como en el menu
		var i := elemento_en((e as InputEventMouseMotion).position)
		if i >= 0:
			foco = i


func _pulsar(indice: int, p: Vector2) -> void:
	if _dedo_indice != -1 or _t_abrir < ENTRADA:
		return                      # ya manda otro dedo, o aun esta entrando
	var i := elemento_en(p)
	if i < 0 and not caja_panel().has_point(p):
		# tocar fuera del panel es volver, como en CONTROLES
		_tragado()
		cerrar()
		return
	_dedo_indice = indice
	_dedo_en = i
	if i >= 0:
		foco = i
		_tragado()


## La suelta siempre libera el dedo. Se elige solo si se levanta sobre lo mismo
## que se toco; un toque que cancela el sistema no elige nada.
func _levantar(indice: int, p: Vector2, cancelado: bool) -> void:
	if indice != _dedo_indice:
		return
	var era := _dedo_en
	_soltar_dedo()
	if cancelado or era < 0:
		return
	if elemento_en(p) == era:
		_tragado()
		_elegir(era)


func _soltar_dedo() -> void:
	_dedo_indice = -1
	_dedo_en = -1


func _tragado() -> void:
	_tragar = true
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _notification(que: int) -> void:
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT or que == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_soltar_dedo()


func _process(d: float) -> void:
	_t += d
	_t_abrir += d
	_t_aviso = maxf(_t_aviso - d, 0.0)
	_t_rechazo = maxf(_t_rechazo - d, 0.0)
	if not abierto:
		return
	queue_redraw()
	if _tragar:
		_tragar = false
		return
	if Input.is_action_just_pressed("ui_cancel"):
		cerrar()
		return
	if Input.is_action_just_pressed("ui_right"):
		_mover(1)
	elif Input.is_action_just_pressed("ui_left"):
		_mover(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_bajar()
	elif Input.is_action_just_pressed("ui_up"):
		_subir()
	elif Input.is_action_just_pressed("ui_accept"):
		_elegir(foco)


## Izquierda y derecha recorren la fila en la que se esta (tarjetas o botones)
## sin saltar a la otra. En el personaje, lo cambian (aunque Volver quede a su
## derecha: por eso desde el personaje se llega a Volver con abajo); desde
## Volver, izquierda lleva al personaje.
func _mover(paso: int) -> void:
	if foco == PERSONAJE:
		_ciclar(paso)
		return
	if foco == VOLVER:
		if paso < 0:
			foco = PERSONAJE
		return
	if foco >= DESDE_PRINCIPIO:
		foco = clampi(foco + paso, DESDE_PRINCIPIO, VER_FINAL)
	else:
		foco = clampi(foco + paso, 0, NIVELES.size() - 1)


## Tres pisos: tarjetas, botones de historia y Volver. De las tarjetas se baja
## al boton que queda debajo, y de los botones se vuelve a la ultima tarjeta.
func _bajar() -> void:
	if foco < DESDE_PRINCIPIO:
		foco = DESDE_PRINCIPIO if foco < NIVELES.size() / 2 else VER_FINAL
	elif foco == DESDE_PRINCIPIO:
		foco = PERSONAJE
	elif foco == VER_FINAL or foco == PERSONAJE:
		foco = VOLVER


func _subir() -> void:
	if foco == VOLVER:
		foco = VER_FINAL
	elif foco == PERSONAJE:
		foco = DESDE_PRINCIPIO
	elif foco >= DESDE_PRINCIPIO:
		foco = _ultima_tarjeta


func _elegir(i: int) -> void:
	foco = i
	if i == VOLVER:
		cerrar()
		return
	if i == PERSONAJE:
		_ciclar(1)
		return
	if not abierto_elemento(i):
		_rechazado = i
		_t_rechazo = RECHAZO
		aviso = motivo_cerrado(i)
		tipo_aviso = "rojo"
		_t_aviso = AVISO
		return
	if i < NIVELES.size():
		_ir(String(NIVELES[i][0]))
	elif i == DESDE_PRINCIPIO:
		_ir(INTRO)                  # la intro lleva sola al nivel 1
	elif i == VER_FINAL:
		_ir(FINAL)                  # y el final, al nivel 4


## Pasa al personaje siguiente (o anterior) de los que se pueden elegir. Si solo
## hay uno, dice como se despierta el siguiente: es la unica pista que hay en el
## juego de que existen.
func _ciclar(paso: int) -> void:
	var lista := Personajes.elegibles()
	if lista.size() <= 1:
		for id in Personajes.ORDEN:
			if Personajes.disponible(id) and not Personajes.desbloqueado(id):
				aviso = String(Personajes.dato(id, "desbloqueo"))
				tipo_aviso = ""
				_t_aviso = AVISO
				return
		return
	var i := maxi(lista.find(Personajes.actual()), 0)
	var siguiente: String = lista[(i + paso + lista.size()) % lista.size()]
	Personajes.elegir(siguiente)
	aviso = "%s: %s" % [Personajes.dato(siguiente, "nombre"), Personajes.dato(siguiente, "rasgo")]
	tipo_aviso = ""
	_t_aviso = AVISO


## El primer cuadro de reposo. Se carga SOLO la hoja de reposo (200 KB): cargar el
## SpriteFrames entero decodificaba las doce hojas (unos 25 MB) para dibujar un
## cuadro, y en un movil flojo se notaba al abrir la pantalla y al cambiar.
## Las hojas de todos los personajes se llaman igual y van en su carpeta.
func _retrato(id: String) -> Texture2D:
	if not _retratos.has(id):
		var ruta := String(Personajes.dato(id, "hojas")).get_base_dir() + "/tsl04_reposo.png"
		var hoja := load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null
		var cuadro: Texture2D = null
		if hoja != null:
			var a := AtlasTexture.new()
			a.atlas = hoja
			a.region = Rect2(0, 0, 288, 288)
			cuadro = a
		_retratos[id] = cuadro
	return _retratos[id]


func _ir(escena: String) -> void:
	destino = escena
	if cambiar_de_verdad and is_inside_tree():
		get_tree().change_scene_to_file(escena)


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

	var x0 := p.position.x + v.x * 0.025
	var base := v.y * 0.08
	_texto("> NIVELES", Vector2(x0, base), 15, Color(CIAN, 0.85))
	# La cabecera dice lo que acaba de pasar (por que algo esta cerrado, que
	# personaje se ha elegido) y, si no ha pasado nada, que es cada cifra. El
	# pie no sirve para eso: comparte fila con el personaje y Volver, y un aviso
	# largo los pisaba.
	var nota := "mejor tiempo  /  par"
	var col_nota := Color(APAGADO, 0.8)
	if _t_aviso > 0.0 and aviso != "":
		nota = aviso
		col_nota = Color(ROJO if tipo_aviso == "rojo" else HUESO, clampf(_t_aviso / 0.3, 0.0, 1.0))
	_texto(nota, Vector2(p.end.x - v.x * 0.025 - _ancho(nota, 11), base), 11, col_nota)
	draw_line(Vector2(x0, v.y * 0.094), Vector2(p.end.x - v.x * 0.025, v.y * 0.094),
		Color(MAGENTA, 0.55), 1.0)

	for i in NIVELES.size():
		_tarjeta_nivel(i)
	_boton(DESDE_PRINCIPIO, "Desde el principio", "con la intro")
	_boton(VER_FINAL, "Ver el final", "")
	_boton(VOLVER, "Volver", "")
	_boton_personaje()
	_pie()


## Entran escalonadas, como las filas de CONTROLES y de la pausa.
func _entrada(i: int) -> float:
	return clampf((_t_abrir - 0.04 * float(i)) / 0.12, 0.0, 1.0)


## El marco comun de tarjetas y botones: enfocado, cerrado y rechazado.
func _marco(i: int) -> Array:
	var r := caja(i)
	var ent := _entrada(i)
	r.position.y += (1.0 - ent) * 10.0
	var abre := abierto_elemento(i)
	var a := ent * (1.0 if abre else 0.45)
	var enf := i == foco
	var rechazado := i == _rechazado and _t_rechazo > 0.0
	if rechazado:
		r.position.x += sin(_t * 60.0) * 3.0 * (_t_rechazo / RECHAZO)
	if enf:
		draw_rect(r, Color(MAGENTA, 0.16 * ent), true)
		draw_rect(r, Color(MAGENTA, ent), false, 2.0)
		_estela_borde(r, ent)
	else:
		draw_rect(r, Color(CIAN, 0.06 * a), true)
		draw_rect(r, Color(CIAN, 0.30 * a), false, 1.0)
	if rechazado:
		draw_rect(r.grow(1.0), Color(ROJO, ent), false, 2.0)
	return [r, a, enf, abre]


func _tarjeta_nivel(i: int) -> void:
	var m := _marco(i)
	var r: Rect2 = m[0]
	var a: float = m[1]
	var enf: bool = m[2]
	var abre: bool = m[3]
	var n := i + 1
	var col := HUESO if enf else APAGADO
	var cx := r.position.x + 10.0
	_texto("%02d" % n, Vector2(cx, r.position.y + 34.0), 28, Color(CIAN if abre else APAGADO, a))
	_texto_ajustado(String(NIVELES[i][1]), Vector2(cx, r.position.y + 56.0), r.size.x - 20.0, 13, Color(col, a))
	draw_line(Vector2(cx, r.position.y + 68.0), Vector2(r.end.x - 10.0, r.position.y + 68.0),
		Color(CIAN, 0.25 * a), 1.0)
	if not abre:
		_candado(Vector2(r.get_center().x, r.position.y + 118.0), a)
		_texto_centrado("cerrado", r, r.position.y + 156.0, 11, Color(APAGADO, a))
		return
	var t := Guardado.mejor_tiempo(n)
	var par: float = NIVELES[i][2]
	# por debajo del par en lima: es lo unico que el selector "celebra"
	var col_t := LIMA if t > 0.0 and t <= par else HUESO
	_texto(texto_tiempo(t), Vector2(cx, r.position.y + 98.0), 17, Color(col_t, a))
	_texto("par %d s" % int(par), Vector2(cx, r.position.y + 116.0), 11, Color(APAGADO, a))
	# Los fragmentos como rombos dibujados: la fuente no tiene U+25C6 (en Android
	# saldria un cuadrado), la misma razon por la que el HUD los dibuja.
	var f := clampi(Guardado.fragmentos(n), 0, FRAGMENTOS)
	for k in FRAGMENTOS:
		_rombo(Vector2(cx + 7.0 + float(k) * 20.0, r.position.y + 150.0), k < f, a)


func _boton(i: int, titulo: String, sub: String) -> void:
	var m := _marco(i)
	var r: Rect2 = m[0]
	var a: float = m[1]
	var enf: bool = m[2]
	var abre: bool = m[3]
	var txt := titulo if abre else "%s  (cerrado)" % titulo
	var an := _ancho(txt, 15)
	var y := r.position.y + r.size.y * 0.5 + 5.0
	if sub != "" and abre:
		var an_sub := _ancho(sub, 11)
		var x := r.get_center().x - (an + 8.0 + an_sub) * 0.5
		_texto(txt, Vector2(x, y), 15, Color(HUESO if enf else APAGADO, a))
		_texto(sub, Vector2(x + an + 8.0, y), 11, Color(APAGADO, a))
	else:
		_texto(txt, Vector2(r.get_center().x - an * 0.5, y), 15, Color(HUESO if enf else APAGADO, a))


## El personaje: su dibujo, su nombre en su color, y su rasgo. Las flechas a los
## lados (dibujadas: la fuente no las tiene) dicen que se puede cambiar, y solo
## salen si hay mas de uno.
func _boton_personaje() -> void:
	var m := _marco(PERSONAJE)
	var r: Rect2 = m[0]
	var a: float = m[1]
	var enf: bool = m[2]
	var id := Personajes.actual()
	var tex := _retrato(id)
	var lado := r.size.y - 4.0
	# el cuadro de la hoja es de 288 y el personaje ocupa el tercio central
	if tex != null:
		draw_texture_rect_region(tex, Rect2(r.position.x + 8.0, r.position.y + 2.0, lado, lado),
			Rect2(72.0, 72.0, 144.0, 144.0), Color(1, 1, 1, a))
	var col: Color = Personajes.dato(id, "color")
	var x := r.position.x + 12.0 + lado
	_texto(String(Personajes.dato(id, "nombre")), Vector2(x, r.position.y + 21.0), 15, Color(col, a))
	_texto_ajustado(String(Personajes.dato(id, "rasgo")), Vector2(x, r.position.y + 37.0),
		r.end.x - x - 22.0, 11, Color(HUESO if enf else APAGADO, a))
	if Personajes.elegibles().size() > 1:
		var cy := r.get_center().y
		var cflecha := Color(HUESO if enf else APAGADO, a)
		var xd := r.end.x - 10.0
		draw_line(Vector2(xd - 4.0, cy - 6.0), Vector2(xd, cy), cflecha, 2.0)
		draw_line(Vector2(xd - 4.0, cy + 6.0), Vector2(xd, cy), cflecha, 2.0)


func _pie() -> void:
	var r := caja_pie()
	var y := r.position.y + 12.0
	# con el dedo ya esta el boton Volver, a la vista: no hace falta decirlo
	var partes: Array = [["Intro", "jugar"], ["Esc", "volver"]]
	var x := r.position.x
	for par in partes:
		var tecla: String = par[0]
		var texto: String = par[1]
		if tecla != "":
			var an := _ancho(tecla, 11) + 8.0
			draw_rect(Rect2(x, y - 11.0, an, 14.0), Color(APAGADO, 0.6), false, 1.0)
			_texto(tecla, Vector2(x + 4.0, y), 11, HUESO)
			x += an + 5.0
		_texto(texto, Vector2(x, y), 11, APAGADO)
		x += _ancho(texto, 11) + 16.0


# ---------------------------------------------------------------- utilidades
func _rombo(c: Vector2, lleno: bool, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8),
		c + Vector2(-6, 0)])
	if lleno:
		draw_colored_polygon(pts, Color(LIMA, a))
	else:
		pts.append(pts[0])
		draw_polyline(pts, Color(LIMA, 0.45 * a), 1.5)


func _candado(c: Vector2, a: float) -> void:
	var col := Color(APAGADO, a)
	draw_arc(c + Vector2(0, -6), 7.0, PI, TAU, 12, col, 2.0)
	draw_line(c + Vector2(-7, -6), c + Vector2(-7, -1), col, 2.0)
	draw_line(c + Vector2(7, -6), c + Vector2(7, -1), col, 2.0)
	draw_rect(Rect2(c + Vector2(-10, -1), Vector2(20, 15)), col, true)


func _ancho(t: String, tam: int) -> float:
	return _fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


func _texto(t: String, pos: Vector2, tam: int, col: Color) -> void:
	draw_string(_fuente, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)


## Si no cabe, baja a 11 px; si aun no cabe, se corta con un punto.
func _texto_ajustado(t: String, pos: Vector2, ancho: float, tam: int, col: Color) -> void:
	var tm := tam
	if _ancho(t, tm) > ancho:
		tm = 11
	var s := t
	while _ancho(s, tm) > ancho and s.length() > 2:
		s = s.substr(0, s.length() - 2) + "."
	_texto(s, pos, tm, col)


func _texto_centrado(t: String, r: Rect2, y: float, tam: int, col: Color) -> void:
	_texto(t, Vector2(r.get_center().x - _ancho(t, tam) * 0.5, y), tam, col)


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
