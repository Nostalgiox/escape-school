extends StaticBody3D

@export var interaction_text: String = "Kliknij aby rozpocząć"
@export var interaction_distance: float = 3.0
@onready var label_3d = $Label3D

var player
var can_interact = false

func _ready():
	label_3d.visible = true
	label_3d.text = interaction_text
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if player:
		var distance = global_transform.origin.distance_to(player.global_transform.origin)
		if distance < interaction_distance:
			label_3d.visible = true
			can_interact = true
		else:
			label_3d.visible = false
			can_interact = false

func _unhandled_input(event):
	if can_interact and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		player.move_to_computer(global_transform.origin)
