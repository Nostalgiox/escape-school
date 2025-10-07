extends Area3D

@export var level1_path = "res://scenes/Main/level1.tscn"
@export var player : CharacterBody3D

func _on_body_entered(body):
	print("Entered body:", body.name, "Class:", body)
	if body == player:
		var fade_layer = body.get_node("FadeLayer")
		if fade_layer:
			fade_layer.fade_out_with_loading(level1_path)
