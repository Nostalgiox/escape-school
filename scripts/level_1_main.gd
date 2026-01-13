extends Node3D

@export var music_player : AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player.play()
	music_player.finished.connect(_on_music_finished)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_music_finished():
	music_player.play()
