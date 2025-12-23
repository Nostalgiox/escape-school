extends StaticBody3D

@onready var anim_player: AnimationPlayer = $"../../../AnimationPlayer"
@onready var sfx: AudioStreamPlayer = $Door_open

func _on_keypad_unlocked() -> void:
	print("DOOR: keypad unlocked, opening door")

	if anim_player:
		anim_player.play("Secondroom_exit_open")
		sfx.play()
