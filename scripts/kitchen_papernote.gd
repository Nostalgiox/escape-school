extends Node3D

signal note_solved

@export var panel_path: NodePath
@export var answer_input_path: NodePath
@export var answer_button_path: NodePath
@export var correct_answer: String = "1"

@onready var panel: Control = get_node(panel_path)
@onready var answer_input: LineEdit = get_node(answer_input_path)
@onready var answer_button: Button = get_node(answer_button_path)
@onready var area: Area3D = $Area3D
@export var audio: AudioStreamPlayer

var player_in_range := false
var panel_open := false
var prev_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	panel.visible = false
	answer_input.text = ""

	answer_input.text_submitted.connect(_on_answer_submitted)
	answer_button.pressed.connect(_on_ok_pressed)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_in_range and not panel_open:
		if Input.is_action_just_pressed("interact"):
			_open_panel()


# ======================
# PANEL
# ======================

func _open_panel() -> void:
	panel.visible = true
	panel_open = true

	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	answer_input.text = ""
	answer_input.placeholder_text = "Wpisz liczbę"
	answer_input.grab_focus()


func _close_panel() -> void:
	panel.visible = false
	panel_open = false
	Input.mouse_mode = prev_mouse_mode


# ======================
# ODPOWIEDŹ
# ======================

func _on_ok_pressed() -> void:
	_check_answer(answer_input.text)


func _on_answer_submitted(text: String) -> void:
	_check_answer(text)


func _check_answer(text: String) -> void:
	if text.strip_edges() == "":
		answer_input.placeholder_text = "Najpierw wpisz odpowiedź"
		return

	if text.strip_edges() == correct_answer:
		_on_correct_answer()
	else:
		answer_input.text = ""
		answer_input.placeholder_text = "Błędna odpowiedź"


func _on_correct_answer() -> void:
	_close_panel()
	audio.play()
	emit_signal("note_solved")


# ======================
# BLOKADY INPUTU
# ======================

func _input(event: InputEvent) -> void:
	if not panel_open:
		return

	# blok inventory
	if event.is_action_pressed("inventory", false):
		get_viewport().set_input_as_handled()
		return

	# ESC zamyka panel (blokuje pause)
	if event.is_action_pressed("ui_cancel", false):
		_close_panel()
		get_viewport().set_input_as_handled()
		return


# ======================
# AREA
# ======================

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
