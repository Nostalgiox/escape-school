extends Node3D

@export var correct_code: int = 24
@export var door_anim_player_path: NodePath
@export var open_anim_name: String = "Secondroom_exit_open"

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $CanvasLayer
@onready var panel: Control = $CanvasLayer/Panel
@onready var display: LineEdit = $CanvasLayer/Panel/MarginContainer/HBoxContainer/VBoxContainer/LineEdit
@onready var message: Label = $CanvasLayer/Panel/MarginContainer/HBoxContainer/VBoxContainer/LabelMessage
@onready var keypad: GridContainer = $CanvasLayer/Panel/MarginContainer/HBoxContainer/VBoxContainer/GridContainer

var player_in_range := false
var input_value := ""

var prev_mouse_mode := Input.MOUSE_MODE_CAPTURED

@onready var door_anim: AnimationPlayer = get_node_or_null(door_anim_player_path)

# ========================
# READY
# ========================

func _ready() -> void:
	ui.visible = false
	panel.visible = false
	display.text = ""
	display.editable = false
	message.text = ""

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	for button in keypad.get_children():
		if button is Button:
			button.pressed.connect(_on_key_pressed.bind(button.text))

# ========================
# PROCESS
# ========================

func _process(_delta: float) -> void:
	if player_in_range and not ui.visible and Input.is_action_just_pressed("interact"):
		_open_ui()

# ========================
# INPUT BLOCKING
# ========================

func _input(event: InputEvent) -> void:
	if not ui.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:

		# ESC – zamyka panel, NIE pause
		if event.is_action_pressed("ui_cancel"):
			_close_ui()
			get_viewport().set_input_as_handled()
			return

		# inventory – blokada
		if event.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			return


# ========================
# UI
# ========================

func _open_ui() -> void:
	ui.visible = true
	panel.visible = true
	input_value = ""
	display.text = ""
	message.text = ""

	prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_ui() -> void:
	ui.visible = false
	panel.visible = false
	Input.set_mouse_mode(prev_mouse_mode)

# ========================
# KEYPAD LOGIC
# ========================

func _on_key_pressed(key: String) -> void:
	if key == "C":
		input_value = ""
		display.text = ""
		message.text = ""
		return

	if key == "OK":
		_check_code()
		return

	# max 2 cyfry
	if input_value.length() >= 2:
		return

	if key.is_valid_int():
		input_value += key
		display.text = input_value

func _check_code() -> void:
	if input_value == "":
		message.text = "Wpisz kod."
		message.modulate = Color.RED
		return

	if int(input_value) == correct_code:
		message.text = "✔ POPRAWNY KOD"
		message.modulate = Color.GREEN
		await get_tree().create_timer(0.6).timeout
		_open_door()
		_close_ui()
	else:
		message.text = "✘ BŁĘDNY KOD"
		message.modulate = Color.RED
		input_value = ""
		display.text = ""

# ========================
# DOOR
# ========================

func _open_door() -> void:
	if door_anim and door_anim.has_animation(open_anim_name):
		door_anim.play(open_anim_name)
	else:
		push_warning("Nie znaleziono AnimationPlayer lub animacji drzwi.")

# ========================
# AREA
# ========================

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
