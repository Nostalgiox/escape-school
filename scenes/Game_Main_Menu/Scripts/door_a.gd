extends Node3D

@onready var animator : AnimationPlayer = $"../../AnimationPlayer"
var can_open = false

func unlock():
	if can_open:
		return
	can_open = true
	animator.play("open_door")
