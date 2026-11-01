extends Node3D
## El fondo tridimensional del menu: el interior de la computadora, visto de
## verdad en 3D y no pintado.
##
## Por que 3D VIVO y no una hoja pre-renderizada en Blender como el resto del
## arte: porque lo que hace que algo se sienta tridimensional no es que este
## sombreado, es que RESPONDE. Un giro pre-renderizado es una animacion; una
## camara que se mueve cuando eliges otra opcion, y un toro cuya silueta cambia
## al girar, es volumen. Ademas no cuesta ni un byte de paquete: todo lo que hay
## aqui son primitivas de Godot construidas por codigo (y el personaje sale del
## mismo .blend generado que el resto del arte), asi que sigue cumpliendo la
## doctrina del proyecto de que nada se modela a mano.
##
## Quien esta en el centro es TSL-04, no una bola. Antes aqui habia una esfera
## azul lisa, y en la pantalla que presenta el juego no aparecia el personaje
## por ningun lado: lo que hace a TSL-04 reconocible no es el color, es la CARA.
## El que se carga es EL MODELO DE BLENDER, el mismo que renderiza los sprites
## del juego (tsl04/build_tsl04.py --glb). Reconstruirlo con primitivas aqui
## seria una copia, y una copia se separa del personaje de verdad en cuanto se
## toque una proporcion alla; ademas trae ya la boca, el rubor y los brillos de
## los ojos, que son lo que lo hace reconocible a tamano de icono.
##
## Lo que SI se hace por codigo es moverlo, porque en un menu el personaje tiene
## que mirarte y responder a lo que eliges, y eso no cabe en un ciclo grabado.
##
## Coste: 12 mallas del personaje (~2.300 triangulos, sin el Subdivision del
## cuerpo), anillo, 5 placas y 6 paquetes, y 2 luces. En GL Compatibility eso no
## se nota, que es el motivo de no meter ni sombras, ni resplandor de entorno,
## ni reflejos: en ese renderizador o no existen o se pagan caros, y el
## resplandor se consigue mas barato con material emisivo. El tope de dibujo por
## cuadro lo vigila prueba/ui.

const CIAN := Color(0.21, 0.85, 1.0)
const MAGENTA := Color(0.89, 0.29, 0.78)
const VOLT := Color(0.78, 0.95, 0.31)
const SUSTRATO := Color(0.042, 0.075, 0.070)

## Cuanto se desplaza la camara de una opcion a la siguiente. Es el gesto que
## vende la profundidad: al bajar por el menu, el mundo se mueve DETRAS del
## panel, y el paralaje entre las placas cercanas y las lejanas solo se puede
## leer como distancia.
const PASO_CAMARA := 0.42
const SUAVIZADO := 3.2            ## 1/s de la persecucion de la camara

## --- TSL-04 ------------------------------------------------------------------
const MODELO := "res://arte/tsl04/tsl04.glb"
const ESCALA := 1.35              ## el cuerpo mide 0,5 en Blender; aqui 0,68
## TSL-04 se ilumina APARTE del decorado, con su propio juego de luces y su capa
## de visibilidad. No es un capricho: el decorado son placas planas y grandes que
## piden una clave fuerte, y esa misma clave sobre una esfera brillante le come
## la mitad del cuerpo (paso con la version anterior: la cabeza salia blanca).
## El personaje lleva las proporciones que ya se midieron para los sprites en
## tsl04/build_tsl04.py: clave lateral fuerte, relleno frio a un tercio, y borde
## POR DEBAJO de la clave, que es lo que alli costo descubrir.
const CAPA_TSL := 2
const PARPADEO := 0.16            ## lo que tarda en cerrar y abrir
const MIRADA := 0.034             ## cuanto se desplaza el iris al seguir la mirada
## A donde mira: la fila elegida del panel, medida en fracciones de media
## pantalla desde el centro (positivo = hacia abajo). Sale de caja_fila() de
## menu.gd: el centro de la fila i cae en y = 157,2 + 51*i de 360 (panel en
## 0,345, margen 10, filas de 46 y huecos de 5). Si eso cambia alli, estos dos
## numeros cambian aqui; prueba/menu_tactil comprueba que siguen casando.
const FILA_PRIMERA := -0.1267
const FILA_PASO := 0.2833
## Las que valen de verdad: menu.gd las MIDE de sus filas (medir_filas) cada vez
## que cambia el tamano. Las constantes de arriba son solo el valor de partida
## para una pantalla 16:9, la de un movil.
var fila_primera := FILA_PRIMERA
var fila_paso := FILA_PASO
const DIST_PANEL := 3.2           ## a que distancia se pone el punto que mira
## Cuanto de la mirada hace la CABEZA. El resto lo hacen los ojos, que es como
## se mira de verdad: la cabeza se queda a medio camino y los ojos completan.
## A 1.0 la cara se giraba 42 grados y el jugador le veia el perfil.
const CABEZA := 0.65
const SIGUE := 6.0                ## 1/s con que la mirada alcanza la opcion
const POSE := 11.0                ## 1/s con que el cuerpo alcanza su pose
const ESPERA_MIRA := 7.0          ## sin tocar nada, te busca a ti
## La despedida: SALIR no se pulsa, se MANTIENE 3 s. Ese hueco de tres segundos
## es el unico sitio del menu donde el jugador esta haciendo algo largo y puede
## arrepentirse, asi que TSL-04 lo usa para despedirse: deja de mirar al menu y
## te busca a ti, agacha la cabeza sin dejar de mirarte (la cabeza baja y los
## ojos suben, que es la mirada de "no te vayas"), ladea, se encoge y se va
## apagando. No bloquea nada ni cambia lo que hace el boton; si sueltas, se
## deshace sola.
##
## Se probo antes negando con la cabeza y se quito: un "no" rapido se lee como
## enfado, y ademas el suavizado de la pose (11/s) se comia el gesto, que se
## quedaba en 0,09 rad. Triste y quieta se lee mucho mejor que agitada.
const ADIOS_AGACHA := 0.24        ## cuanto baja la cabeza
const ADIOS_LADEO := 0.26         ## y cuanto la ladea
const ADIOS_ENCOGE := 0.16        ## cuanto se encoge del todo
const ADIOS_APAGA := 0.45         ## cuanta luz propia pierde: se va quedando sin carga
const ADIOS_SIGUE := 8.0          ## 1/s con que entra y sale la despedida
## El importador de glTF cuelga la escena de una raiz con el nombre del archivo.
const RAMA_CARA := "TSL04/ctrl_cuerpo/ctrl_cara"

var _tsl: Node3D                  ## el personaje entero, tal cual sale de Blender
var _anillo: MeshInstance3D
var _clave_tsl: DirectionalLight3D  ## su luz principal: se baja al despedirse
var _ojos: Array[Node3D] = []     ## ojo_L y ojo_R: aplastarlos en Y es parpadear
var _mirada: Array = []           ## por ojo, [[pieza, su sitio de siempre], ...]
var _placas: Array[MeshInstance3D] = []
var _paquetes: Array[MeshInstance3D] = []
var _camara: Camera3D
var _t := 0.0
var _objetivo := 0.0              ## altura a la que quiere estar la camara
var _altura := 0.0                ## donde esta ahora
var _opcion := 0                  ## la fila que mira
var _t_reac := 99.0               ## desde cuando dura la reaccion
var _fuerza := 0.0                ## 1 al cambiar de opcion, mas al confirmar
var _espera := 0.0                ## sin tocar nada
var _mira := Vector3.ZERO         ## el punto al que mira ahora, suavizado
var _adios := 0.0                 ## 0 a 1, lo que lleva mantenido el boton SALIR
var _p_adios := 0.0               ## lo mismo, ya suavizado
var _p_giro := 0.0                ## la pose, ya suavizada
var _p_cabezada := 0.0
var _p_ladeo := 0.0
var _p_alto := 0.0
var _p_estira := 0.0
var _t_ojo := 0.0
var _prox_ojo := 2.0


func _ready() -> void:
	_montar_entorno()
	_montar_camara()
	_montar_luces()
	_montar_tsl04()
	_montar_anillo()
	_montar_placas()
	_montar_paquetes()


func _mat(color: Color, emision: float, rugosidad := 0.35,
		metalico := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = metalico
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	return m


func _montar_entorno() -> void:
	# Sin entorno propio la vista se borraba a NEGRO y las esquinas del menu no
	# eran del color del juego. Ademas el ambiente da el poco relleno que evita
	# que las placas de canto se hundan del todo; en GL Compatibility no hay
	# oclusion ni reflejos, asi que este es todo el rebote que va a haber.
	var ent := Environment.new()
	ent.background_mode = Environment.BG_COLOR
	ent.background_color = Color(0.031, 0.055, 0.086)
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.10, 0.20, 0.28)
	ent.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.name = "Entorno"
	we.environment = ent
	add_child(we)


func _montar_camara() -> void:
	_camara = Camera3D.new()
	_camara.name = "Camara"
	# perspectiva corta (35 mm equivalentes largos) para que el paralaje entre
	# las placas cercanas y las lejanas se note sin deformar el nucleo
	_camara.fov = 42.0
	_camara.position = Vector3(0.0, 0.0, 5.2)
	add_child(_camara)


func _montar_luces() -> void:
	# clave lateral, igual que en el personaje: la luz frontal aplana porque el
	# terminador se queda detras de la silueta y no cruza la cara visible
	var clave := DirectionalLight3D.new()
	clave.name = "Clave"
	clave.light_color = Color(0.86, 0.96, 1.0)
	clave.light_energy = 2.1
	clave.rotation_degrees = Vector3(-28.0, 52.0, 0.0)
	clave.light_cull_mask = _todas_menos_tsl()
	add_child(clave)

	# el borde magenta es el unico sitio donde entra ese color: separa el nucleo
	# del fondo sin tener que subir el contraste general
	var borde := OmniLight3D.new()
	borde.name = "Borde"
	borde.light_color = MAGENTA
	borde.light_energy = 2.6
	borde.omni_range = 7.0
	borde.position = Vector3(-2.4, 1.6, -1.8)
	borde.light_cull_mask = _todas_menos_tsl()
	add_child(borde)


## Todas las capas de visibilidad menos la del personaje.
func _todas_menos_tsl() -> int:
	return 0xFFFFF & ~(1 << (CAPA_TSL - 1))


func _montar_luces_tsl() -> void:
	# Clave lateral y no frontal, la misma leccion que en Blender: de frente el
	# terminador se queda detras de la silueta y no cruza la cara visible, asi
	# que la esfera sale como un circulo de color liso.
	_clave_tsl = DirectionalLight3D.new()
	var clave := _clave_tsl
	clave.name = "ClaveTsl"
	clave.light_color = Color(1.0, 0.97, 0.92)
	clave.light_energy = 1.45
	clave.rotation_degrees = Vector3(-24.0, 38.0, 0.0)
	# Especular bajo. El cuerpo es una esfera casi pulida y una luz direccional
	# es un punto en el infinito: el reflejo sale como una quemadura blanca del
	# tamano de una moneda. En Blender el mismo brillo lo da un area de 1,2 m,
	# que no cabe aqui, asi que se baja el especular en vez de raspar el material.
	clave.light_specular = 0.28
	clave.light_cull_mask = 1 << (CAPA_TSL - 1)
	add_child(clave)

	# Relleno frio: sin el, el lado en sombra se hunde a casi negro y el
	# personaje pierde el color justo donde mas silueta tiene.
	var relleno := DirectionalLight3D.new()
	relleno.name = "RellenoTsl"
	relleno.light_color = Color(0.62, 0.82, 1.0)
	relleno.light_energy = 0.55
	relleno.rotation_degrees = Vector3(-6.0, -58.0, 0.0)
	relleno.light_cull_mask = 1 << (CAPA_TSL - 1)
	add_child(relleno)

	# Borde por detras, para despegarlo del fondo. Por debajo de la clave: el
	# borde describe la silueta, que ya se lee sola contra un fondo oscuro, y la
	# clave describe la FORMA, que es lo que hay que contar.
	var borde := OmniLight3D.new()
	borde.name = "BordeTsl"
	borde.light_color = Color(0.55, 0.98, 1.0)
	borde.light_energy = 1.1
	borde.omni_range = 3.4
	borde.position = Vector3(-2.9, 0.9, -1.9)
	borde.light_cull_mask = 1 << (CAPA_TSL - 1)
	add_child(borde)


func _montar_tsl04() -> void:
	_tsl = (load(MODELO) as PackedScene).instantiate() as Node3D
	_tsl.name = "Tsl04"
	_tsl.scale = Vector3.ONE * ESCALA
	# A la izquierda y no centrado: en el centro lo tapaba el panel de opciones,
	# que pinta su propio fondo al 92%. Aqui ocupa el hueco que quedaba vacio y
	# el anillo sigue cruzando por detras del panel, que es lo que ata las dos
	# mitades de la pantalla.
	_tsl.position = Vector3(-2.15, -0.35, -0.4)
	add_child(_tsl)
	# a su capa: lo que lo ilumina es su propio juego de luces, no el del decorado
	for n in _tsl.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = 1 << (CAPA_TSL - 1)
	_montar_luces_tsl()

	# El arbol viene de Blender: la raiz la pone el importador con el nombre del
	# archivo, y dentro va TSL04 > ctrl_cuerpo > ctrl_cara > los ojos. Si
	# cambian esos nombres alla, esto deja de encontrarlos y el personaje se
	# queda quieto y sin parpadear, que es un fallo callado; por eso prueba/ui
	# comprueba pieza por pieza que siguen estando.
	var cara: Node3D = _tsl.get_node(RAMA_CARA) as Node3D
	for lado in ["L", "R"]:
		var ojo: Node3D = cara.get_node("ojo_" + lado) as Node3D
		_ojos.append(ojo)
		var piezas: Array = []
		# el iris y sus dos brillos son hermanos, no hijos del iris: para mover
		# la mirada hay que llevarse los tres a la vez o los brillos se quedan
		for n in ["iris_", "brillo1_", "brillo2_"]:
			var pieza: Node3D = ojo.get_node(n + lado) as Node3D
			piezas.append([pieza, pieza.position])
		_mirada.append(piezas)


func _montar_anillo() -> void:
	# El toro es la pieza que mas trabaja de toda la escena, y es deliberado: su
	# silueta cambia por completo al girar (de circunferencia a elipse a linea),
	# asi que basta el para que el ojo sepa que hay profundidad. Una esfera
	# girando no dice nada, porque un circulo es un circulo desde todos lados.
	var toro := TorusMesh.new()
	toro.inner_radius = 0.90
	toro.outer_radius = 1.02
	toro.rings = 48
	toro.ring_segments = 10
	_anillo = MeshInstance3D.new()
	_anillo.name = "Anillo"
	_anillo.mesh = toro
	_anillo.material_override = _mat(CIAN, 1.10, 0.20, 0.6)
	_anillo.position = Vector3(-2.15, -0.35, -0.4)
	add_child(_anillo)


func _montar_placas() -> void:
	## Placas de circuito a distintas profundidades. La mas cercana y la mas
	## lejana se mueven a velocidades muy distintas al desplazarse la camara, y
	## ese desajuste ES la sensacion de profundidad.
	var sitios: Array = [
		[Vector3(-2.9, 1.35, -2.2), Vector3(2.4, 0.06, 1.7), 14.0],
		[Vector3(2.7, -1.15, -1.4), Vector3(2.0, 0.06, 2.6), -11.0],
		[Vector3(-2.6, -2.25, -4.4), Vector3(3.2, 0.06, 2.0), 24.0],
		[Vector3(3.3, 1.75, -4.2), Vector3(2.6, 0.06, 1.6), -18.0],
		[Vector3(-3.8, -0.25, -5.4), Vector3(3.6, 0.06, 2.4), 9.0],
	]
	for i in sitios.size():
		var s: Array = sitios[i]
		var caja := BoxMesh.new()
		caja.size = s[1]
		var mi := MeshInstance3D.new()
		mi.name = "Placa%d" % i
		mi.mesh = caja
		# Las lejanas mas apagadas: la niebla de verdad no existe en GL
		# Compatibility, asi que la distancia se cuenta bajando el brillo a mano.
		# Y ninguna tan oscura como el sustrato real de la placa
		# (0.042, 0.075, 0.070): es correcto para la textura vista de cerca en
		# el juego, pero aqui son superficies grandes iluminadas de canto y
		# salian como esquirlas negras. Albedo mas claro y emision propia es lo
		# que las hace leerse como placas encendidas.
		var lejania: float = clampf(-float(s[0].z) / 6.0, 0.0, 1.0)
		var tono: Color = Color(0.16, 0.30, 0.26).lerp(Color(0.07, 0.13, 0.13), lejania)
		mi.material_override = _mat(tono, 0.22 * (1.0 - 0.6 * lejania), 0.62)
		mi.position = s[0]
		mi.rotation_degrees = Vector3(float(s[2]) * 0.4, float(s[2]), 0.0)
		add_child(mi)
		_placas.append(mi)


func _montar_paquetes() -> void:
	## Los paquetes de datos del fondo del juego, aqui en volumen. Mismo
	## lenguaje visual: cuadraditos voltios que recorren el bus.
	for i in 6:
		var caja := BoxMesh.new()
		caja.size = Vector3(0.11, 0.11, 0.34)
		var mi := MeshInstance3D.new()
		mi.name = "Paquete%d" % i
		mi.mesh = caja
		mi.material_override = _mat(VOLT if i % 2 == 0 else CIAN, 2.2, 0.1)
		add_child(mi)
		_paquetes.append(mi)


## Le dice a la escena que opcion esta elegida. La camara se desplaza, no salta:
## el movimiento tiene que leerse como que la camara viaja por dentro de algo.
func mirar_opcion(i: int, total: int) -> void:
	var centro: float = (float(total) - 1.0) * 0.5
	_objetivo = -(float(i) - centro) * PASO_CAMARA
	# y TSL-04 se entera: mira a esa fila y le responde con SU reaccion
	_opcion = i
	_t_reac = 0.0
	_fuerza = 1.0
	_espera = 0.0
	_t_ojo = _prox_ojo + 0.001    # y pestanea, que es lo que hace cualquiera


## El jugador esta manteniendo SALIR: `t` va de 0 a 1 segun lo que lleve. Se
## llama en cada cuadro desde menu.gd, y ademas esto se apaga solo (ver el final
## de _animar_tsl04), asi que si el menu deja de llamar, la despedida se deshace
## igual en vez de quedarse puesta.
func despedida(t: float) -> void:
	_adios = clampf(t, 0.0, 1.0)
	if _adios > 0.05:
		_espera = 0.0             # esto cuenta como estar haciendo algo


## El jugador ha elegido de verdad. La misma reaccion de esa opcion, pero mas
## grande: es la diferencia entre "te he oido" y "voy".
func confirmar() -> void:
	_t_reac = 0.0
	_fuerza = 1.9
	_espera = 0.0


func _process(delta: float) -> void:
	_t += delta
	_altura = lerpf(_altura, _objetivo, clampf(delta * SUAVIZADO, 0.0, 1.0))

	# la camara orbita despacio y ademas acompana a la seleccion
	var orbita: float = sin(_t * 0.11) * 0.55
	_camara.position = Vector3(orbita, _altura * 1.6 + sin(_t * 0.17) * 0.12, 5.2)
	_camara.look_at(Vector3(0.0, _altura * 0.7, 0.0), Vector3.UP)

	_animar_tsl04(delta)
	_anillo.position.y = -0.35 + sin(_t * 0.8) * 0.04

	_anillo.rotation = Vector3(_t * 0.47 + 0.5, _t * 0.29, sin(_t * 0.19) * 0.4)

	for i in _placas.size():
		var p: MeshInstance3D = _placas[i]
		var v: float = 0.12 + 0.04 * float(i)
		p.rotation.y += delta * v * (1.0 if i % 2 == 0 else -1.0)
		p.position.y += sin(_t * (0.3 + 0.07 * float(i))) * delta * 0.22

	# los paquetes recorren el bus y vuelven a empezar: el modulo es lo que
	# cierra el recorrido sin acumular error con el tiempo
	for i in _paquetes.size():
		var q: MeshInstance3D = _paquetes[i]
		var carril: int = i % 3
		var avance: float = fmod(_t * (1.5 + 0.35 * float(carril)) + float(i) * 1.7, 7.0)
		q.position = Vector3(-2.6 + float(carril) * 2.4,
							 -1.9 + float(carril) * 1.5,
							 -4.6 + avance)
		q.rotation.z = _t * 0.9 + float(i)


func medir_filas(primera: float, paso: float) -> void:
	fila_primera = primera
	fila_paso = paso


## El punto del mundo que cae justo donde el jugador ve la opcion elegida. El
## panel es una capa 2D por encima y no tiene sitio en el mundo, asi que se coge
## el punto que la camara ve en esa parte de la pantalla, a DIST_PANEL de ella.
func _punto_fila() -> Vector3:
	var media: float = tan(deg_to_rad(_camara.fov * 0.5)) * DIST_PANEL
	return _camara.global_transform * Vector3(0.0,
		-media * (fila_primera + fila_paso * float(_opcion)), -DIST_PANEL)


## La reaccion de cada opcion, toda en un sitio: devuelve
## [giro, cabezada, ladeo, altura, estirado] para el tiempo `u` desde que se
## eligio. Son curvas, no estados: TODAS se apagan solas, no hay banderas que
## se puedan quedar encendidas y no hay nada que esperar a que termine. Si el
## jugador cambia de opcion a media reaccion, la nueva empieza de cero y el
## cuerpo llega a ella suavizado, asi que tampoco da un tiron.
func _reaccion(i: int, u: float) -> Array:
	if i == 0:
		# JUGAR: ganas de salir corriendo. Dos brincos, y en cada aterrizaje se
		# aplasta, que es lo que hace que un salto pese.
		var a: float = exp(-u * 2.0)
		return [0.0, -0.10 * a, 0.0, absf(sin(u * PI * 2.4)) * a * 0.26,
			-sin(u * PI * 4.8) * a * 0.14]
	if i == 1:
		# OPCIONES: curiosidad. Ladea la cabeza deprisa y la va enderezando.
		var b: float = exp(-u * 0.85) * (1.0 - exp(-u * 9.0))
		return [0.10 * b, 0.0, 0.42 * b, 0.0, 0.0]
	if i == 2:
		# CREDITOS: asiente dos veces, como quien lee una lista de nombres.
		var c: float = exp(-u * 1.7)
		return [0.0, sin(u * PI * 2.6) * c * 0.32, 0.0, 0.0, 0.0]
	# SALIR: se desanima. Se hunde, agacha la cabeza, y se recupera sola: el
	# desanimo tiene que PASARSE, o el menu se queda con cara triste para siempre.
	var d: float = (1.0 - exp(-u * 5.0)) * exp(-u * 0.45)
	return [0.0, 0.30 * d, -0.12 * d, -0.13 * d, 0.06 * d]


## TSL-04 vivo. Cada pieza de esto responde a algo: mira a la opcion que estas
## eligiendo, le contesta con una reaccion distinta a cada una, parpadea, y si
## te quedas quieto levanta la vista a buscarte. Nada de esto se puede hacer con
## un dibujo, y es lo unico que separa "una bola azul en el fondo" de "el
## personaje del juego esta aqui".
func _animar_tsl04(delta: float) -> void:
	_t_reac += delta
	_espera += delta

	# ---------------------------------------------------------- a donde mira
	# Si pasa un rato sin que toques nada, te busca a ti y vuelve al menu, una y
	# otra vez: una cara que solo mira al panel es un adorno; una que de vez en
	# cuando levanta la vista es alguien esperando.
	var atencion := 0.0
	if _espera > ESPERA_MIRA:
		atencion = maxf(sin((_espera - ESPERA_MIRA) * 0.5), 0.0) * 0.7
	_p_adios = lerpf(_p_adios, _adios, clampf(delta * ADIOS_SIGUE, 0.0, 1.0))
	# Al despedirse deja de mirar al menu y te mira A TI: es lo que convierte un
	# temporizador en alguien pidiendote que no te vayas.
	var punto: Vector3 = _punto_fila().lerp(_camara.global_position,
		maxf(atencion, _p_adios))
	if _mira == Vector3.ZERO:
		_mira = punto                 # el primer cuadro, sin barrido desde el centro
	_mira = _mira.lerp(punto, clampf(delta * SIGUE, 0.0, 1.0))

	# La cabeza se queda a medio camino (CABEZA) y los ojos completan el resto.
	# y la cabeza se gira DEL TODO, no a medias como cuando mira una opcion
	var objetivo: Vector3 = _camara.global_position.lerp(_mira,
		CABEZA * (1.0 - _p_adios))
	var d: Vector3 = objetivo - _tsl.global_position
	var giro: float = atan2(d.x, d.z)
	var cabezada: float = -atan2(d.y, Vector2(d.x, d.z).length())

	# ------------------------------------------------- reaccion + vaiven vivo
	# El vaiven no para nunca, ni con el menu quieto: es lo que ensena que la
	# cara tiene bulto, porque al girar un ojo tapa un poco al otro y la sonrisa
	# se acorta. Las tres velocidades no son multiplo una de otra para que la
	# pose no se repita cada pocos segundos.
	var r: Array = _reaccion(_opcion, _t_reac)
	giro += float(r[0]) * _fuerza + sin(_t * 0.37) * 0.24
	cabezada += float(r[1]) * _fuerza + sin(_t * 0.53) * 0.07
	var ladeo: float = float(r[2]) * _fuerza + sin(_t * 0.31) * 0.07
	var alto: float = float(r[3]) * _fuerza + sin(_t * 0.8) * 0.055
	var estira: float = float(r[4]) * _fuerza

	# Se despide: agacha la cabeza, la ladea, se hunde y tiembla un poco. La
	# cabeza baja pero la MIRADA se queda en ti (arriba hemos puesto el punto en
	# la camara), asi que los ojos se le van hacia arriba solos. Esa combinacion
	# (cabeza abajo, ojos arriba) es la cara de "no te vayas"; no hay que
	# dibujarla, sale de las dos cosas juntas.
	cabezada += ADIOS_AGACHA * _p_adios
	ladeo += (ADIOS_LADEO + sin(_t * 1.7) * 0.05) * _p_adios
	alto += (sin(_t * 9.0) * 0.008 - 0.11) * _p_adios
	# y se va apagando, que en una maquina que funciona con carga es lo que
	# significa despedirse
	if _clave_tsl != null:
		_clave_tsl.light_energy = 1.45 * (1.0 - ADIOS_APAGA * _p_adios)

	# Todo entra suavizado. Es lo que impide el tiron al cambiar de opcion a
	# media reaccion, y lo que hace que no haya ningun salto que "trabe".
	var k: float = clampf(delta * POSE, 0.0, 1.0)
	_p_giro = lerp_angle(_p_giro, giro, k)
	_p_cabezada = lerpf(_p_cabezada, cabezada, k)
	_p_ladeo = lerpf(_p_ladeo, ladeo, k)
	_p_alto = lerpf(_p_alto, alto, k)
	_p_estira = lerpf(_p_estira, estira, k)

	_tsl.rotation = Vector3(_p_cabezada, _p_giro, _p_ladeo)
	_tsl.position.y = -0.35 + _p_alto
	# y se encoge: pequeno es la forma mas corta de decir "no te vayas"
	var tam: float = ESCALA * (1.0 - ADIOS_ENCOGE * _p_adios)
	_tsl.scale = Vector3(tam * (1.0 - _p_estira), tam * (1.0 + _p_estira),
		tam * (1.0 - _p_estira))

	# --------------------------------------------------------------- los ojos
	# parpadeo: se cierra y se abre en 0,16 s, cada 2,6-5,5 s
	var abierto := 1.0
	_t_ojo += delta
	if _t_ojo > _prox_ojo:
		var f: float = (_t_ojo - _prox_ojo) / PARPADEO
		if f >= 1.0:
			_t_ojo = 0.0
			_prox_ojo = randf_range(2.6, 5.5)
		else:
			abierto = 1.0 - sin(f * PI) * 0.94
	# Mientras se despide deja de pestanear de golpe y le pesan los parpados:
	# un cierre lento y continuo en vez de los parpadeos secos de siempre. Entra
	# suavizado para no cortar un parpadeo empezado por la mitad.
	abierto = lerpf(abierto, 1.0 - 0.30 * (0.5 + 0.5 * sin(_t * 1.5)),
		clampf(_p_adios * 2.0, 0.0, 1.0))
	# y los ojos se le hacen mas grandes, que es lo unico que hace falta para
	# que una cara redonda de pena
	var ojazo: float = 1.0 + 0.16 * _p_adios
	for i in _ojos.size():
		# El punto que mira, visto desde el ojo, con la base SIN escala: el ojo
		# se esta aplastando para parpadear, y con to_local esa Y aplastada
		# multiplicaria la altura de la mirada por diez justo al cerrarse.
		var base: Basis = _ojos[i].global_transform.basis.orthonormalized()
		var l: Vector3 = (base.inverse() * (_mira - _ojos[i].global_position)).normalized()
		var v := Vector3(clampf(l.x, -0.7, 0.7) * MIRADA,
						 clampf(l.y, -0.7, 0.7) * MIRADA * 0.8, 0.0)
		for par in _mirada[i]:
			(par[0] as Node3D).position = (par[1] as Vector3) + v
		_ojos[i].scale = Vector3(ojazo, abierto * ojazo, 1.0)

	# La despedida se apaga sola. menu.gd la refresca en cada cuadro mientras se
	# mantiene el boton, asi que esto no le quita nada; lo que impide es que un
	# valor viejo se quede puesto si el menu deja de hablar (al abrir un panel,
	# por ejemplo) y TSL-04 se quede encogido para siempre.
	_adios = maxf(_adios - delta * 1.5, 0.0)
