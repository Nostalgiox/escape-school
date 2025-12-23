extends Node3D

signal keypad_unlocked

@export var correct_code: String = "27"
@export var max_digits: int = 3

var player_in_range := false
var ui_open := false
var current_input := ""

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $KeypadUI
@onready var display: Label = $KeypadUI/Panel/VBoxContainer/DisplayLabel
@onready var message: Label = $KeypadUI/Panel/VBoxContainer/MessageLabel
@onready var buttons_grid: GridContainer = $KeypadUI/Panel/VBoxContainer/GridContainer
@onready var clear_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonClear
@onready var zero_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonZero
@onready var ok_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonOK
@onready var anim_player: AnimationPlayer = $"../../AnimationPlayer"

func _ready():
	ui.visible = false
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

	display.text = ""
	message.text = ""

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# przyciski 1–9
	for button in buttons_grid.get_children():
		if button is Button:
			button.pressed.connect(_on_digit_pressed.bind(button.text))

	# 0, C, OK
	zero_button.pressed.connect(_on_digit_pressed.bind("0"))
	clear_button.pressed.connect(_on_clear_pressed)
	ok_button.pressed.connect(_on_ok_pressed)

func _process(_delta):
	if player_in_range and not ui_open and Input.is_action_just_pressed("interact"):
		open_ui()

func open_ui():
	ui.visible = true
	ui_open = true
	current_input = ""
	display.text = ""
	message.text = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_ui():
	ui.visible = false
	ui_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if not ui_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()

# =========================
# LOGIKA PRZYCISKÓW
# =========================

func _on_digit_pressed(digit: String):
	if current_input.length() >= max_digits:
		return

	current_input += digit
	display.text = current_input

func _on_clear_pressed():
	current_input = ""
	display.text = ""
	message.text = ""

func _on_ok_pressed():
	if current_input == "":
		message.text = "Wpisz kod."
		return

	if current_input == correct_code:
		message.text = "✔ Poprawny kod."
		emit_signal("keypad_unlocked")
		await get_tree().create_timer(0.6).timeout
		close_ui()
	else:
		message.text = "✘ Błędny kod."
		_on_clear_pressed()

# =========================
# AREA
# =========================

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		player_in_range = false
