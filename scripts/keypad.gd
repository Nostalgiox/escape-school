extends Node3D

signal keypad_unlocked
signal keypad_locked

@export var correct_code: String = "27"
@export var max_digits: int = 3
@export var max_attempts: int = 3
@export var lockout_time: float = 120.0 # 2 minuty

var player_in_range := false
var ui_open := false
var current_input := ""
var failed_attempts := 0
var locked := false
var lock_timer := 0.0

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $KeypadUI
@onready var display: Label = $KeypadUI/Panel/VBoxContainer/DisplayLabel
@onready var message: Label = $KeypadUI/Panel/VBoxContainer/MessageLabel
@onready var buttons_grid: GridContainer = $KeypadUI/Panel/VBoxContainer/GridContainer
@onready var clear_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonClear
@onready var zero_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonZero
@onready var ok_button: Button = $KeypadUI/Panel/VBoxContainer/HBoxContainer/ButtonOK
@onready var anim_player: AnimationPlayer = $"../../AnimationPlayer"
@onready var wrong_answer: AudioStreamPlayer = $Wrong_answer
@onready var cooldown_label: Label3D = $CooldownLabel3D

func _ready():
	ui.visible = false
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

	display.text = ""
	message.text = ""

	cooldown_label.visible = false

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	for button in buttons_grid.get_children():
		if button is Button:
			button.pressed.connect(_on_digit_pressed.bind(button.text))

	zero_button.pressed.connect(_on_digit_pressed.bind("0"))
	clear_button.pressed.connect(_on_clear_pressed)
	ok_button.pressed.connect(_on_ok_pressed)

func _process(delta):
	if locked:
		lock_timer -= delta
		_update_cooldown_label()
		if lock_timer <= 0.0:
			_unlock_keypad()
		return

	if player_in_range and not ui_open and Input.is_action_just_pressed("interact"):
		open_ui()

func open_ui():
	if locked:
		return
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
	if locked:
		return
	if current_input.length() >= max_digits:
		return
	current_input += digit
	display.text = current_input

func _on_clear_pressed():
	current_input = ""
	display.text = ""
	message.text = ""

func _on_ok_pressed():
	if locked:
		return

	if current_input == "":
		message.text = "Wpisz kod."
		return

	if current_input == correct_code:
		message.text = "✔ Poprawny kod."
		emit_signal("keypad_unlocked")
		await get_tree().create_timer(0.6).timeout
		close_ui()
	else:
		failed_attempts += 1
		wrong_answer.play()
		message.text = "✘ Błędny kod."
		_on_clear_pressed()

		if failed_attempts >= max_attempts:
			_activate_lockout()

# =========================
# BLOKADA
# =========================

func _activate_lockout():
	locked = true
	lock_timer = lockout_time
	failed_attempts = 0
	close_ui()

	area.monitoring = false
	cooldown_label.visible = true
	_update_cooldown_label()
	emit_signal("keypad_locked")

func _unlock_keypad():
	locked = false
	area.monitoring = true
	cooldown_label.visible = false
	message.text = ""

func _update_cooldown_label():
	var seconds := int(max(lock_timer, 0))
	var minutes := seconds / 60
	var secs := seconds % 60
	cooldown_label.text = "%02d:%02d" % [minutes, secs]

# =========================
# AREA
# =========================

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		player_in_range = false
