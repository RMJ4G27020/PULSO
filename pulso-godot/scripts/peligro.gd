class_name Peligro
extends Area2D
## Base de todo lo que mata. La regla del GDD: si es rojo, hace dano.

@export var letal := true

func _ready() -> void:
	# se apunta el solo: si depende de que cada escena declare el grupo,
	# basta con olvidarlo en una para que ese peligro no se reinicie nunca
	add_to_group("peligro")
	body_entered.connect(_al_tocar)

func _al_tocar(cuerpo: Node2D) -> void:
	if letal and cuerpo.has_method("morir"):
		cuerpo.morir()

## Devuelve el peligro a su estado de partida. Lo llama el nivel al morir,
## para que no te reciba en la misma pose con la que te mato.
func reiniciar() -> void:
	pass

func chispazo(tinte := Color(1.0, 0.25, 0.2), radio := 260.0) -> void:
	## efecto solo si el jugador lo puede ver: si no, la pantalla se sacude sin motivo
	var j := get_tree().get_first_node_in_group("jugador") as Node2D
	if j and global_position.distance_to(j.global_position) < radio:
		Efectos.aviso_peligro(global_position, tinte)

func _revisar_dentro() -> void:
	## al encenderse hay que matar a quien ya estuviera dentro
	if not letal:
		return
	for c in get_overlapping_bodies():
		if c.has_method("morir"):
			c.morir()
