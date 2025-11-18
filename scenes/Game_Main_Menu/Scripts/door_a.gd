extends Node3D

@export var animation_player_path: NodePath = NodePath("")
@onready var animator: AnimationPlayer = null

var can_open: bool = false

func _ready() -> void:
	if animation_player_path != NodePath(""):
		animator = get_node_or_null(animation_player_path) as AnimationPlayer
	else:
		# próbujemy wykryć animator relatywnie (fallback), ale to tylko pomocniczo
		animator = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animator == null:
		push_warning("Door.gd: AnimationPlayer not found. Ustaw animation_player_path w Inspectorze.")
	else:
		print("Door.gd: animator found at:", animator.get_path())

func unlock() -> void:
	if can_open:
		print("Door.gd: unlock() called but door already open.")
		return
	if animator == null:
		push_warning("Door.gd: unlock() called but animator == null (cannot play animation).")
		return
	can_open = true
	print("Door.gd: playing 'open_door' animation.")
	animator.play("open_door")
