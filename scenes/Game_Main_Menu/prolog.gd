extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready():
	anim_player.play("lamp_animation")
	music_player.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
