extends Node2D
## Une interruptor -> puerta -> portal, reinicia al morir y encadena los niveles.

## orden de juego. El numero del titulo es la posicion aqui, no la del GDD.
const ORDEN := [
	"res://escenas/niveles/n1_ida_y_vuelta.tscn",
	"res://escenas/niveles/n2_el_corredor.tscn",
	"res://escenas/niveles/n3_el_nudo.tscn",
	"res://escenas/niveles/n4_la_chimenea.tscn",
	"res://escenas/niveles/n5_lasermania.tscn",
	"res://escenas/niveles/n6_runthedrun.tscn",
]
## Al pasar el ultimo nivel, el juego vuelve al menu.
const MENU := "res://escenas/MenuPrincipal.tscn"
## El final de la historia va despues del TERCER nivel (indice 2 en ORDEN), y de
## ahi el juego sigue en el cuarto. La cinematica se inserta en la cadena, no la
## sustituye: nada se salta y nada se solapa.
const CINE_FINAL := "res://escenas/CineFinal.tscn"
const NIVEL_DEL_FINAL := 2
const PAUSA := "res://escenas/Pausa.tscn"
const TACTIL := "res://escenas/Tactil.tscn"
const HUD := "res://escenas/Hud.tscn"
const FUNDIDO := "res://escenas/Fundido.tscn"

@export var titulo := ""
@export var par := 0.0
@export var limite_caida := 0.0        ## por debajo de esta y es el vacio

## Beat de muerte: sin el, los peligros te rematan en bucle antes de reaccionar.
const PAUSA_MUERTE := 0.85

var _tiempo := 0.0
var _muertes := 0
var _terminado := false
var _fragmentos_tomados := 0
## Donde se reaparece al morir si ya se ha pisado una baliza (Vector2.INF: ninguna,
## y se reaparece en el anclaje con el nivel reiniciado entero, como siempre).
var _punto_control := Vector2.INF
var _t_aviso_baliza := 0.0
const AVISO_BALIZA := 1.6

@onready var _jugador: CharacterBody2D = $Jugador
@onready var _aparicion: Marker2D = $Aparicion
@onready var _anclaje: Node2D = get_node_or_null("Anclaje")
@onready var _puerta: StaticBody2D = get_node_or_null("Puerta")
@onready var _inter: Area2D = get_node_or_null("Interruptor")
@onready var _fragmentos: Node2D = get_node_or_null("Fragmentos")

var _pausa: Control
var _mandos: Control
var _hud: Control
var _capa_hud: CanvasLayer
var _capa_mandos: CanvasLayer
var _fundido: CanvasLayer

func _ready() -> void:
	_jugador.murio.connect(_al_morir)
	_jugador.carga_cambiada.connect(_al_cambiar_carga)
	var sal := get_node_or_null("Salida")
	if sal:
		sal.alcanzado.connect(_al_salir)
	if _inter:
		_inter.activado.connect(_al_activar)
	if _fragmentos:
		for f in _fragmentos.get_children():
			(f as Area2D).body_entered.connect(_al_fragmento.bind(f))
	for pel in get_tree().get_nodes_in_group("peligro"):
		(pel as Area2D).body_entered.connect(_al_peligro)
	for b in get_tree().get_nodes_in_group("baliza"):
		b.activada.connect(_al_baliza.bind(b))
	_montar_hud()
	_montar_fundido()
	_montar_pausa()
	_montar_mandos()
	# el menu tapa lo que haya debajo: con el HUD encendido, el cronometro se
	# leia mejor que las propias opciones
	_pausa.hud = _capa_hud
	_pausa.mandos = _capa_mandos
	# El jugador no traia linea "position" en ningun .tscn a mano y nadie lo
	# colocaba al entrar: nacia en (0,0), a 200-641 px de la aparicion, y caia
	# desde la esquina superior izquierda con animacion de "caida". reiniciar()
	# lo pone en su sitio, le devuelve la carga y reproduce "aparicion", que
	# hasta ahora no se veia NUNCA al empezar un nivel. Va despues del HUD
	# porque reiniciar() emite carga_cambiada y el HUD tiene que existir ya.
	reiniciar()
	if _hud:
		_hud.reiniciar_animacion()
	_fundido.desde_negro(0.35)
	# el mismo tema que el menu: poner_musica no reinicia si ya suena ese, asi
	# que entrar en un nivel no corta la musica
	if Audio.has_method("poner_musica"):
		Audio.poner_musica("circuito")

func _montar_hud() -> void:
	var esc: Node = load(HUD).instantiate()
	add_child(esc)
	_capa_hud = esc as CanvasLayer
	_hud = esc.get_node("Panel")
	_hud.enlazar(_jugador, get_tree().get_first_node_in_group("estela"))

func _montar_fundido() -> void:
	var esc: Node = load(FUNDIDO).instantiate()
	add_child(esc)
	_fundido = esc as CanvasLayer

func _montar_pausa() -> void:
	var esc: Node = load(PAUSA).instantiate()
	add_child(esc)
	_pausa = esc.get_node("Menu")
	_pausa.continuar.connect(_al_continuar)
	_pausa.reiniciar.connect(func(): _al_continuar(); reiniciar())
	_pausa.salir.connect(func():
		Guardado.guardar()
		get_tree().change_scene_to_file(MENU))

## Los mandos solo si hay pantalla tactil: en un escritorio estorban.
func _montar_mandos() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	var esc: Node = load(TACTIL).instantiate()
	add_child(esc)
	_capa_mandos = esc as CanvasLayer
	_mandos = esc.get_node("Mandos")
	# el boton de pausa tactil no puede ir por Input.action_press: eso no genera
	# ningun evento, y la pausa se abre desde _unhandled_input
	_mandos.pauso.connect(_abrir_pausa)

func _al_continuar() -> void:
	# soltar los dedos al reanudar, o el personaje sale corriendo solo
	if _mandos:
		_mandos.soltar_todo()

## El boton atras de Android tiene que pausar, no cerrar la aplicacion.
func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_GO_BACK_REQUEST and _pausa:
		if _pausa.abierto: _al_continuar(); _pausa.cerrar()
		else: _abrir_pausa()

## Abrir el menu NO puede borrar el nivel. Antes llamaba a reiniciar(), asi que
## pulsar Esc te dejaba sin cronometro, sin fragmentos y con la puerta cerrada.
func _abrir_pausa() -> void:
	# Durante la ceremonia de salida (1,5 s) no hay pausa. Con el arbol parado,
	# sus temporizadores se congelaban: abierta durante el fundido, la pausa
	# quedaba DEBAJO del negro y la pantalla se quedaba negra sin salida; y
	# "Reiniciar nivel" no servia de nada, porque al cerrarla la ceremonia
	# seguia y cargaba el nivel siguiente igual. Es el momento mas quieto del
	# juego y dura un suspiro: no hay nada que pausar.
	if _terminado:
		return
	if _mandos:
		_mandos.soltar_todo()
	_pausa.abrir()

func _process(delta: float) -> void:
	_t_aviso_baliza = maxf(_t_aviso_baliza - delta, 0.0)
	if _jugador.vivo and not _terminado:
		_tiempo += delta
	if limite_caida > 0.0 and _jugador.vivo and _jugador.global_position.y > limite_caida:
		_jugador.morir()
	_pintar_hud()
	# Durante la ceremonia de salida no se reinicia, por lo mismo que no se pausa
	# (_abrir_pausa): la ceremonia seguia, cargaba el nivel siguiente igual, y con
	# _terminado devuelto a false la pausa podia abrirse debajo del negro.
	if Input.is_action_just_pressed("reiniciar") and not _terminado:
		reiniciar()

## La tecla de pausa se lee aqui y se marca como atendida. Leyendola en _process
## el menu se abria y se cerraba en el MISMO cuadro: nivel.gd (padre) abria y
## pausa.gd (hijo) veia la misma pulsacion y elegia "Continuar".
func _unhandled_input(e: InputEvent) -> void:
	if _pausa and not _pausa.abierto and e.is_action_pressed("pausa"):
		_abrir_pausa()
		get_viewport().set_input_as_handled()

## Reinicio COMPLETO: vuelve al anclaje con todo como al empezar (la tecla de
## reiniciar y "Reiniciar nivel" de la pausa). Morir en un nivel con balizas no
## pasa por aqui sino por reaparecer().
func reiniciar() -> void:
	_tiempo = 0.0
	_terminado = false
	_fragmentos_tomados = 0
	_punto_control = Vector2.INF
	_t_aviso_baliza = 0.0
	for b in get_tree().get_nodes_in_group("baliza"):
		b.reiniciar()
	if _puerta:
		_puerta.cerrar()
	if _inter:
		_inter.reiniciar()
	if _fragmentos:
		for f in _fragmentos.get_children():
			f.visible = true
			f.set_deferred("monitoring", true)
	# primero el jugador: si no, los peligros se reinician viendolo todavia
	# tirado donde murio y vuelven a activarse en el acto
	_jugador.reiniciar(_aparicion.global_position)
	# y luego los peligros, a su pose de partida: si no, el dron te espera
	# en alerta justo donde te acorralo y te remata al aparecer
	for pel in get_tree().get_nodes_in_group("peligro"):
		if pel.has_method("reiniciar"):
			pel.reiniciar()
	if _anclaje and _anclaje.has_method("activar"):
		_anclaje.activar()

func _al_activar() -> void:
	if _puerta:
		_puerta.abrir()
	_jugador.cargar(15.0)

func _al_morir() -> void:
	_muertes += 1
	Guardado.sumar_muerte()
	# en tiempo real: durante la congelacion de los efectos time_scale vale 0
	await get_tree().create_timer(PAUSA_MUERTE, false, false, true).timeout
	# Si en esa pausa se reinicio el nivel (R o "Reiniciar nivel"), el jugador ya
	# esta vivo en el anclaje: reaparecer ahora lo devolveria atras otra vez.
	if _jugador.vivo:
		return
	reaparecer()

## Sin balizas pisadas, morir es volver a empezar el nivel, como siempre. Con
## una, se reaparece en la ultima: con la carga a tope y los peligros en su pose
## de partida, pero SIN deshacer lo hecho (fragmentos cogidos, terminal, puerta)
## ni parar el cronometro: las muertes cuestan tiempo.
func reaparecer() -> void:
	if _punto_control == Vector2.INF:
		reiniciar()
		return
	# primero el jugador, por lo mismo que en reiniciar()
	_jugador.reiniciar(_punto_control)
	for pel in get_tree().get_nodes_in_group("peligro"):
		if pel.has_method("reiniciar"):
			pel.reiniciar()

func _al_baliza(b: Node) -> void:
	_punto_control = b.punto_aparicion()
	_t_aviso_baliza = AVISO_BALIZA
	_jugador.cargar(b.carga_devuelta)

## El HUD de un movil se mira de reojo: pocas palabras, cifras que no bailan y
## nada permanente que se pueda contar de un vistazo con simbolos. Aqui solo se
## decide QUE hay que decir; el COMO lo resuelve scripts/hud.gd de una pieza.
func _pintar_hud() -> void:
	if _hud == null:
		return
	var total: int = _fragmentos.get_child_count() if _fragmentos else 0

	# el estado solo dice lo que hace falta AHORA. Ya no dice "pulsa E":
	# la terminal se acciona sola desde que se quito el boton en tactil.
	var estado := ""
	if _terminado:
		estado = "salida alcanzada"
	elif not _jugador.vivo:
		estado = ""
	elif _t_aviso_baliza > 0.0:
		estado = "punto de control"
	elif _puerta and _puerta.abierta:
		# "->" y no U+2192: la fuente del proyecto no tiene la flecha (has_char
		# false) y en Android saldria un tofu. En macOS se ve porque el sistema
		# presta el glifo, que es justo la trampa que se comio a los rombos.
		estado = "puerta abierta  ->  a la salida"
	elif _inter and _inter.en_rango():
		estado = "conectando\u2026"
	else:
		estado = "busca la terminal"

	var a_la_salida: bool = _puerta == null or _puerta.abierta
	_hud.actualizar(_tiempo, par, _jugador.carga, _fragmentos_tomados, total,
		estado, titulo, _muertes, _objetivo_actual(), a_la_salida)

## Interruptor -> Puerta -> Salida. Vector2.INF si el nivel no tiene ninguno:
## el chevron falla a invisible antes que apuntar al vacio.
func _objetivo_actual() -> Vector2:
	if _puerta and not _puerta.abierta and _inter:
		return _inter.global_position
	var sal: Node2D = get_node_or_null("Salida")
	if sal:
		return sal.global_position
	if _inter:
		return _inter.global_position
	return Vector2.INF

## La senal se conserva con la misma firma, pero el HUD ya no la necesita para
## pintar: lee la carga en actualizar() y de ahi deriva solo si la bajada fue
## fuga (el goteo del consumo) o maniobra (un impulso, un pulso).
func _al_cambiar_carga(_valor: float) -> void:
	pass

func _al_salir() -> void:
	if _terminado or (_puerta and not _puerta.abierta):
		return
	_terminado = true
	Audio.sonar("portal")
	var i := ORDEN.find(scene_file_path)
	if i >= 0:
		Guardado.completar_nivel(i + 1, _tiempo, _fragmentos_tomados)
	_jugador.celebrar()
	# la ceremonia dura lo mismo que antes (1,5 s): en PULSO pararse mata y este
	# ya es el momento mas quieto del juego, no se puede alargar
	await get_tree().create_timer(0.9, false).timeout
	if not _terminado:
		return
	_fundido.a_negro(0.5)
	# Hacia el final, "circuito" se apaga CON el fundido y en su mismo medio
	# segundo. El sonido del portal dura 0,90 s, asi que ya ha terminado cuando
	# esto empieza: portal, luego silencio con la pantalla en negro, luego el
	# tema del final. Entre niveles normales la musica sigue sin cortarse.
	if i == NIVEL_DEL_FINAL and Audio.has_method("parar_musica"):
		Audio.parar_musica(0.5)
	await get_tree().create_timer(0.6, false).timeout
	if not _terminado:
		return
	_siguiente(i)

## Encadena: los de ORDEN en su orden, con el final despues del tercero, y a
## partir del ultimo, el menu.
func _siguiente(i: int) -> void:
	if i == NIVEL_DEL_FINAL and ResourceLoader.exists(CINE_FINAL):
		get_tree().change_scene_to_file(CINE_FINAL)
		return
	if i >= 0 and i + 1 < ORDEN.size():
		get_tree().change_scene_to_file(ORDEN[i + 1])
		return
	Guardado.guardar()
	get_tree().change_scene_to_file(MENU)


func _al_fragmento(cuerpo: Node2D, area: Area2D) -> void:
	if not cuerpo.has_method("morir") or not area.visible:
		return
	area.visible = false
	area.set_deferred("monitoring", false)
	_fragmentos_tomados += 1
	# sube de tono con cada uno: se oye que estas progresando
	Audio.sonar("fragmento", float(_fragmentos_tomados - 1) * 2.0)
	_jugador.cargar(5.0)

func _al_peligro(cuerpo: Node2D) -> void:
	if cuerpo.has_method("morir"):
		cuerpo.morir()
