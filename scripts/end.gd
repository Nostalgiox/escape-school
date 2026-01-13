extends Area3D

@export var animation_player: AnimationPlayer
@export var credits_label: Label

@export var scroll_speed: float = 40.0
@export var return_delay: float = 30.0

var triggered: bool = false
var credits_active: bool = false
var input_locked: bool = false


func _process(delta):
	if not credits_active:
		return

	# Scroll napisów od dołu do góry
	credits_label.position.y -= scroll_speed * delta


func _on_body_entered(body):
	if triggered:
		return

	if not body.is_in_group("player"):
		return

	triggered = true

	# 🔒 blokujemy ESC + inventory
	input_locked = true

	animation_player.play("fade_in")
	await animation_player.animation_finished
	show_credits()


func show_credits():
	print("SHOW_CREDITS CALLED")

	credits_label.visible = true

	var viewport_size = credits_label.get_viewport().get_visible_rect().size

	# Start POD ekranem (Star Wars style)
	credits_label.position = Vector2(
		(viewport_size.x - credits_label.size.x) / 2,
		viewport_size.y
	)

	credits_active = true

	# Po ~15 sekundach powrót do menu
	await get_tree().create_timer(return_delay).timeout
	go_to_main_menu()


func _input(event):
	if not input_locked:
		return

	# Blok ESC
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

	# Blok inventory
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()


func go_to_main_menu():
	input_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/menu_glowne.tscn")
