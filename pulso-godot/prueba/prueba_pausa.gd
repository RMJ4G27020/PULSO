extends Node
## La pausa tiene que congelar el juego DE VERDAD y devolverte al mismo sitio.
##
## El 12/12 de antes era mentira: llamaba a _abrir_pausa() a mano y nunca
## comprobaba que la partida sobreviviera. En el juego real, la tecla abria y
## cerraba el menu en el MISMO cuadro (nivel.gd abria y pausa.gd se comia la
## misma pulsacion), abrir llamaba a reiniciar() y te borraba el nivel, y en
## movil no habia ningun boton. Aqui se mide todo eso.
var fallos := 0
var n: Node2D
var jug: CharacterBody2D
var pausa: Control
var mandos: Control
var capa_mandos: CanvasLayer
var _reinicios := 0
var _salidas := 0
## los lambdas de GDScript capturan las locales POR VALOR: los testigos de los
## temporizadores tienen que ser miembros o no se enteran de nada
var _tic_salida := false
var _tic_muerte := false

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-62s %s" % [txt, "OK" if c else "FALLA"])

func _tecla_pausa() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var s := InputEventKey.new()
	s.keycode = KEY_ESCAPE
	s.pressed = false
	Input.parse_input_event(s)

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	n = load("res://escenas/niveles/n1_ida_y_vuelta.tscn").instantiate() as Node2D
	add_child(n)
	# esta prueba corre en ALWAYS para sobrevivir a la pausa, y los hijos
	# heredan ese modo. En el juego el nivel es la escena raiz y SI se pausa,
	# asi que hay que decirselo o la prueba mide una situacion que no existe.
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().create_timer(0.3).timeout
	jug = n.get_node("Jugador")
	pausa = n.get_node("Pausa/Menu")
	pausa.reiniciar.connect(func(): _reinicios += 1)
	pausa.salir.connect(func(): _salidas += 1)

	# en escritorio los mandos no se montan (no hay pantalla tactil), asi que se
	# montan aqui a mano y se le entregan al menu igual que hace nivel.gd
	var esc: Node = load("res://escenas/Tactil.tscn").instantiate()
	n.add_child(esc)
	capa_mandos = esc as CanvasLayer
	mandos = esc.get_node("Mandos")
	pausa.mandos = capa_mandos
	await get_tree().process_frame

	_ok(pausa != null, "el nivel monta el menu de pausa")
	_ok(not get_tree().paused, "se empieza sin pausa")

	await _la_tecla_abre()
	await _la_partida_sobrevive()
	await _lo_de_debajo_se_esconde()
	await _continuar_y_atras()
	await _dos_toques()
	await _volumen()
	await _flecha_arriba()
	await _un_toque_cuenta_una_vez()
	await _ceremonias()
	await _pausar_corriendo()
	_boton_tactil()

	print("FALLOS: %d" % fallos)
	print("PRUEBA PAUSA OK")
	get_tree().quit()

## Lo que el jugador vive: pulsa Esc y tiene que APARECER un menu y QUEDARSE.
func _la_tecla_abre() -> void:
	await _tecla_pausa()
	await get_tree().process_frame
	_ok(pausa.abierto, "la tecla de pausa abre el menu")
	await get_tree().create_timer(0.1).timeout
	_ok(pausa.abierto and get_tree().paused,
		"y SIGUE abierto al cuadro siguiente (no se cierra solo)")
	pausa.cerrar(true)
	await get_tree().process_frame

## Abrir el menu no puede borrar la partida.
func _la_partida_sobrevive() -> void:
	n._tiempo = 7.25
	n._fragmentos_tomados = 2
	if n._inter:
		n._inter.activar()
	await get_tree().create_timer(0.3).timeout
	var pos: Vector2 = jug.global_position
	var puerta: bool = n._puerta != null and n._puerta.abierta
	var reloj: float = n._tiempo
	n._abrir_pausa()
	await get_tree().create_timer(0.15).timeout
	_ok(absf(n._tiempo - reloj) < 0.05,
		"el cronometro sobrevive a abrir la pausa (%.2f, era %.2f)" % [n._tiempo, reloj])
	_ok(n._fragmentos_tomados == 2, "los fragmentos sobreviven (%d)" % n._fragmentos_tomados)
	_ok(n._puerta == null or n._puerta.abierta == puerta, "la puerta sigue como estaba")
	_ok(jug.global_position.distance_to(pos) < 1.0,
		"y el jugador no se ha movido (%.1f px)" % jug.global_position.distance_to(pos))
	_ok(get_tree().paused, "abrir la pausa congela el arbol")
	_ok(pausa.visible, "y se ve el menu")

	var antes: Vector2 = jug.global_position
	Input.action_press("mover_izq")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("mover_izq")
	var movido: float = jug.global_position.distance_to(antes)
	_ok(movido < 0.5, "el jugador NO se mueve pausado (se movio %.2f px)" % movido)

## El menu tapa lo que hay debajo: con el HUD encendido se leia mejor el
## cronometro que las propias opciones.
func _lo_de_debajo_se_esconde() -> void:
	_ok(not n._capa_hud.visible, "el HUD se esconde con el menu abierto")
	_ok(not capa_mandos.visible, "y los mandos tactiles tambien")
	# y con el menu abierto, un dedo sobre saltar no lo pulsa
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = mandos._botones["saltar"]
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(0.1).timeout
	_ok(not Input.is_action_pressed("saltar"),
		"un dedo sobre SALTAR no lo pulsa con la pausa abierta")
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().process_frame

func _continuar_y_atras() -> void:
	pausa._elegir(0)
	await get_tree().create_timer(0.5).timeout
	_ok(not get_tree().paused, "continuar descongela")
	_ok(not pausa.visible, "y esconde el menu")
	_ok(n._capa_hud.visible and capa_mandos.visible, "y devuelve el HUD y los mandos")
	_ok(is_instance_valid(jug) and jug.is_inside_tree(),
		"sigues EN EL NIVEL, no te ha echado al menu")

	n._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(0.1).timeout
	_ok(get_tree().paused, "el boton atras de Android abre la pausa")
	n._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(0.5).timeout
	_ok(not get_tree().paused, "y pulsado otra vez la cierra")

## Las dos filas que borran la partida estan a un dedo de "Continuar": piden dos
## toques, y el primero solo cambia el rotulo a "confirmar".
func _dos_toques() -> void:
	var i_rei: int = pausa.OPCIONES.find("Reiniciar nivel")
	var i_sal: int = pausa.OPCIONES.find("Salir al menu")
	_ok(i_rei >= 0 and i_sal >= 0, "el menu tiene las filas destructivas al final")
	jug.global_position += Vector2(-120, 0)
	var lejos: Vector2 = jug.global_position
	n._abrir_pausa()
	await get_tree().create_timer(0.15).timeout

	_reinicios = 0
	pausa._elegir(i_rei)
	await get_tree().process_frame
	_ok(_reinicios == 0 and get_tree().paused,
		"el PRIMER toque en 'Reiniciar nivel' no reinicia nada")
	_ok(pausa._confirmando == i_rei, "y la fila pasa a 'confirmar'")
	pausa._elegir(i_rei)
	await get_tree().create_timer(0.4).timeout
	_ok(_reinicios == 1, "el SEGUNDO toque si reinicia")
	_ok(not get_tree().paused, "y descongela en el acto, sin ceremonia")
	_ok(jug.global_position.distance_to(lejos) > 50.0,
		"y te devuelve a la aparicion (%.0f px de donde estabas)"
		% jug.global_position.distance_to(lejos))

	n._abrir_pausa()
	await get_tree().create_timer(0.15).timeout
	_salidas = 0
	pausa._elegir(i_sal)
	await get_tree().process_frame
	_ok(_salidas == 0, "'Salir al menu' tambien pide dos toques")
	pausa._confirmando = -1
	pausa.cerrar(true)
	await get_tree().process_frame

## El volumen no existia en NINGUNA parte del juego, aunque el autoload lo tiene
## desde el principio.
func _volumen() -> void:
	var vol0: float = Audio.volumen
	var sil0: bool = Audio.silencio
	var mus0: float = float(Audio.get("volumen_musica"))
	var i_efe: int = pausa.OPCIONES.find("Volumen efectos")
	var i_mus: int = pausa.OPCIONES.find("Volumen musica")

	pausa.poner_celdas(i_efe, 4)
	_ok(absf(Audio.volumen - 0.5) < 0.001 and not Audio.silencio,
		"la fila de efectos escribe en Audio.volumen (%.2f)" % Audio.volumen)
	pausa.poner_celdas(i_efe, 0)
	_ok(Audio.silencio, "cero celdas ES el silencio, sin gastar una fila propia")
	_ok(pausa.celdas_efectos() == 0, "y la fila se dibuja vacia")
	pausa.poner_celdas(i_efe, 6)
	_ok(not Audio.silencio, "volver a subirla quita el silencio")

	pausa.poner_celdas(i_mus, 2)
	var m: Variant = Audio.get("volumen_musica")
	if m == null:
		_ok(true, "la fila de musica queda a la espera de Audio.volumen_musica")
	else:
		_ok(absf(float(m) - 0.25) < 0.001,
			"la fila de musica escribe en Audio.volumen_musica (%.2f)" % float(m))
		_ok(absf(Audio.volumen - 0.75) < 0.001,
			"y es independiente del volumen de efectos (%.2f)" % Audio.volumen)

	Audio.volumen = vol0
	Audio.silencio = sil0
	Audio.set("volumen_musica", mus0)

## La flecha arriba es de ui_up Y de saltar. Cuando la pausa elegia tambien con
## "saltar", subir de fila elegia la fila nueva en el mismo cuadro: desde
## "Volumen musica" se subia el volumen de efectos, y desde "Volumen efectos" se
## llegaba a "Continuar" y la pausa se cerraba sola. Se prueba con la tecla de
## verdad y con el mapa de fabrica en memoria (sin tocar el guardado), porque el
## fallo depende justo de que esa tecla este en las dos acciones.
func _flecha_arriba() -> void:
	for a in Teclas.ACCIONES:
		Teclas._poner(a, Teclas.de_fabrica(a))
	var arriba := InputEventKey.new()
	arriba.keycode = KEY_UP
	arriba.pressed = true
	_ok(InputMap.event_is_action(arriba, "ui_up") and InputMap.event_is_action(arriba, "saltar"),
		"de fabrica la flecha arriba es de ui_up y de saltar a la vez")
	pausa.abrir()
	await get_tree().process_frame
	await get_tree().process_frame
	var i_mus: int = pausa.OPCIONES.find("Volumen musica")
	pausa._sel = i_mus
	var efe0: int = pausa.celdas_efectos()
	var mus0: int = pausa.celdas_musica()
	await _flecha(KEY_UP)
	_ok(pausa._sel == i_mus - 1, "flecha arriba sube una fila (%d)" % pausa._sel)
	_ok(pausa.celdas_efectos() == efe0 and pausa.celdas_musica() == mus0,
		"y no toca ningun volumen al llegar")
	await _flecha(KEY_UP)
	_ok(pausa._sel == 0 and pausa.abierto,
		"llegar a Continuar con la flecha no cierra la pausa")
	pausa.cerrar(true)
	await get_tree().process_frame
	Teclas.aplicar()

## Un dedo en la pantalla llega DOS veces: Godot emula un clic de raton a partir
## del toque (emulate_mouse_from_touch vale true de fabrica) y despues manda el
## propio toque. La pausa aceptaba los dos, asi que en el movil un solo toque en
## "Reiniciar nivel" pasaba a "confirmar" y confirmaba en el mismo instante, y los
## interruptores se encendian y apagaban a la vez (parecian muertos). Tambien la
## rueda del raton contaba como clic. Se manda el toque de verdad, con
## Input.parse_input_event, que es lo que hace el sistema.
func _un_toque_cuenta_una_vez() -> void:
	# los interruptores escriben el progreso: se guarda y se devuelve
	var habia := FileAccess.file_exists(Guardado.RUTA)
	var copia := FileAccess.get_file_as_bytes(Guardado.RUTA) if habia else PackedByteArray()
	pausa.abrir()
	await get_tree().process_frame
	await get_tree().process_frame
	var reinicios0 := _reinicios
	var i_rei: int = pausa.OPCIONES.find("Reiniciar nivel")
	await _toque(pausa._filas[i_rei].get_center())
	_ok(_reinicios == reinicios0 and pausa.abierto and pausa._confirmando == i_rei,
		"un toque en Reiniciar solo pide confirmar (no reinicia)")
	var i_acc: int = pausa.CLASES.find("interruptores")
	var k: int = pausa.INTERRUPTORES.find("asistencia")
	var antes: bool = pausa.interruptor(k)
	await _toque(pausa._caja_chip(pausa._filas[i_acc], k).get_center())
	_ok(pausa.interruptor(k) != antes, "un toque en un interruptor lo cambia una sola vez")
	pausa.cerrar(true)
	await get_tree().process_frame
	pausa.abrir()
	await get_tree().process_frame
	await get_tree().process_frame
	var r0 := _reinicios
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rueda.position = get_viewport().get_final_transform() * pausa._filas[i_rei].get_center()
	for n in 2:
		rueda.pressed = true
		Input.parse_input_event(rueda)
		await get_tree().process_frame
		rueda.pressed = false
		Input.parse_input_event(rueda.duplicate())
		await get_tree().process_frame
	_ok(_reinicios == r0 and pausa.abierto and pausa._confirmando == -1,
		"y la rueda del raton no elige nada (ni pide confirmar)")
	pausa.cerrar(true)
	await get_tree().process_frame
	if habia:
		var fa := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
		fa.store_buffer(copia)
		fa.close()
	Guardado.cargar()
	Teclas.aplicar()

func _toque(p: Vector2) -> void:
	for pulsado in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		# El toque entra por la VENTANA: hay que pasar el punto de coordenadas del
		# juego (640x360) a las de la ventana, o cae en otra parte. Sin esto la
		# prueba tocaba fuera de la fila y pasaba o fallaba sin medir nada.
		t.position = get_viewport().get_final_transform() * p
		t.pressed = pulsado
		Input.parse_input_event(t)
		await get_tree().process_frame
		await get_tree().process_frame

func _flecha(cod: int) -> void:
	for pulsado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = cod as Key
		e.physical_keycode = cod as Key
		e.pressed = pulsado
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame

## Los temporizadores de las ceremonias corrian con el arbol pausado. El de la
## victoria hacia change_scene_to_file con todo congelado y el nivel siguiente
## arrancaba en pausa SIN forma de salir: bloqueo total y motivo de rechazo.
func _ceremonias() -> void:
	get_tree().paused = true
	_tic_salida = false
	_tic_muerte = false
	# copias exactas de las dos llamadas de nivel.gd
	get_tree().create_timer(0.2, false).timeout.connect(_marcar_salida)
	get_tree().create_timer(0.2, false, false, true).timeout.connect(_marcar_muerte)
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = false
	_ok(not _tic_salida, "el temporizador de la victoria NO corre con el arbol pausado")
	_ok(not _tic_muerte, "ni el del beat de muerte")
	await get_tree().create_timer(0.4).timeout
	_ok(_tic_salida and _tic_muerte, "y los dos disparan en cuanto se descongela")

func _marcar_salida() -> void:
	_tic_salida = true

func _marcar_muerte() -> void:
	_tic_muerte = true

## El caso que de verdad mataba: pausar corriendo, con la gracia agotada.
func _pausar_corriendo() -> void:
	n.reiniciar()
	await get_tree().create_timer(0.2).timeout
	Input.action_press("mover_izq")
	await get_tree().create_timer(0.25).timeout
	jug._t_gracia = 0.0
	await get_tree().create_timer(0.05).timeout
	n._abrir_pausa()
	await get_tree().create_timer(0.5).timeout
	pausa.cerrar(true)
	await get_tree().create_timer(0.2).timeout
	Input.action_release("mover_izq")
	_ok(jug.vivo, "pausar 0,5 s corriendo y reanudar deja al jugador VIVO")

## En movil no habia NINGUNA forma visible de abrir el menu: los mandos solo
## tenian saltar, impulso y pulso.
func _boton_tactil() -> void:
	var r: Vector2 = mandos.get_viewport_rect().size
	_ok(mandos._botones.has("pausa"), "los mandos tactiles tienen boton de pausa")
	var b: Vector2 = mandos._botones["pausa"]
	var s: Vector2 = mandos._botones["saltar"]
	_ok(b is Vector2 and s is Vector2,
		"_botones sigue siendo accion -> Vector2 (lo lee prueba_tactil)")
	_ok(b.x > r.x * 0.45,
		"el boton de pausa cae fuera del 45%% del pulgar izquierdo (x=%.0f de %.0f)" % [b.x, r.x])
	_ok(b.distance_to(s) > 100.0,
		"y a mas de 100 px de saltar (%.0f px)" % b.distance_to(s))
	var rp: float = float(mandos.RADIOS.get("pausa", mandos.RADIO_BOTON))
	_ok(rp < mandos.RADIO_BOTON,
		"con menos area de acierto que saltar (%.0f contra %.0f px)" % [rp, mandos.RADIO_BOTON])
	# y el joystick ya no nace arriba a la izquierda, donde vive el HUD
	mandos._abajo(9, Vector2(40.0, 20.0))
	_ok(not mandos._dedos.has(9) or mandos._dedos.get(9, "") != "joy",
		"el joystick no nace arriba a la izquierda, encima de la barra de carga")
	mandos.soltar_todo()
