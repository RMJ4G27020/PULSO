extends Node
## Las teclas del jugador. Autoload `Teclas`, que va DESPUES de `Guardado`.
##
## El mapa de fabrica vive en project.godot y no se toca nunca. Lo que cambia el
## jugador se guarda aparte (opciones -> teclas, en el mismo progreso.json) y se
## aplica encima al arrancar. Asi "restaurar" es volver a leer project.godot y
## no hay una segunda copia del mapa de fabrica que se pueda desincronizar.
##
## Tres promesas que se cumplen por construccion, no por cuidado:
##  * NINGUNA accion se queda sin tecla. Ni quitando, ni robandole la suya otra
##    accion, ni con un guardado roto. Una accion sin tecla, en un juego donde
##    pararse mata, es una partida que no se puede jugar.
##  * Ninguna tecla esta en DOS acciones. Con la misma tecla en saltar y en
##    pulso, cada salto gastaria un cuarto de la carga.
##  * La pausa NO se reasigna: es Esc y nada mas. Es la salida de emergencia de
##    cualquier configuracion que salga mal, y ademas una pausa con Espacio o
##    Intro se abria y se cerraba sola: nivel.gd la abre en _unhandled_input y
##    pausa.gd, que corre con el arbol parado, veia ese mismo ui_accept en el
##    mismo cuadro y elegia "Continuar".

signal cambiadas

## Las que se pueden cambiar, en el orden en que salen en pantalla: primero lo
## que se usa cada segundo, al final lo que se usa una vez por nivel.
const ACCIONES: Array[String] = ["mover_izq", "mover_der", "saltar", "impulso",
	"pulso", "interactuar", "reiniciar"]
const ROTULOS := {
	"mover_izq": "Mover a la izquierda", "mover_der": "Mover a la derecha",
	"saltar": "Saltar", "impulso": "Impulso", "pulso": "Pulso de reinicio",
	"interactuar": "Accionar terminal", "reiniciar": "Reiniciar nivel",
	"pausa": "Pausa",
}
## Para los avisos del pie, que tienen que caber en una linea de 377 px a 11 px
## con el nombre de tecla mas largo: con los rotulos largos no cabian.
const CORTOS := {
	"mover_izq": "IZQUIERDA", "mover_der": "DERECHA", "saltar": "SALTAR",
	"impulso": "IMPULSO", "pulso": "PULSO", "interactuar": "TERMINAL",
	"reiniciar": "REINICIAR", "pausa": "PAUSA",
}
## Tres por accion porque es lo que ya trae el juego de fabrica: saltar tiene
## Espacio, flecha arriba y W. Con menos huecos, la configuracion de fabrica
## no cabria en su propia pantalla.
const MAX := 3

## Lista BLANCA, no negra. Una lista negra tendria que conocer todas las teclas
## raras que existen (volumen, multimedia, el "atras" de Android, las que mandan
## los teclados virtuales), y la que se olvide acaba asignada. Asi solo entra lo
## que se ha pensado que se puede pulsar jugando.
##  * Fuera Esc, que cancela la escucha y es la pausa.
##  * Fuera Bloq Mayus, Bloq Num y Bloq Despl: son interruptores, cada pulsacion
##    cambia una luz del teclado y el estado del sistema.
##  * Fuera Cmd/Windows: son del sistema operativo y no siempre llegan al juego.
##
## Del teclado numerico solo entran las teclas que NO cambian con Bloq Num
## (* / - + e Intro). Con Bloq Num apagado, Num 8, 4 y 6 mandan el CODIGO de las
## flechas, y las flechas de fabrica van por codigo: Num 4 asignada a pulso
## seria a la vez pulso y mover a la izquierda, una tecla en dos acciones que
## ninguna comprobacion de aqui podria ver.
const ESPECIALES: Array[int] = [
	KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT,
	KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_BACKSPACE, KEY_INSERT, KEY_DELETE,
	KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9,
	KEY_F10, KEY_F11, KEY_F12,
	KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_ADD,
]
const FLECHAS: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

var _nombres: Dictionary = {}          ## codigo -> nombre, rehecho al cambiar


func _ready() -> void:
	aplicar()


# ------------------------------------------------------------------ lectura
## Las teclas de una accion tal como estan ahora. Solo teclado: si algun dia hay
## mando, sus eventos no son de esta pantalla y se dejan como esten.
func de(accion: String) -> Array[InputEventKey]:
	var r: Array[InputEventKey] = []
	for e in InputMap.action_get_events(accion):
		var k := e as InputEventKey
		if k != null:
			r.append(k)
	return r


## Las de fabrica, leidas de project.godot. Copias, no los objetos de alli:
## action_add_event guarda la referencia, y si alguien la modificara despues
## cambiaria tambien "lo de fabrica".
func de_fabrica(accion: String) -> Array[InputEventKey]:
	var r: Array[InputEventKey] = []
	var v: Variant = ProjectSettings.get_setting("input/" + accion)
	if not (v is Dictionary):
		return r
	for e in (v as Dictionary).get("events", []):
		var k := e as InputEventKey
		if k != null:
			r.append(k.duplicate() as InputEventKey)
	return r


## La tecla, independiente de como se definio. Las letras de fabrica van por
## posicion fisica y las flechas, Espacio y Shift por codigo; para esas teclas
## especiales los dos numeros coinciden, asi que se comparan bien.
func codigo(k: InputEventKey) -> int:
	return int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)


func es_asignable(cod: int) -> bool:
	if cod <= 0:
		return false
	# Imprimibles: letras, cifras, signos y Espacio. Va hasta el 126 y no hasta
	# KEY_SPECIAL: la tecla FISICA se nombra por su sitio en un QWERTY de EEUU,
	# asi que la Ñ de un teclado espanol llega como el punto y coma (59). Del 127
	# al 255 solo hay caracteres de control y simbolos que ningun teclado manda
	# como posicion (la prueba los encontro: la fuente ni siquiera los dibuja),
	# menos las dos teclas de mas de los teclados ISO y JIS.
	#
	# Y sin 97-122: las letras de las teclas son las MAYUSCULAS (KEY_A = 65). Las
	# minusculas no son ninguna tecla, y un "f97" en un guardado tocado a mano
	# dejaba la accion con una tecla que no existe pero que se veia como "A".
	if cod >= KEY_SPACE and cod <= KEY_ASCIITILDE:
		return cod < 97 or cod > 122
	# Ctrl en macOS: Ctrl con las flechas son atajos del sistema (Mission
	# Control) que el juego nunca llega a recibir. Ctrl como impulso dejaria de
	# funcionar justo al correr con las flechas.
	if cod == KEY_CTRL and OS.get_name() == "macOS":
		return false
	return cod in ESPECIALES or cod == KEY_SECTION or cod == KEY_YEN


func es_flecha(cod: int) -> bool:
	return cod in FLECHAS


## Que accion usa ya esta tecla, o "" si ninguna. Incluye la pausa, aunque no se
## reasigne: Esc es suya y no puede acabar en otra accion.
func duena_de(cod: int) -> String:
	for a in ACCIONES + ["pausa"]:
		for k in de(a):
			if codigo(k) == cod:
				return a
	return ""


func es_de_fabrica() -> bool:
	return cambios() == 0


## Cuantos huecos difieren de fabrica, para el "N cambios" de la pantalla.
##
## Se compara la TECLA (codigo()), no como esta escrita (_firma). Shift de
## fabrica va por codigo ("k4194325") y el que pone el jugador por posicion
## ("f4194325"): son la misma tecla, y devolverle a impulso su Shift contaba
## como un cambio y se guardaba en disco.
func cambios() -> int:
	var n := 0
	for a in ACCIONES:
		var ahora := _codigos(de(a))
		var antes := _codigos(de_fabrica(a))
		for i in maxi(ahora.size(), antes.size()):
			if i >= ahora.size() or i >= antes.size() or ahora[i] != antes[i]:
				n += 1
	return n


## Si el hueco `i` de la accion es distinto del de fabrica.
func hueco_cambiado(accion: String, i: int) -> bool:
	var ahora := _codigos(de(accion))
	var antes := _codigos(de_fabrica(accion))
	if i >= ahora.size():
		return false
	return i >= antes.size() or ahora[i] != antes[i]


# ------------------------------------------------------------------ cambios
## Pone la tecla `cod` en el hueco `hueco` de `accion`; si `hueco` es igual al
## numero de teclas que tiene, la anade. Devuelve [hecho, aviso, otra]:
##  * aviso es lo que hay que decirle al jugador, tambien cuando sale bien: si
##    se le ha quitado la tecla a otra accion, tiene que saberlo.
##  * otra es la accion a la que se le quito o intercambio, o "".
func asignar(accion: String, hueco: int, cod: int) -> Array:
	if not (accion in ACCIONES):
		return [false, "", ""]
	if not es_asignable(cod):
		return [false, "%s no se puede asignar" % nombre_codigo(cod), ""]
	var mias: Array[InputEventKey] = de(accion)
	if hueco < 0 or hueco > mias.size() or hueco >= MAX:
		return [false, "", ""]
	for i in mias.size():
		if codigo(mias[i]) == cod:
			if i == hueco:
				return [true, "", ""]
			return [false, "%s ya es de %s" % [nombre_codigo(cod), CORTOS[accion]], ""]

	var aviso := ""
	var otra := duena_de(cod)
	if otra == "pausa":
		return [false, "%s es de PAUSA" % nombre_codigo(cod), ""]
	if otra != "":
		var suyas: Array[InputEventKey] = de(otra)
		var j := -1
		for i in suyas.size():
			if codigo(suyas[i]) == cod:
				j = i
		if suyas.size() > 1:
			# le quedan mas: se le quita y ya
			suyas.remove_at(j)
			aviso = "%s pasa de %s a %s" % [nombre_codigo(cod), CORTOS[otra], CORTOS[accion]]
		elif hueco < mias.size():
			# Era su unica tecla. Se intercambian: la otra se queda con la que
			# esta accion tenia en ese hueco. Asi nadie se queda sin tecla y el
			# jugador no pierde nada sin enterarse.
			var vieja: InputEventKey = mias[hueco]
			suyas[j] = vieja
			aviso = "Intercambio: %s a %s, %s a %s" % [nombre_codigo(cod), CORTOS[accion],
				nombre(vieja), CORTOS[otra]]
		else:
			# era su unica tecla y en un hueco vacio no hay nada que darle a cambio
			return [false, "%s se quedaria sin tecla" % CORTOS[otra], ""]
		_poner(otra, suyas)

	# Las que pone el jugador van SIEMPRE por posicion fisica: si cambia la
	# distribucion del teclado, la tecla sigue en el mismo sitio de la mano.
	var nueva := InputEventKey.new()
	nueva.physical_keycode = cod as Key
	if hueco < mias.size():
		mias[hueco] = nueva
	else:
		mias.append(nueva)
	_poner(accion, mias)
	_guardar()
	return [true, aviso, otra]


## Quita la tecla del hueco. Nunca la ultima.
func quitar(accion: String, hueco: int) -> Array:
	if not (accion in ACCIONES):
		return [false, "", ""]
	var mias: Array[InputEventKey] = de(accion)
	if hueco < 0 or hueco >= mias.size():
		return [false, "", ""]
	if mias.size() <= 1:
		return [false, "%s necesita al menos una tecla" % CORTOS[accion], ""]
	var ida := nombre(mias[hueco])
	mias.remove_at(hueco)
	_poner(accion, mias)
	_guardar()
	return [true, "%s quitada de %s" % [ida, CORTOS[accion]], ""]


func restaurar() -> void:
	for a in ACCIONES:
		_poner(a, de_fabrica(a))
	Guardado.poner_opcion("teclas", {})
	Guardado.guardar()
	_rehacer_nombres()
	cambiadas.emit()


func _poner(accion: String, teclas: Array[InputEventKey]) -> void:
	# Lo que no es teclado se conserva: esta pantalla solo responde de teclas.
	for e in InputMap.action_get_events(accion):
		if e is InputEventKey:
			InputMap.action_erase_event(accion, e)
	var puestas: Array[int] = []
	for k in teclas:
		if codigo(k) in puestas or puestas.size() >= MAX:
			continue
		InputMap.action_add_event(accion, k)
		puestas.append(codigo(k))


# ------------------------------------------------------------------- disco
## Solo se guardan las acciones que difieren de fabrica: un cambio futuro en
## project.godot (una tecla nueva de fabrica) llega asi a quien nunca toco esa
## accion, en vez de quedarse tapado por una copia vieja.
func _guardar() -> void:
	var t := {}
	for a in ACCIONES:
		if _codigos(de(a)) != _codigos(de_fabrica(a)):
			t[a] = _firma(de(a))
	Guardado.poner_opcion("teclas", t)
	Guardado.guardar()
	_rehacer_nombres()
	cambiadas.emit()


## "f87" es la W por posicion fisica, "k32" Espacio por codigo. Texto y no
## numeros: JSON devuelve todos los numeros como float, y 4194319.0 tendria que
## volver a int sin perder nada por el camino. Con texto no hay camino.
func _firma(teclas: Array[InputEventKey]) -> Array[String]:
	var r: Array[String] = []
	for k in teclas:
		if k.physical_keycode != KEY_NONE:
			r.append("f%d" % int(k.physical_keycode))
		else:
			r.append("k%d" % int(k.keycode))
	return r


## Lee lo guardado y lo pone encima de fabrica. No escribe nunca a disco: un
## guardado roto se ignora, pero no se pisa, por si se puede rescatar a mano.
func aplicar() -> void:
	var guardadas: Variant = Guardado.opcion("teclas", {})
	if not (guardadas is Dictionary):
		guardadas = {}
	var nuevo := {}
	var vistas := {}                   ## codigo -> accion, para ver repetidas
	for c in _codigos(de_fabrica("pausa")):
		vistas[c] = "pausa"
	var repetida := false
	for a in ACCIONES:
		var teclas: Array[InputEventKey] = []
		var lista: Variant = (guardadas as Dictionary).get(a, null)
		if lista is Array:
			for s in lista:
				var k := _leer(s)
				if k != null and es_asignable(codigo(k)) and teclas.size() < MAX:
					teclas.append(k)
		# nada valido, o la accion no estaba guardada: las de fabrica
		if teclas.is_empty():
			teclas = de_fabrica(a)
		for c in _codigos(teclas):
			if vistas.has(c) and vistas[c] != a:
				repetida = true
			vistas[c] = a
		nuevo[a] = teclas
	if repetida:
		# Una tecla en dos acciones solo puede venir de un archivo tocado a mano o
		# a medio escribir. Arreglarlo accion por accion obligaria a decidir cual
		# de las dos se la queda; volver todo a fabrica no decide nada y siempre
		# deja un mapa valido.
		push_warning("teclas guardadas con una tecla repetida: se usan las de fabrica")
		for a in ACCIONES:
			nuevo[a] = de_fabrica(a)
	for a in ACCIONES:
		_poner(a, nuevo[a])
	_rehacer_nombres()


func _codigos(teclas: Array[InputEventKey]) -> Array[int]:
	var r: Array[int] = []
	for k in teclas:
		r.append(codigo(k))
	return r


func _leer(s: Variant) -> InputEventKey:
	if not (s is String) or (s as String).length() < 2:
		return null
	var t: String = s
	var num: String = t.substr(1)
	if not num.is_valid_int() or int(num) <= 0:
		return null
	var k := InputEventKey.new()
	if t[0] == "f":
		k.physical_keycode = int(num) as Key
	elif t[0] == "k":
		k.keycode = int(num) as Key
	else:
		return null
	return k


# ------------------------------------------------------------------ nombres
## En espanol y sin flechas Unicode: la fuente del juego no tiene U+2190-2193
## (has_char da false; en macOS el sistema presta el glifo y en Android saldria
## un cuadrado). Las flechas la pantalla las DIBUJA; estos nombres son para el
## texto de los avisos.
const NOMBRES := {
	KEY_SPACE: "Espacio", KEY_LEFT: "Flecha izq.", KEY_RIGHT: "Flecha der.",
	KEY_UP: "Flecha arriba", KEY_DOWN: "Flecha abajo", KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_ENTER: "Intro", KEY_KP_ENTER: "Intro num",
	KEY_ESCAPE: "Esc", KEY_TAB: "Tab", KEY_BACKSPACE: "Retroceso",
	KEY_DELETE: "Supr", KEY_INSERT: "Insert", KEY_HOME: "Inicio", KEY_END: "Fin",
	KEY_PAGEUP: "RePag", KEY_PAGEDOWN: "AvPag", KEY_CAPSLOCK: "Bloq Mayus",
	KEY_NUMLOCK: "Bloq Num", KEY_META: "Cmd",
	KEY_KP_MULTIPLY: "Num *", KEY_KP_DIVIDE: "Num /", KEY_KP_SUBTRACT: "Num -",
	KEY_KP_ADD: "Num +", KEY_KP_PERIOD: "Num .",
}
## Solo estos servidores de pantalla saben de distribuciones de teclado. Los
## demas (el de las pruebas, Android) escriben un ERROR en cada llamada, y el
## nombre se pinta en cada cuadro: serian sesenta errores por segundo.
const CON_DISTRIBUCION: Array[String] = ["Windows", "macOS", "X11", "Wayland"]


func nombre(k: InputEventKey) -> String:
	return nombre_codigo(codigo(k))


## El nombre se calcula una vez por tecla y se guarda: se pide desde _draw y la
## consulta de distribucion no es gratis.
func nombre_codigo(c: int) -> String:
	if _nombres.has(c):
		return _nombres[c]
	var n := _calcular_nombre(c)
	_nombres[c] = n
	return n


func _calcular_nombre(c: int) -> String:
	if NOMBRES.has(c):
		return NOMBRES[c]
	if c >= KEY_KP_0 and c <= KEY_KP_9:
		return "Num %d" % (c - KEY_KP_0)          # no se asignan, pero se nombran
	if c >= KEY_F1 and c <= KEY_F12:
		return "F%d" % (c - KEY_F1 + 1)
	if c > KEY_SPACE and c < KEY_SPECIAL:
		# La letra que pone en TU teclado, no la del QWERTY: en un AZERTY la
		# posicion de la W tiene una Z impresa, y en uno espanol la del punto y
		# coma tiene una Ñ. Si la fuente no tiene ese caracter, el del QWERTY.
		var mostrar := c
		if DisplayServer.get_name() in CON_DISTRIBUCION:
			var local: int = int(DisplayServer.keyboard_get_label_from_physical(c as Key))
			if local > KEY_SPACE and local < KEY_SPECIAL \
					and ThemeDB.fallback_font.has_char(local):
				mostrar = local
		return String.chr(mostrar).to_upper()
	var s: String = OS.get_keycode_string(c as Key)
	return s if s != "" else "?"


func _rehacer_nombres() -> void:
	_nombres.clear()
