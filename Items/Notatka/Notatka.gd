extends Area3D

@onready var info_panel = $CanvasLayer/InfoPanel
@onready var info_label = $CanvasLayer/InfoPanel/InfoLabel
@onready var animator : AnimationPlayer = $AnimationPlayer
@onready var button = $CanvasLayer/InfoPanel/Button

@export var door : NodePath
var door_node

var player_in_range = false
var note_read = false #flaga

func _ready():
	animator.play("1")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	if door != null:
		door_node = get_node(door)

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		var opening = not info_panel.visible
		info_panel.visible = opening
		info_panel.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) else Input.MOUSE_MODE_CAPTURED
		
		if opening and not note_read:
			note_read = true
			if door_node:
				door_node.unlock()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = false
