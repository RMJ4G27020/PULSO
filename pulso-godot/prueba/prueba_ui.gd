extends Node
## Recorre menu y cinematica y avisa si algo falla.

var fase := 0
var cine: Control
var menu: Control
var pasos := 0
var fallos := 0
## Guardia. Esta prueba se quedo colgada un dia entero: miraba propiedades que
## cine.gd ya no tiene, erraba en cada fotograma y nunca llegaba a terminar.
## Ninguna prueba debe poder colgarse: si no acaba, falla.
const TOPE := 2600
var listo := false               ## _process espera a que acabe la revision 3D

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-56s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	menu = load("res://escenas/MenuPrincipal.tscn").instantiate()
	add_child(menu)
	print("MENU instanciado, opciones=", menu.OPCIONES.size())
	await get_tree().process_frame
	await _comprobar_3d()
	listo = true
	# Solo DESPUES de revisar el 3D se acelera el reloj: la camara del menu
	# persigue su objetivo con un suavizado por segundo, y a 25x los 30
	# fotogramas de espera son 0,05 s reales y no le da tiempo a moverse.
	Engine.time_scale = 25.0        # 32 s de cinematica en poco mas de un segundo

func _process(_d: float) -> void:
	if not listo:
		return                    # o el menu se libera a mitad de la revision
	pasos += 1
	if fase == 0:
		if pasos == 10: menu.sel = 1
		if pasos == 20: menu.sel = 3
		if pasos == 30: menu._panel = "controles"
		# El panel se abria y nadie miraba si de verdad se abria: si reventaba,
		# el error salia por consola y la prueba pasaba igual.
		if pasos == 35:
			var c: Control = menu.get_node_or_null("Controles") as Control
			_ok(c != null and c.abierto and c.visible, "OPCIONES abre la pantalla de controles")
		if pasos == 40: menu._panel = "creditos"
		if pasos == 45:
			var c2: Control = menu.get_node_or_null("Controles") as Control
			_ok(c2 != null and not c2.abierto, "y al pasar a creditos se cierra sola")
		if pasos == 50:
			menu._panel = ""
			print("MENU ok: sel=%d panel='%s' reten=%.1f" % [menu.sel, menu._panel, menu._reten])
			menu.queue_free()
			fase = 1
			cine = load("res://escenas/CineIntro.tscn").instantiate()
			cine.termino.connect(_fin_cine)
			add_child(cine)
	elif fase == 1 and cine != null and is_instance_valid(cine):
		if pasos % 40 == 0:
			# cine.gd cuenta por BEATS, no por "tomas": la prueba se habia
			# quedado con el vocabulario de una version anterior.
			var i: int = clampi(cine.beat, 0, cine.BEATS.size() - 1)
			print("CINE beat %d/%d (%s)" % [i + 1, cine.BEATS.size(),
				String(cine.BEATS[i][3])])
	if pasos > TOPE:
		fallos += 1
		print("  %-52s %s" % ["la cinematica termina sola", "FALLA"])
		print("FALLOS: %d" % fallos)
		print("PRUEBA UI OK")
		get_tree().quit()

## El menu lleva una escena 3D viva detras. Lo que hay que proteger no es que
## se vea bonita, que eso no lo puede juzgar una prueba, sino tres cosas que se
## rompen solas y en silencio: que el 3D siga MONTADO, que siga DETRAS del
## texto, y que no se dispare el coste de dibujo en un movil.
func _comprobar_3d() -> void:
	var mundo: Node3D = menu.get_node_or_null("Escena3D/Marco/Vista/Mundo") as Node3D
	_ok(mundo != null, "el menu monta la escena 3D")
	if mundo == null:
		return
	var mallas := 0
	for h in mundo.get_children():
		if h is MeshInstance3D:
			mallas += 1
	_ok(mallas >= 10, "hay %d mallas en la escena (anillo, placas, paquetes)" % mallas)
	_ok(mundo.get_node_or_null("Camara") != null, "y una camara propia")

	# La capa negativa es lo unico que mantiene el 3D DEBAJO del texto. Un
	# CanvasItem se dibuja antes que sus hijos, asi que colgado del Control
	# taparia todo lo que pinta _draw().
	var capa: CanvasLayer = menu.get_node_or_null("Escena3D") as CanvasLayer
	_ok(capa != null and capa.layer < 0,
		"la escena 3D va en capa %d, por debajo del texto" % (capa.layer if capa else 0))

	# Cambiar de opcion tiene que MOVER la camara: es el gesto que convierte el
	# fondo en un espacio y no en un dibujo. Y ahora ademas TSL-04 mira a la fila
	# elegida, que es lo que le hace parecer que te esta haciendo caso.
	mundo.mirar_opcion(0, 4)
	for i in 30: await get_tree().process_frame
	var cam0: float = mundo.get_node("Camara").position.y
	var mira0: float = mundo._mira.y
	mundo.mirar_opcion(3, 4)
	for i in 30: await get_tree().process_frame
	var cam1: float = mundo.get_node("Camara").position.y
	var mira1: float = mundo._mira.y
	_ok(absf(cam1 - cam0) > 0.3,
		"al cambiar de opcion la camara se desplaza %.2f unidades" % absf(cam1 - cam0))
	_ok(mira1 < mira0 - 0.5,
		"y TSL-04 baja la mirada %.2f de la primera fila a la ultima" % (mira0 - mira1))

	# Lo que se rompio una vez: en la pantalla que presenta el juego no salia el
	# personaje, solo una esfera azul. Que TSL-04 este montado CON CARA es parte
	# de la pantalla, no decoracion, asi que se comprueba pieza por pieza. Y se
	# comprueba que es EL MODELO DE BLENDER: si alguien lo cambia por una copia
	# hecha con primitivas, el personaje del menu se separa del de los sprites.
	var tsl: Node3D = mundo.get_node_or_null("Tsl04") as Node3D
	_ok(tsl != null, "TSL-04 esta en el menu")
	if tsl != null:
		_ok(tsl.scene_file_path == mundo.MODELO,
			"y es el modelo de Blender (%s)" % tsl.scene_file_path.get_file())
		var falta := ""
		for r in ["TSL04/ctrl_cuerpo/cuerpo", "TSL04/ctrl_cuerpo/ctrl_cara/boca",
				"TSL04/ctrl_cuerpo/ctrl_cara/rubor_L", "TSL04/ctrl_cuerpo/ctrl_cara/rubor_R",
				"TSL04/ctrl_cuerpo/ctrl_cara/ojo_L/iris_L", "TSL04/ctrl_cuerpo/ctrl_cara/ojo_L/brillo1_L",
				"TSL04/ctrl_cuerpo/ctrl_cara/ojo_R/iris_R", "TSL04/ctrl_cuerpo/ctrl_cara/ojo_R/brillo1_R"]:
			if tsl.get_node_or_null(r) == null:
				falta = r
		_ok(falta == "", "con cuerpo, boca, rubor, ojos y brillos" if falta == ""
			else "FALTA la pieza %s" % falta)
		# Pestanea y sigue con la mirada: sin esto se queda de cera. El parpadeo
		# no se espera al azar, se PROVOCA: cambiar de opcion tiene que hacerle
		# pestanear, que es parte de acusar el cambio.
		var ojo: Node3D = tsl.get_node("TSL04/ctrl_cuerpo/ctrl_cara/ojo_L")
		var iris: Node3D = ojo.get_node("iris_L")
		var abierto: float = ojo.scale.y
		var x0: float = iris.position.x
		mundo.mirar_opcion(1, menu.OPCIONES.size())
		var cerro := false
		var miro := false
		for i in 400:
			await get_tree().process_frame
			if ojo.scale.y < 0.4: cerro = true
			if absf(iris.position.x - x0) > 0.004: miro = true
			if cerro and miro: break
		_ok(cerro, "al cambiar de opcion pestanea")
		_ok(miro, "y mueve la mirada")
		# y se vuelve a abrir. Se espera por RELOJ y no por cuadros: en headless
		# los cuadros duran microsegundos y 400 no llegan ni a medio parpadeo.
		await get_tree().create_timer(0.4, true, false, true).timeout
		_ok(absf(ojo.scale.y - abierto) < 0.001, "y vuelve a abrir el ojo del todo")

		# Cada opcion tiene SU reaccion, y todas se apagan solas. Lo segundo es
		# lo que impide que el personaje se quede trabado en una pose: no hay
		# estados que apagar, solo curvas que mueren.
		var firmas := {}
		var viva := 0.0
		for op in menu.OPCIONES.size():
			var firma := ""
			for paso in 6:
				for x in mundo._reaccion(op, 0.12 * float(paso + 1)):
					firma += "%.2f," % float(x)
			firmas[firma] = true
			for x in mundo._reaccion(op, 6.0):
				viva = maxf(viva, absf(float(x)))
		_ok(firmas.size() == menu.OPCIONES.size(),
			"cada opcion tiene su propia reaccion (%d distintas)" % firmas.size())
		_ok(viva < 0.03, "y a los 6 s todas han vuelto al reposo (queda %.3f)" % viva)

		# La despedida de SALIR. Es lo unico del menu que NO lo dispara un
		# cambio de opcion sino un boton mantenido, asi que es lo unico que
		# podria quedarse puesto: se comprueba que entra y, sobre todo, que sale.
		# Se mantiene la tecla DE VERDAD y no se llama a despedida() a mano: el
		# menu la refresca en cada cuadro y le pisaria el valor a la prueba. Y se
		# mide por reloj de pared, porque en headless los cuadros duran
		# microsegundos y no le daria tiempo ni a empezar.
		var luz0: float = mundo._clave_tsl.light_energy
		menu.sel = menu.OPCIONES.size() - 1
		mundo.mirar_opcion(menu.sel, menu.OPCIONES.size())
		# 2,4 s de los 3 que hacen falta para salir: la despedida crece CON la
		# retencion, asi que a 0,9 s solo va por el 30% y no se media nada. Y no
		# mas de 2,4, que a los 3 el juego se cierra y se lleva la prueba.
		Input.action_press("ui_accept")
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2400:
			await get_tree().process_frame
		_ok(tsl.rotation.x > 0.25 and absf(tsl.rotation.z) > 0.15,
			"al mantener SALIR agacha la cabeza (%.2f) y la ladea (%.2f)" %
			[tsl.rotation.x, absf(tsl.rotation.z)])
		var encogido: float = tsl.scale.x
		_ok(encogido < mundo.ESCALA * 0.96,
			"y se encoge al %.0f%%" % (100.0 * encogido / mundo.ESCALA))
		_ok(ojo.scale.x > 1.05, "y se le hacen los ojos mas grandes (x%.2f)" % ojo.scale.x)
		# la luz propia solo la toca la despedida: es lo que distingue "se esta
		# despidiendo" de "la opcion SALIR le da pena", que tambien agacha
		_ok(mundo._clave_tsl.light_energy < luz0 * 0.8,
			"y se va apagando (%.0f%% de su luz)" %
			(100.0 * mundo._clave_tsl.light_energy / luz0))
		# lo que dice, que es lo que nadie verificaria a ojo
		var letras := ""
		for b in menu.ADIOS_BITS:
			var n := 0
			for i in 8:
				n = n * 2 + (1 if String(b)[i] == "1" else 0)
			letras += char(n)
		_ok(letras == menu.ADIOS_TEXTO, "y el binario de la despedida dice '%s'" % letras)

		Input.action_release("ui_accept")
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1200:
			await get_tree().process_frame
		# Se compara con el tamano ENCOGIDO y no con el de reposo: la reaccion de
		# SALIR (el desanimo) sigue viva unos segundos mas por su cuenta, y es
		# correcto que siga; lo que tiene que haberse ido es la despedida.
		_ok(mundo._p_adios < 0.02 and tsl.scale.x > encogido * 1.05
			and mundo._clave_tsl.light_energy > luz0 * 0.99,
			"y al soltar se deshace entera (queda %.3f)" % mundo._p_adios)
		_ok(menu._reten == 0.0, "y el contador de SALIR vuelve a cero")
		menu.sel = 0
		mundo.mirar_opcion(0, menu.OPCIONES.size())

	var dibujos: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_ok(dibujos < 200, "el menu entero cuesta %d dibujos por cuadro (tope 200)" % dibujos)


func _fin_cine() -> void:
	var i: int = clampi(cine.beat, 0, cine.BEATS.size() - 1)
	print("  %-52s %s" % ["la cinematica recorre sus %d laminas y termina" % cine.BEATS.size(), "OK"])
	print("CINE completa: acabo en el beat %d de %d" % [i + 1, cine.BEATS.size()])
	print("FALLOS: %d" % fallos)
	print("PRUEBA UI OK")
	get_tree().quit()
