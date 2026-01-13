extends StaticBody3D

@export var animation_player: AnimationPlayer
@export var audio_player: AudioStreamPlayer

var player_inside: bool = false
var opened: bool = false

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false

func _input(event):
	if event.is_action_pressed("interact"):
		try_open_door()

func try_open_door():
	if not player_inside:
		return
		
	if opened:
		return

	opened = true
	animation_player.play("ending_open")
	audio_player.play()
