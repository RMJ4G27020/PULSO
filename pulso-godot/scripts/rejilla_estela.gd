class_name RejillaEstela
extends Node2D
## La estela como rejilla de marcas de tiempo, no como objetos.
## Una celda guarda el instante en que TSL-04 la piso; morir es leer un numero.
## Lo visual va aparte: laminas renderizadas en Blender mas una cinta continua.

const CELDA := 16
const DURACION := 3.0     ## segundos que la celda mata
const RETARDO := 0.35     ## margen antes de encenderse: por eso correr es seguro y pararse no
## Modo asistencia: el doble. 0,35 s esta por debajo del tiempo de reaccion de
## una eleccion (0,4-0,5 s en adultos), asi que el juego exige anticiparse, no
## reaccionar. 0,70 s da UNA reaccion completa de margen a quien la necesite,
## y pararse sigue siendo un error: la celda sigue matando, solo que despues.
const RETARDO_ASISTIDO := 0.70
## El que manda de verdad. RETARDO se queda como constante porque hay pruebas
## que la leen como referencia del juego normal.
var retardo := RETARDO
## Los del personaje (scripts/personajes.gd): TSL-01 se enciende a los 0,55 s y
## dura 5; TSL-03 se enciende a los 0,28. La asistencia DOBLA el de cada uno, que
## con TSL-04 da los 0,70 de siempre.
var retardo_base := RETARDO
var duracion := DURACION
var hojas_estela := "res://arte/estela/estela_spriteframes.tres"
const AVISO := 0.4        ## parpadeo final antes de apagarse
const APAGADO := 0.35     ## se sigue dibujando un poco despues de dejar de matar

## El sprite cubre 32 px de juego para una celda de 16, y la barra de suelo
## queda 9.6 px por debajo de su centro (asi se modelo en Blender).
const SPR := 32.0
const DESVIO_Y := 25.6

@export var color_cinta := Color(0.21, 0.85, 1.0)

## Reloj propio, no Time.get_ticks_msec(): el de pared sigue corriendo con el
## arbol pausado, asi que pausar envejecia la celda que pisas y al reanudar la
## estela te mataba. Como este nodo es PAUSABLE, en pausa el reloj se queda
## quieto. De regalo, con time_scale 0 (el hitstop de la muerte) delta es 0 y
## la estela tambien se congela, y la misma partida repetida da la misma
## secuencia de celdas: el reloj de pared no permitia eso.
var reloj := 0.0

var _marcas: Dictionary = {}          ## Vector2i -> segundos
var _camino: Array = []               ## [[Vector2i, segundos]] en orden de pisada
var _tierra: Dictionary = {}          ## celdas conectadas a tierra: ahi no prende
var _sf: SpriteFrames

func _ready() -> void:
	# cada nivel monta su rejilla, asi que aqui se recogen el personaje y el
	# ajuste guardado
	Personajes.aplicar_rejilla(self)
	poner_asistencia(bool(Guardado.opcion("asistencia", false)))
	_sf = load(hojas_estela)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD    # el resplandor suma, no tapa
	material = m

func celda_de(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELDA), floori(pos.y / CELDA))

## Una zona con toma de tierra descarga el pulso: la estela no se enciende
## encima. Lo usa la terminal, el unico sitio donde el nivel te pide pararte.
func tomar_tierra(zona: Rect2) -> void:
	var a := celda_de(zona.position)
	var b := celda_de(zona.end)
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			_tierra[c] = true
			_marcas.erase(c)

func marcar(celda: Vector2i, ahora: float) -> void:
	if _tierra.has(celda):
		return
	_marcas[celda] = ahora
	_camino.append([celda, ahora])

func tiene(celda: Vector2i) -> bool:
	return _marcas.has(celda)

## Para el HUD: cuanto lleva marcada la celda. -1.0 si no lo esta.
func edad_de(celda: Vector2i) -> float:
	if not _marcas.has(celda):
		return -1.0
	return reloj - float(_marcas[celda])

## Toma de tierra: ahi si se puede parar, y el aviso de quietud NO debe saltar.
func en_tierra(celda: Vector2i) -> bool:
	return _tierra.has(celda)

## Tambien se llama con el nivel en marcha, desde la pausa: la rejilla viva
## tiene que enterarse sin reiniciar.
func poner_asistencia(activa: bool) -> void:
	retardo = retardo_base * (RETARDO_ASISTIDO / RETARDO if activa else 1.0)
	queue_redraw()

func mata(celda: Vector2i, ahora: float) -> bool:
	if _tierra.has(celda) or not _marcas.has(celda):
		return false
	var edad: float = ahora - float(_marcas[celda])
	return edad >= retardo and edad < duracion

func limpiar() -> void:
	_marcas.clear()
	_camino.clear()
	queue_redraw()

func purgar(ahora: float) -> void:
	for c in _marcas.keys():
		if ahora - float(_marcas[c]) >= duracion + APAGADO:
			_marcas.erase(c)
	while _camino.size() > 0 and ahora - float(_camino[0][1]) >= duracion + APAGADO:
		_camino.pop_front()

func _process(delta: float) -> void:
	reloj += delta
	queue_redraw()

func _estado(edad: float) -> Array:
	## que lamina toca segun la edad de la celda
	if edad < retardo:
		# La animacion de encendido se ESTIRA al retardo efectivo: sus 4 cuadros
		# ocupan la misma proporcion del retardo con TSL-04, con TSL-01 y con la
		# asistencia. Es la del juego normal (4 cuadros a 24 por segundo, o sea el
		# 36 % del retardo de 0,35 s), y el ultimo se queda quieto hasta que
		# empieza "activa", que es cuando de verdad mata. Es un aviso por exceso:
		# la celda se ve encendida un poco ANTES de matar, nunca despues.
		return ["encendido", int(edad / retardo * RETARDO * 24.0)]
	if edad < duracion - AVISO:
		return ["activa", int((edad - retardo) * 12.0)]
	if edad < duracion:
		return ["aviso", int((edad - (duracion - AVISO)) * 15.0)]
	return ["apagado", int((edad - duracion) * 20.0)]

func _draw() -> void:
	var ahora := reloj
	# 1. la cinta: une las celdas para que se lea como un trazo y no como cuadros sueltos
	if _camino.size() > 1:
		for i in range(1, _camino.size()):
			var edad: float = ahora - float(_camino[i][1])
			if edad >= duracion + APAGADO:
				continue
			var a: Vector2 = Vector2(_camino[i - 1][0]) * CELDA + Vector2(CELDA, 2) * 0.5
			var b: Vector2 = Vector2(_camino[i][0]) * CELDA + Vector2(CELDA, 2) * 0.5
			if a.distance_to(b) > CELDA * 3:      # saltos y caidas no dejan cinta
				continue
			var f: float = 1.0 - clampf(edad / duracion, 0.0, 1.0)
			var col := color_cinta
			col.a = 0.10 + 0.45 * f
			draw_line(a, b, col, 3.0 + 4.0 * f)
	# 2. las laminas de Blender, una por celda
	if _sf == null:
		return
	for c in _marcas:
		var edad: float = ahora - float(_marcas[c])
		if edad >= duracion + APAGADO:
			continue
		var e := _estado(edad)
		var nom: String = e[0]
		var n := _sf.get_frame_count(nom)
		if n == 0:
			continue
		var tex := _sf.get_frame_texture(nom, clampi(int(e[1]), 0, n - 1) % n)
		if tex == null:
			continue
		var p := Vector2(c.x * CELDA + CELDA * 0.5 - SPR * 0.5, c.y * CELDA - DESVIO_Y)
		draw_texture_rect(tex, Rect2(p, Vector2(SPR, SPR)), false)
