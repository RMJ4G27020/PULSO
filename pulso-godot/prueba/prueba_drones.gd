extends Node
## Los drones deben tener masa: pasarse de largo al final de la patrulla,
## ladearse en el sentido en que aceleran, y la torreta pasarse al apuntar.
var n: Node2D
var jug: CharacterBody2D
var dron: Node2D
var zap: Node2D
var t := 0.0
var paso := 0
var fallos := 0
var max_pasada := 0.0
var incl: Array[float] = []
var acel: Array[float] = []
var vx_ant := 0.0
var ang_hist: Array[float] = []
var termino := false

func _ok(c: bool, txt: String) -> void:
	if not c: fallos += 1
	print("  %-52s %s" % [txt, "OK" if c else "FALLA"])

func _ready() -> void:
	n = load("res://escenas/niveles/n3_el_nudo.tscn").instantiate() as Node2D
	add_child(n)
	jug = n.get_node("Jugador")
	for pel in get_tree().get_nodes_in_group("peligro"):
		var r: String = pel.get_script().resource_path if pel.get_script() else ""
		if r.ends_with("dron_purga.gd"): dron = pel
		elif r.ends_with("dron_zapador.gd"): zap = pel
	# lejos, que no entre en alerta y patrulle tranquilo
	jug.global_position = Vector2(-4000, 0)

func _physics_process(d: float) -> void:
	t += d
	match paso:
		0:
			if t > 0.5: paso = 1; t = 0.0
		1:   # patrulla: medir cuanto se pasa del extremo y si se ladea
			jug.global_position = Vector2(-4000, 0)      # sujetarlo: si no, se cae al vacio
			if fmod(t, 1.0) < d:
				print("    t=%.0f  x=%.1f  a=%.1f b=%.1f  vx=%.1f  alerta=%s"
					% [t, dron.global_position.x, dron._a.x, dron._b.x, dron._vel.x, dron._alerta])
			var lim_a: float = dron._a.x
			var lim_b: float = dron._b.x
			var x: float = dron.global_position.x
			max_pasada = maxf(max_pasada, maxf(x - maxf(lim_a, lim_b), minf(lim_a, lim_b) - x))
			var a: float = dron._vel.x - vx_ant
			vx_ant = dron._vel.x
			if absf(a) > 0.02:
				acel.append(a); incl.append(dron.get_node("Sprite").rotation)
			if t > 7.0:
				_ok(max_pasada > 1.0, "se pasa %.1f px del extremo de la patrulla" % max_pasada)
				var iguales := 0
				for i in acel.size():
					if signf(incl[i]) == -signf(acel[i]) or absf(incl[i]) < 0.004: iguales += 1
				var frac := float(iguales) / maxf(1.0, float(acel.size()))
				_ok(frac > 0.85, "se ladea hacia donde acelera (%.0f%% de %d muestras)" % [100*frac, acel.size()])
				_ok(absf(dron.get_node("Sprite").position.y) > 0.2, "cabecea al sostenerse (%.1f px)" % dron.get_node("Sprite").position.y)
				# ahora la torreta: ponerle el jugador a un lado
				jug.global_position = zap.global_position + Vector2(140, 60)
				paso = 2; t = 0.0
		2:
			jug.global_position = zap.global_position + Vector2(140, 60)   # sujetarlo aqui
			jug.velocity = Vector2.ZERO
			# la PRIMERA tanda de apuntado: en las siguientes ya esta
			# apuntando al sitio y no tiene giro que hacer, asi que no se
			# puede pasar de largo de nada
			if zap._estado == "apunta" and not termino:
				ang_hist.append(zap._ang)
			elif ang_hist.size() > 4:
				termino = true
			if t > 3.0:
				var objetivo := (jug.global_position - zap.global_position).angle()
				var maxerr := 0.0
				var cruces := 0
				var signo := 0.0
				for a in ang_hist:
					var e: float = wrapf(a - objetivo, -PI, PI)
					maxerr = maxf(maxerr, absf(e))
					# signi() trunca a entero: cualquier error menor que 1 rad daba 0
					# y no se detectaba ningun cambio de signo. signf() no trunca.
					var sg: float = signf(e)
					if signo != 0.0 and sg != 0.0 and sg != signo: cruces += 1
					if sg != 0.0: signo = sg
				var linea := ""
				for i in mini(14, ang_hist.size()):
					linea += "%.2f " % wrapf(ang_hist[i] - objetivo, -PI, PI)
				print("    objetivo %.3f rad   error por muestra: %s" % [objetivo, linea])
				print("    vel_ang final %.3f   estado %s   apuntado=%.2f" % [zap._vel_ang, zap._estado, zap.apuntado])
				_ok(ang_hist.size() > 5, "la torreta llega a apuntar (%d muestras)" % ang_hist.size())
				_ok(cruces >= 1, "se pasa de largo y corrige (%d cruces por el objetivo)" % cruces)
				_ok(absf(wrapf(ang_hist[-1] - objetivo, -PI, PI)) < 0.12,
					"acaba asentada en el objetivo (error final %.3f rad)" % absf(wrapf(ang_hist[-1] - objetivo, -PI, PI)))
				print("FALLOS: %d" % fallos)
				print("PRUEBA DRONES OK")
				get_tree().quit()
