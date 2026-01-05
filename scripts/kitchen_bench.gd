extends Node3D

@export var open_animation_name: String = "OPEN_ANIMATION"
@export var destroy_after: bool = false

@onready var anim_player: AnimationPlayer = $AnimationPlayer2
@onready var smash_sound: AudioStreamPlayer = $Wood_smash

var opened := false

func _on_computer_cash_register_solved() -> void:
	if opened:
		return

	opened = true

	# dźwięk
	if smash_sound:
		smash_sound.play()

	# animacja
	if anim_player and anim_player.has_animation(open_animation_name):
		anim_player.play(open_animation_name)
	else:
		push_warning("Brak animacji: %s" % open_animation_name)
