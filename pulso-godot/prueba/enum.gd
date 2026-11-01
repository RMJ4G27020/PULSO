extends SceneTree
func _init():
	var clave := "rendering/textures/canvas_textures/default_texture_filter"
	for p in ProjectSettings.get_property_list():
		if p.name == clave:
			print("HINT: ", p.hint_string)
	print("VALOR ACTUAL: ", ProjectSettings.get_setting(clave))
	quit()
