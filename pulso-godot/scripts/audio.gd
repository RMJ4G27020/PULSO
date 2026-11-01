extends Node
## Reproductor de efectos. Autoload `Audio`.
##
## Regla de diseno que viene del propio juego: el audio REFUERZA, nunca informa
## de algo que no se vea. Mucha gente juega en silencio, asi que un peligro que
## solo avisara con sonido seria injusto. Los peligros ya avisan con luz.

const CARPETA := "res://arte/sonido/"
const VOCES := 8                      ## efectos solapados a la vez

## Lista explicita, no escaneo del directorio: al exportar, los .wav de origen
## no viajan en el paquete (solo el recurso importado), asi que DirAccess sobre
## res:// devuelve otra cosa y el juego se queda mudo justo en el movil.
const EFECTOS: Array[String] = ["salto", "aterrizaje", "impulso", "muerte",
	"terminal", "fragmento", "puerta", "aviso", "portal"]

## Los temas van en su propia lista explicita por la misma razon de arriba.
## "libre" es el tema del final: la misma escala que "circuito" en do mayor,
## con el latido una vez por compas. Solo suena en la cinematica del final.
const TEMAS: Array[String] = ["circuito", "libre"]

const BUS_MUSICA := "Musica"
const ATENUACION := -12.0             ## cuanto baja la musica con el juego en pausa

var volumen := 0.8:
	set(v):
		volumen = clampf(v, 0.0, 1.0)
		_aplicar_volumen()

## Separado de `volumen` a proposito: quien juega en el metro quiere bajar la
## musica sin quedarse sin la senal de los efectos.
var volumen_musica := 0.55:
	set(v):
		volumen_musica = clampf(v, 0.0, 1.0)
		_aplicar_volumen()

var silencio := false:
	set(v):
		silencio = v
		_aplicar_volumen()

var _bancos: Dictionary = {}          ## nombre -> AudioStream
var _voces: Array[AudioStreamPlayer] = []
var _siguiente := 0

var _temas: Dictionary = {}           ## nombre -> AudioStreamWAV ya en bucle
## Reproductor PROPIO, fuera de _voces: sonar() reescribe volume_db de la voz
## que le toca en cada disparo, asi que la musica metida en la rotacion se
## quedaria muda y con el volumen pisado.
var _musica: AudioStreamPlayer
var _tema := ""
var _bus := -1                        ## -1 hasta que _ready() cree el bus
var _atenuada := false
var _paso: Tween                      ## fundido de la musica
var _paso_bus: Tween                  ## atenuacion de la pausa

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # sonar aunque el juego se congele
	for i in VOCES:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voces.append(p)
	_crear_bus()
	_musica = AudioStreamPlayer.new()
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	_musica.bus = BUS_MUSICA if _bus > 0 else "Master"
	add_child(_musica)
	_cargar()
	_aplicar_volumen()

## El bus se crea EN CALIENTE: asi no hace falta un default_bus_layout.tres ni
## abrir el editor, y el volumen de la musica se controla en un solo sitio en
## vez de perseguir reproductores.
func _crear_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS_MUSICA)
	if _bus > 0:
		return
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, BUS_MUSICA)
	AudioServer.set_bus_send(_bus, "Master")

func _cargar() -> void:
	for nombre in EFECTOS:
		var ruta: String = CARPETA + nombre + ".wav"
		if not ResourceLoader.exists(ruta):
			push_warning("falta el efecto %s" % ruta)
			continue
		var s: AudioStream = load(ruta)
		if s != null:
			_bancos[nombre] = s
	for nombre in TEMAS:
		var t: AudioStreamWAV = _cargar_tema(nombre)
		if t != null:
			_temas[nombre] = t

## Devuelve el tema ya preparado para dar la vuelta, o null si todavia no esta
## importado (el .sample no existe hasta que pasa el importador).
func _cargar_tema(nombre: String) -> AudioStreamWAV:
	var ruta: String = CARPETA + nombre + ".wav"
	if not ResourceLoader.exists(ruta):
		push_warning("falta el tema %s" % ruta)
		return null
	if not _importado(ruta):
		push_warning("el tema %s aun no esta importado; hay que abrir el editor una vez" % ruta)
		return null
	var base: Resource = load(ruta)
	var origen: AudioStreamWAV = base as AudioStreamWAV
	if origen == null:
		push_warning("el tema %s no cargo como AudioStreamWAV" % ruta)
		return null
	# Duplicado para no dejar el bucle puesto en el recurso compartido de disco.
	return _preparar_bucle(origen.duplicate() as AudioStreamWAV)

## Deja el stream dando la vuelta. Aparte para que la prueba mida ESTO y no una
## copia suya escrita al lado.
func _preparar_bucle(s: AudioStreamWAV) -> AudioStreamWAV:
	if s == null:
		return null
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	# Medido: con loop_end = 0 el bucle NO da la vuelta, el reproductor se para
	# al llegar al final. loop_end va en MUESTRAS, no en segundos.
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	return s

## ResourceLoader.exists() dice que si en cuanto hay un .import, aunque el
## .sample todavia no exista, y entonces load() escupe tres ERROR rojos en cada
## arranque de cada escena. Aqui se mira el destino real antes de cargar.
## En el juego exportado no viaja ningun .import, asi que ConfigFile falla, se
## da por importado y se carga normal: que es justo lo que hay que hacer alli.
func _importado(ruta: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ruta + ".import") != OK:
		return true
	var destino: String = str(cfg.get_value("remap", "path", ""))
	return destino == "" or FileAccess.file_exists(destino)

## `tono` en semitonos: sirve para que repetir un sonido no suene identico.
func sonar(nombre: String, tono := 0.0, ganancia := 0.0) -> void:
	if silencio or not _bancos.has(nombre):
		return
	var p: AudioStreamPlayer = _voces[_siguiente]
	_siguiente = (_siguiente + 1) % VOCES
	p.stream = _bancos[nombre]
	p.pitch_scale = pow(2.0, tono / 12.0)
	p.volume_db = linear_to_db(maxf(volumen, 0.0001)) + ganancia
	p.play()

func tiene(nombre: String) -> bool:
	return _bancos.has(nombre)

# ------------------------------------------------------------------- la musica

## Pone un tema. Si YA esta sonando ese mismo tema no hace nada: entre nivel y
## nivel hay un change_scene_to_file, y reiniciar la musica en cada portal
## convertiria cada puerta en un corte de sonido justo donde el juego funde.
func poner_musica(nombre: String, desvanecido: float = 0.6) -> void:
	if _musica == null:
		return
	if nombre == _tema and _musica.playing:
		return
	if not _temas.has(nombre):
		push_warning("no hay tema '%s'" % nombre)
		return
	var s: AudioStreamWAV = _temas[nombre]
	_tema = nombre
	if _paso != null and _paso.is_valid():
		_paso.kill()
	_musica.stream = s
	_musica.volume_db = -40.0 if desvanecido > 0.0 else 0.0
	_musica.play()
	if desvanecido > 0.0:
		_paso = create_tween()
		_paso.tween_property(_musica, "volume_db", 0.0, desvanecido)

func parar_musica(desvanecido: float = 0.6) -> void:
	if _musica == null or not _musica.playing:
		_tema = ""
		return
	_tema = ""
	if _paso != null and _paso.is_valid():
		_paso.kill()
	if desvanecido <= 0.0:
		_musica.stop()
		return
	_paso = create_tween()
	_paso.tween_property(_musica, "volume_db", -40.0, desvanecido)
	_paso.tween_callback(_musica.stop)

## Con el juego en pausa la musica no se corta: se hunde. Un corte seco al
## pausar se lee como un fallo del juego, y ademas dejaria el menu muerto.
## El Tween corre aunque el arbol este pausado porque este nodo es ALWAYS.
func musica_atenuada(si: bool) -> void:
	if _atenuada == si:
		return
	_atenuada = si
	if _bus <= 0:
		return
	if _paso_bus != null and _paso_bus.is_valid():
		_paso_bus.kill()
	_paso_bus = create_tween()
	_paso_bus.tween_method(_poner_db_bus, AudioServer.get_bus_volume_db(_bus),
		_db_musica(), 0.2)

func tiene_musica(nombre: String) -> bool:
	return _temas.has(nombre)

func _poner_db_bus(db: float) -> void:
	if _bus > 0:
		AudioServer.set_bus_volume_db(_bus, db)

func _db_musica() -> float:
	if silencio:
		return -80.0
	return linear_to_db(maxf(volumen_musica, 0.0001)) + (ATENUACION if _atenuada else 0.0)

func _aplicar_volumen() -> void:
	var db := -80.0 if silencio else linear_to_db(maxf(volumen, 0.0001))
	for p in _voces:
		p.volume_db = db
	# El guardado puede escribir el volumen antes de que _ready() cree el bus;
	# sin la guarda estariamos bajandole el volumen al Master.
	if _bus > 0:
		if _paso_bus != null and _paso_bus.is_valid():
			_paso_bus.kill()
		AudioServer.set_bus_volume_db(_bus, _db_musica())
