extends MeshInstance3D

@onready var lamps = $"../CeilingLamps"
@onready var sound_switch = $Light_Switch
@onready var exclamation = $Exclamation
@onready var ex_anim = $"../../AnimationPlayer"

var player_in_area: bool = false

func _ready() -> void:
	# odpal animację wykrzyknika
	if ex_anim and ex_anim.has_animation("exclamation"):
		ex_anim.play("exclamation")
	
	print("Light switch ready.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player_in_area:
		_toggle_lamps()
		_hide_exclamation()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_area = true
		print("Player is inside interaction area.")


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_area = false
		print("Player left interaction area.")


func _toggle_lamps() -> void:
	lamps.visible = not lamps.visible
	if sound_switch:
		sound_switch.play()
	print("Lights toggled:", lamps.visible)


func _hide_exclamation() -> void:
	if exclamation and exclamation.visible:
		exclamation.visible = false
