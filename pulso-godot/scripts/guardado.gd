extends Node
## Progreso persistente. Autoload `Guardado`.
##
## Un solo archivo JSON en user://. Nada de clases internas: se serializan mal
## y ademas `:=` no infiere tipos desde Dictionary, asi que todo va anotado.

const RUTA := "user://progreso.json"

var _datos: Dictionary = {}

func _ready() -> void:
	cargar()

# ------------------------------------------------------------------ lectura
func nivel_desbloqueado(n: int) -> bool:
	return n <= int(_datos.get("max_nivel", 1))

func mejor_tiempo(n: int) -> float:
	var t: Dictionary = _datos.get("tiempos", {})
	return float(t.get(str(n), 0.0))

func fragmentos(n: int) -> int:
	var f: Dictionary = _datos.get("fragmentos", {})
	return int(f.get(str(n), 0))

func muertes_totales() -> int:
	return int(_datos.get("muertes", 0))

## Ajustes del jugador (volumen, cerco fijo...). Viven en el mismo JSON porque
## un segundo archivo es un segundo archivo que se puede corromper.
func opcion(nombre: String, por_defecto: Variant) -> Variant:
	var o: Dictionary = _datos.get("opciones", {})
	return o.get(nombre, por_defecto)

func poner_opcion(nombre: String, valor: Variant) -> void:
	var o: Dictionary = _datos.get("opciones", {})
	o[nombre] = valor
	_datos["opciones"] = o

# ------------------------------------------------------------- escritura
func completar_nivel(n: int, tiempo: float, frags: int) -> void:
	var maxn: int = int(_datos.get("max_nivel", 1))
	_datos["max_nivel"] = maxi(maxn, n + 1)

	var t: Dictionary = _datos.get("tiempos", {})
	var previo: float = float(t.get(str(n), 0.0))
	if previo <= 0.0 or tiempo < previo:
		t[str(n)] = tiempo
	_datos["tiempos"] = t

	var f: Dictionary = _datos.get("fragmentos", {})
	f[str(n)] = maxi(int(f.get(str(n), 0)), frags)
	_datos["fragmentos"] = f

	guardar()

## No escribe a disco: morir es un momento critico y no toca hacer I/O ahi.
## Se vuelca al completar nivel o al salir.
func sumar_muerte() -> void:
	_datos["muertes"] = int(_datos.get("muertes", 0)) + 1

func borrar_todo() -> void:
	_datos = {}
	guardar()

# ------------------------------------------------------------------ disco
func cargar() -> void:
	if not FileAccess.file_exists(RUTA):
		_datos = {}
		return
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		_datos = {}
		return
	var texto := f.get_as_text()
	f.close()
	# JSON.parse_string() escupe un ERROR en consola cuando el archivo esta a
	# medias, y eso es ruido: el caso esta previsto y se resuelve empezando de
	# cero. Con JSON.new().parse() el fallo llega como codigo de retorno.
	var j := JSON.new()
	if j.parse(texto) != OK:
		push_warning("progreso ilegible, se empieza de cero")
		_datos = {}
		return
	var v: Variant = j.data
	_datos = v if v is Dictionary else {}

func guardar() -> void:
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		push_warning("no se pudo escribir el progreso en %s" % RUTA)
		return
	f.store_string(JSON.stringify(_datos))
	f.close()
