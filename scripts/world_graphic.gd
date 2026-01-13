extends Node3D

func _ready():
	apply_texture_quality()

func apply_texture_quality():
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return

	var quality: int = int(cfg.get_value("graphics", "textures", 1))

	match quality:
		0: # Niskie
			RenderingServer.viewport_set_texture_mipmap_bias(
				get_viewport().get_viewport_rid(),
				2.0
			)
		1: # Średnie
			RenderingServer.viewport_set_texture_mipmap_bias(
				get_viewport().get_viewport_rid(),
				1.0
			)
		2: # Wysokie
			RenderingServer.viewport_set_texture_mipmap_bias(
				get_viewport().get_viewport_rid(),
				0.0
			)
