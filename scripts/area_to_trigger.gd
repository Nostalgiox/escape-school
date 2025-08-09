extends Area3D

@export var next_scene: PackedScene
@export var interaction_text: String = "Kliknij aby rozpocząć..."

@onready var label_3d = $"../Label3D"
@onready var fade_overlay = $"../../CanvasLayer/FadeOverlay"

var player_inside = false

func _ready():
	print(Global.global_numbers)
	var player = get_tree().get_first_node_in_group("player")  # Pobieramy gracza
	if player:
		if Global.player_position != Vector3.ZERO:
			player.global_transform.origin = Global.player_position
		
	label_3d.text = interaction_text
	label_3d.visible = false
	
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate = Color(0, 0, 0, 1)
		var tween = get_tree().create_tween()
		tween.tween_property(fade_overlay, "modulate", Color(0, 0, 0, 0), 1.5)
		await tween.finished
		fade_overlay.visible = false
	
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _process(delta):
	if player_inside:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			label_3d.look_at(player.global_transform.origin, Vector3.UP)
			label_3d.rotate_y(deg_to_rad(180))
			label_3d.rotation.x = 0
			label_3d.rotation.z = 0

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Gracz wszedl")
		label_3d.visible = true
		player_inside = true
func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Gracz wyszedl")
		label_3d.visible = false
		player_inside = false
func _unhandled_input(event):
	if player_inside and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_blackout()

func start_blackout():
	print("Przechodzenie do czerni...")
	var player = get_tree().get_first_node_in_group("player")
	if player:
		Global.player_position = player.global_transform.origin  # Zapis pozycji

	fade_overlay.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(fade_overlay, "modulate", Color(0, 0, 0, 1), 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/Computer_game/game.tscn")
