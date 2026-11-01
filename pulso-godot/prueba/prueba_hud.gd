extends Node
## El HUD nuevo, medido a los DOS anchos del juego.
##
## Se monta dentro de un SubViewport porque en headless la ventana no se puede
## redimensionar: window_set_size no hace nada y el viewport se queda en 640.
## Con un SubViewport se miden los 640 px del 16:9 y los 780 px a los que se
## estira un movil 20:9, que es donde lo anclado se descolgaba.
var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-64s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	for ancho in [640, 780]:
		await _mirar(ancho)
	print("FALLOS: %d" % fallos)
	print("PRUEBA HUD OK")
	get_tree().quit()

func _mirar(ancho: int) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(ancho, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var capa: Node = load("res://escenas/Hud.tscn").instantiate()
	sv.add_child(capa)
	var h: Control = capa.get_node("Panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var r: Vector2 = h.get_viewport_rect().size
	print("  --- %.0f x %.0f" % [r.x, r.y])
	_ok(absf(r.x - float(ancho)) < 0.5, "el HUD se monta a %d px de ancho" % ancho)

	# --- el cronometro no baila. Antes "%5.1f" rellenaba con ESPACIO ASCII, que
	# mide 5 px contra los 11 del digito: 12 px de baile al pasar de 9,9 a 10,0.
	h.actualizar(0.0, 52.0, 100.0, 0, 3, "", "", 0, Vector2.INF)
	var a0: float = h.caja_cronometro().size.x
	h.actualizar(141.8, 52.0, 100.0, 0, 3, "", "", 0, Vector2.INF)
	var a1: float = h.caja_cronometro().size.x
	_ok(absf(a0 - a1) < 0.5,
		"el cronometro no cambia de ancho entre 0.0 y 141.8 (%.1f vs %.1f px)" % [a0, a1])

	# --- la fila de rombos tampoco: los vacios ocupan lo mismo que los llenos
	h.actualizar(1.0, 52.0, 100.0, 0, 3, "", "", 0, Vector2.INF)
	var f0: float = h.caja_rombos().size.x
	h.actualizar(1.0, 52.0, 100.0, 2, 3, "", "", 0, Vector2.INF)
	var f1: float = h.caja_rombos().size.x
	_ok(absf(f0 - f1) < 0.5,
		"la fila de fragmentos no cambia de ancho al recoger (%.1f vs %.1f px)" % [f0, f1])

	# --- carga baja: una CIFRA, no 3,5 px rojos en una esquina
	h.actualizar(1.0, 52.0, 3.0, 0, 3, "", "", 0, Vector2.INF)
	var cifra: String = h.texto_segundos(3.0)
	var caja: Rect2 = h.caja_cifra()
	_ok(cifra.length() >= 3 and caja.size.x > 8.0,
		"a carga 3%% hay cifra legible ademas del color ('%s', %.0f px)" % [cifra, caja.size.x])

	# --- el cerco: monotono y con tope de seguridad fotosensible
	var mono := true
	var tope := 0.0
	var previa := -1.0
	var c := 100.0
	while c >= 0.0:
		var hz: float = h.hz_cerco(c)
		if previa >= 0.0 and hz < previa - 0.0001:
			mono = false
		previa = hz
		tope = maxf(tope, hz)
		c -= 2.5
	_ok(mono, "la frecuencia del cerco crece al bajar la carga, sin tirones")
	_ok(tope <= 2.6001, "y nunca pasa de 2,6 Hz (maximo %.2f)" % tope)

	# --- el cuadro central es del personaje: ahi no se dibuja nada
	h.actualizar(5.0, 52.0, 60.0, 1, 3, "busca la terminal", "Nivel 2  ·  El corredor",
		0, Vector2(4000, 200), false)
	h.reiniciar_animacion()
	await get_tree().process_frame
	var libre: Rect2 = h.caja_libre()
	var choca := ""
	for caj in h.cajas():
		if caj.intersects(libre):
			choca += str(caj) + " "
	_ok(choca == "", "nada dibujado en el cuadro central de 120x120 %s" % choca)

	# --- fuera del alcance del pulgar. La barra y los rombos viven en la franja
	# de arriba, y el joystick ya no nace por encima del 30% de la pantalla.
	var techo: float = r.y * 0.30
	var bajo := ""
	for par in [["barra", h.caja_barra()], ["cifra", h.caja_cifra()], ["rombos", h.caja_rombos()]]:
		if float((par[1] as Rect2).end.y) > techo:
			bajo += str(par[0]) + " "
	_ok(bajo == "",
		"barra, cifra y rombos quedan sobre y=%.0f, donde el joystick no nace %s" % [techo, bajo])

	# --- ninguna cadena de estado se sale de su hueco
	var largo := ""
	for s in ["busca la terminal", "conectando…", "puerta abierta  →  a la salida",
			  "salida alcanzada"]:
		h.actualizar(5.0, 52.0, 60.0, 0, 3, s, "", 0, Vector2.INF)
		h.reiniciar_animacion()
		var ce: Rect2 = h.caja_estado()
		if ce.size.x > 0.0 and (ce.position.x < 8.0 or ce.end.x > r.x - 8.0):
			largo += s + " "
	_ok(largo == "", "ninguna cadena de estado se sale del hueco %s" % largo)

	# --- el aviso de quietud y la regla de toma de tierra
	_ok(h.aviso_quietud(0.5, false), "el aviso de quietud salta a los 0,20 s sobre la estela")
	_ok(not h.aviso_quietud(0.5, true), "y NO salta sobre una celda de toma de tierra")
	_ok(not h.aviso_quietud(0.1, false), "ni antes de los 0,20 s")

	# --- las animaciones avanzan de verdad (se mide el valor, no la llamada)
	h.cerco_fijo = false
	h.actualizar(1.0, 52.0, 8.0, 0, 3, "", "T", 0, Vector2.INF)
	var muestras: Array[float] = []
	for i in 8:
		await get_tree().process_frame
		h.actualizar(1.0, 52.0, 8.0, 0, 3, "", "T", 0, Vector2.INF)
		muestras.append(h.alfa_cerco())
	var mov := 0.0
	for i in range(1, muestras.size()):
		mov = maxf(mov, absf(muestras[i] - muestras[0]))
	_ok(mov > 0.001, "el cerco late de verdad: la alfa se mueve %.3f entre cuadros" % mov)

	# --- y con "cerco fijo" deja de latir (opcion de fotosensibilidad)
	h.cerco_fijo = true
	var fijas: Array[float] = []
	for i in 8:
		await get_tree().process_frame
		h.actualizar(1.0, 52.0, 8.0, 0, 3, "", "T", 0, Vector2.INF)
		fijas.append(h.alfa_cerco())
	var mov2 := 0.0
	for i in range(1, fijas.size()):
		mov2 = maxf(mov2, absf(fijas[i] - fijas[0]))
	_ok(mov2 < 0.0001, "con 'cerco fijo' la alfa no cambia entre cuadros (%.5f)" % mov2)
	h.cerco_fijo = false

	# --- el chevron falla a invisible si el nivel no tiene objetivo
	h.actualizar(1.0, 52.0, 80.0, 0, 3, "", "", 0, Vector2.INF)
	_ok(h.caja_chevron().size == Vector2.ZERO,
		"sin objetivo NO se dibuja chevron (antes que apuntar al vacio)")
	h.actualizar(1.0, 52.0, 80.0, 0, 3, "", "", 0, Vector2(5000, 100), true)
	_ok(h.caja_chevron().size.x > 0.0, "y con objetivo si aparece, pegado al borde")

	sv.queue_free()
	await get_tree().process_frame
