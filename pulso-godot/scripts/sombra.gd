extends Node2D
## Sombra de contacto de TSL-04.
##
## El personaje ya se renderiza con volumen, pero seguia FLOTANDO: nada en
## pantalla lo relacionaba con el suelo. La sombra de contacto es la senal de
## profundidad mas barata que existe, y aqui hace tres cosas a la vez: dice
## donde esta el suelo, dice a que altura va el personaje, y en el aire anticipa
## donde va a caer, que en un juego donde pararse mata es informacion util.
##
## Va como hijo de Jugador y ANTES que Sprite en la escena. No hay z_index en
## todo el proyecto: el orden de dibujo es el del arbol, asi que colocada ahi
## queda detras del personaje y delante de las plataformas sin tocar nada mas.
## Y no usa top_level: con eso deja de dibujarse dentro del orden del padre y
## podria acabar delante del sprite.

## Por encima de esto no hay sombra. El salto es de 115 px: a 150 la sombra
## sigue viva en la cima de un salto desde el suelo, que es cuando mas sirve
## para saber donde vas a caer, y se apaga antes de parecer una mancha suelta
## en el suelo de otra plataforma.
const ALTURA_MAX := 150.0
const PIES := 14.0                ## radio de la colision: los pies, desde el centro
const ANCHO := 13.0               ## semieje horizontal en el suelo (cuerpo de ~32 px)
const APLASTADO := 0.30           ## semieje vertical / horizontal: vista rasante
const ESCALA_ALTA := 0.42         ## lo que encoge en el limite de altura
## Sobre la placa base casi negra una sombra negra es invisible. Pero no cae
## sobre la placa: cae sobre el CANTO de la plataforma, que lleva una tira cian
## encendida (la marca de "aqui se pisa"). Tapar esa tira es lo que se lee, asi
## que basta un negro azulado con bastante opacidad.
const TINTE := Color(0.0, 0.02, 0.05)
const ALFA_MAX := 0.62

## Estado publico para las pruebas: lo que se dibujo en el ultimo cuadro.
var altura := -1.0                ## px entre los pies y el suelo; -1 sin suelo
var escala := 0.0
var alfa := 0.0

var _jugador: CharacterBody2D


func _ready() -> void:
	_jugador = get_parent() as CharacterBody2D


func _physics_process(_delta: float) -> void:
	# el espacio fisico solo se consulta con seguridad desde aqui
	altura = _medir_altura()
	if _jugador == null or not _jugador.vivo or altura < 0.0:
		escala = 0.0
		alfa = 0.0
	else:
		var t: float = clampf(altura / ALTURA_MAX, 0.0, 1.0)
		escala = lerpf(1.0, ESCALA_ALTA, t)
		# Se apaga mas deprisa de lo que encoge (a media altura ha perdido la
		# mitad de opacidad y solo un 29% de tamano): una sombra grande y palida
		# se lee como una mancha, una pequena y palida como distancia. Lineal y
		# no cuadratica: con el cuadrado quedaba a alfa 0,03 en la cima de un
		# salto, que es invisible justo cuando mas sirve para saber donde caes.
		alfa = ALFA_MAX * (1.0 - t)
	# en el suelo, justo bajo los pies. El padre solo se traslada, asi que el
	# desfase local es el desfase en el mundo
	position = Vector2(0.0, PIES + maxf(altura, 0.0))
	queue_redraw()


func _medir_altura() -> float:
	if _jugador == null:
		return -1.0
	var pies: Vector2 = _jugador.global_position + Vector2(0.0, PIES)
	var q := PhysicsRayQueryParameters2D.create(pies + Vector2(0.0, -2.0),
		pies + Vector2(0.0, ALTURA_MAX))
	q.exclude = [_jugador.get_rid()]
	var hit: Dictionary = _jugador.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1.0                # sobre el vacio no hay nada donde proyectar
	return maxf(float((hit["position"] as Vector2).y) - pies.y, 0.0)


func _draw() -> void:
	if alfa <= 0.004:
		return
	# tres elipses concentricas: un borde suave cuesta lo mismo que uno duro y
	# no parece una pegatina. Se aplasta con la transformacion de dibujo porque
	# draw_circle no admite radios distintos.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, APLASTADO))
	var r: float = ANCHO * escala
	draw_circle(Vector2.ZERO, r * 1.35, Color(TINTE, alfa * 0.30))
	draw_circle(Vector2.ZERO, r * 1.10, Color(TINTE, alfa * 0.45))
	draw_circle(Vector2.ZERO, r * 0.80, Color(TINTE, alfa * 0.70))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
