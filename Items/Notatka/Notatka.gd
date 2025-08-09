extends Area3D

@onready var info_panel = $CanvasLayer/InfoPanel
@onready var info_label = $CanvasLayer/InfoPanel/InfoLabel
@onready var animator : AnimationPlayer = $AnimationPlayer

var player_in_range = false

func _ready():
	animator.play("1")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		info_panel.visible = not info_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) else Input.MOUSE_MODE_CAPTURED

func _on_body_entered(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = false
