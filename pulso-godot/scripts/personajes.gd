class_name Personajes
extends RefCounted
## Las cuatro celdas de prueba de NIMBUS-9, como personajes jugables.
##
## La historia ya las tenia: "De sus cables colgaban cuatro celdas de prueba de
## carga. Tres ya se habian apagado." Y en el final, al sol, "a su lado se
## encendieron otras tres luces". Esas tres son TSL-01, 02 y 03, y se despiertan
## con lo que el jugador va consiguiendo.
##
## Cada una cambia la mecanica con UNA ventaja y UN coste, nunca dos ventajas.
## Y hay una regla que no se rompe: ninguna salta menos, corre menos ni cae mas
## deprisa que TSL-04. Los niveles a mano se verificaron con su fisica (huecos de
## 112 px, 56 px de holgura en cada subida) y los grandes (tsl04/grandes.py) se
## construyen con esas mismas cuentas: un personaje con menos alcance se
## encontraria saltos imposibles.
## Por eso los costes van por otro lado (la carga, la estela), y prueba/personajes
## comprueba la regla para todos.

const BASE := "tsl04"
## El orden en que se recorren al elegir.
const ORDEN: Array[String] = ["tsl04", "tsl01", "tsl02", "tsl03"]

## Por personaje: lo que se ve, lo que cambia del jugador (nombres de @export de
## jugador.gd) y de la estela (retardo y duracion de la rejilla). Lo que no se
## dice es lo de TSL-04.
const DATOS := {
	"tsl04": {
		"nombre": "TSL-04", "rasgo": "la de siempre",
		"color": Color(0.21, 0.85, 1.0),
		"hojas": "res://arte/tsl04/tsl04_spriteframes.tres",
		"estela": "res://arte/estela/estela_spriteframes.tres",
		"jugador": {}, "retardo": 0.35, "duracion": 3.0,
		"desbloqueo": "",
	},
	## La primera y la mas vieja: se hizo para medir descargas largas y lentas.
	## Su estela tarda en encenderse (mas margen para dudar) y gasta poca carga.
	## La pega esta en las rafagas: el impulso le sale casi el doble de caro. La
	## duracion de 5 s casi no pega: correr o aterrizar sobre tu propia estela la
	## vuelve a marcar, asi que solo importa al cruzarla en el aire o con el
	## impulso, y por eso no se cuenta como pega.
	"tsl01": {
		"nombre": "TSL-01", "rasgo": "estela lenta; impulso caro",
		"color": Color(1.0, 0.66, 0.16),
		"hojas": "res://arte/tsl04/ambar/tsl04_spriteframes.tres",
		"estela": "res://arte/estela/ambar/estela_spriteframes.tres",
		"jugador": {"consumo": 1.3, "coste_impulso": 5.0}, "retardo": 0.55, "duracion": 5.0,
		"desbloqueo": "Pasa el nivel 3 para despertar a TSL-01",
	},
	## Hecha para picos de carga: va deprisa, salta mas y repite el impulso
	## antes. Y se vacia: con 1,9 %/s la carga dura 53 s en vez de 62. Se calculo
	## contra los pares: una terminal da 15 y cada fragmento 5, y con 2,4 %/s el
	## par del nivel 3 (66 s, o 58 s a su velocidad) pedia 139 %, o sea que ni a
	## ritmo de par se terminaba. Con 1,9 pide 110 %: exige ir bien, no perfecto.
	## prueba/personajes lo comprueba para todos (carga a ritmo de par <= 115).
	"tsl02": {
		"nombre": "TSL-02", "rasgo": "rapida, pero gasta mas",
		"color": Color(0.66, 0.48, 1.0),
		"hojas": "res://arte/tsl04/violeta/tsl04_spriteframes.tres",
		"estela": "res://arte/estela/violeta/estela_spriteframes.tres",
		"jugador": {"velocidad": 250.0, "altura_salto": 125.0, "impulso_espera": 0.6,
			"consumo": 1.9},
		"retardo": 0.35, "duracion": 3.0,
		"desbloqueo": "Pasa el nivel 4 para despertar a TSL-02",
	},
	## La que mas aguanto colgada: se agarra a todo. Trepa sin gastar carga y el
	## pulso le cuesta menos, pero el impulso tarda en volver. Su estela es la de
	## siempre a proposito: la pared exige que una celda se cruce deslizando en
	## menos de lo que tarda en encenderse (16 px / 46 px/s = 0,348 s contra 0,35),
	## asi que ni resbalar mas despacio ni encenderse antes son posibles sin
	## matarla en cada pared. prueba/personajes lo comprueba para los cuatro.
	"tsl03": {
		"nombre": "TSL-03", "rasgo": "trepa gratis; impulso lento",
		"color": Color(0.82, 0.90, 0.95),
		"hojas": "res://arte/tsl04/plata/tsl04_spriteframes.tres",
		"estela": "res://arte/estela/plata/estela_spriteframes.tres",
		"jugador": {"coste_adherencia": 0.0, "coste_pulso": 15.0, "impulso_espera": 1.4},
		"retardo": 0.35, "duracion": 3.0,
		"desbloqueo": "Recoge los 12 fragmentos para despertar a TSL-03",
	},
}

## Para pruebas y capturas: fuerza un personaje sin tocar el guardado. Una prueba
## que escribiera "personaje" en el progreso le cambiaria la eleccion a quien
## juega; esto vive solo en memoria. Tambien se puede dar desde fuera, para
## pasar los bots con cada personaje:
##   PULSO_PERSONAJE=tsl01 Godot --headless --path . prueba/bot.tscn
static var forzado := OS.get_environment("PULSO_PERSONAJE")
static var _avisado := false


## Hay arte para el (sus hojas existen). Un personaje sin arte no se ofrece.
static func disponible(id: String) -> bool:
	if not DATOS.has(id):
		return false
	return ResourceLoader.exists(String(DATOS[id]["hojas"])) \
		and ResourceLoader.exists(String(DATOS[id]["estela"]))


static func desbloqueado(id: String) -> bool:
	match id:
		"tsl04":
			return true
		"tsl01":
			# despierta con el final, que va despues del nivel 3
			return Guardado.nivel_desbloqueado(4)
		"tsl02":
			return Guardado.nivel_desbloqueado(5)
		"tsl03":
			for n in range(1, 5):
				if Guardado.fragmentos(n) < 3:
					return false
			return true
	return false


static func elegible(id: String) -> bool:
	return disponible(id) and desbloqueado(id)


## El que se juega. Si el guardado dice uno que ya no vale (sin arte, cerrado o
## que no existe), TSL-04: nunca se puede quedar el juego sin personaje.
## El forzado manda sobre el progreso: solo pide que tenga arte. Si tambien
## exigiera estar despierto, una prueba o un bot lanzado con PULSO_PERSONAJE
## sobre una partida nueva correria con TSL-04 sin decirlo, y pasaria por
## "probado" lo que no se probo.
static func actual() -> String:
	if forzado != "":
		if disponible(forzado):
			return forzado
		if not _avisado:
			_avisado = true
			push_warning("PULSO_PERSONAJE='%s' no existe o no tiene arte: se juega con %s" % [forzado, BASE])
		return BASE
	var id := String(Guardado.opcion("personaje", BASE))
	return id if elegible(id) else BASE


static func elegir(id: String) -> void:
	if not elegible(id):
		return
	Guardado.poner_opcion("personaje", id)
	Guardado.guardar()


## Los que se pueden elegir ahora, en orden.
static func elegibles() -> Array[String]:
	var r: Array[String] = []
	for id in ORDEN:
		if elegible(id):
			r.append(id)
	return r


static func dato(id: String, clave: String) -> Variant:
	var d: Dictionary = DATOS.get(id, DATOS[BASE])
	return d.get(clave, DATOS[BASE][clave])


# --------------------------------------------------------------- aplicarlos
## Pone en el jugador lo que cambia su personaje y su hoja de animaciones.
## Devuelve el id aplicado.
static func aplicar_jugador(j: Node) -> String:
	var id := actual()
	var cambios: Dictionary = dato(id, "jugador")
	for clave in cambios:
		j.set(clave, cambios[clave])
	var sprite := j.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null and id != BASE:
		var sf := load(String(dato(id, "hojas"))) as SpriteFrames
		if sf != null:
			sprite.sprite_frames = sf
	return id


## Lo mismo para la estela: tiempos, color de la cinta y laminas.
static func aplicar_rejilla(r: Node) -> String:
	var id := actual()
	r.set("retardo_base", float(dato(id, "retardo")))
	r.set("duracion", float(dato(id, "duracion")))
	r.set("color_cinta", dato(id, "color") as Color)
	r.set("hojas_estela", String(dato(id, "estela")))
	return id
