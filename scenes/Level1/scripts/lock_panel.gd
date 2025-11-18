extends Panel
class_name LockPanel

@export var correct_code: Array[int] = [4, 2, 7]
@export var auto_check: bool = false

@export var block_actions: Array[StringName] = [&"inventory", &"ui_cancel"] 
@export var close_on_esc: bool = false  # czy panel zamyka się na Esc

@export var freeze_world: bool = true  # czy zatrzymać świat gry przy otwarciu panelu
@export var manage_mouse: bool = true  # czy zarządzać widocznością i blokowaniem myszy

@export var check_button: Button
@export var close_button: Button

@export var anim_player: AnimationPlayer

@onready var shaker: Control = $Shaker

signal unlocked

var guess: Array[int] = []
@onready var wheels_container: Node = $"Shaker/HBoxContainer"
var wheels: Array[LockWheel] = []
var _prev_paused: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	for child in wheels_container.get_children():
		if child is LockWheel:
			wheels.append(child)
	guess.resize(wheels.size())
	for i in range(wheels.size()):
		wheels[i].index = i
		wheels[i].value_changed.connect(_on_wheel_changed)
		guess[i] = wheels[i].value
	
	if check_button:
		check_button.pressed.connect(_on_check_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


func _on_wheel_changed(index: int, value: int) -> void:
	guess[index] = value
	if auto_check:
		_check()

func _on_check_pressed() -> void:
	print("Sprawdzam kod:", guess)
	_check()

func _on_close_pressed() -> void:
	close_panel()

func _check() -> void:
	if guess == correct_code:
		unlocked.emit()
		close_panel()
	else:
		_play_wrong_animation()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event.is_pressed():
		return
	for action in block_actions:
		if event.is_action_pressed(action, false):
			if close_on_esc and action == "ui_cancel":
				close_panel()
			get_viewport().set_input_as_handled()
			return

func open_panel() -> void:
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if freeze_world:
		_prev_paused = get_tree().paused
		get_tree().paused = true
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_set_subtree_process_mode(self, Node.PROCESS_MODE_WHEN_PAUSED)
	show()
	grab_focus()

func close_panel() -> void:
	hide()
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if freeze_world:
		_set_subtree_process_mode(self, Node.PROCESS_MODE_INHERIT)
		get_tree().paused = _prev_paused

func _set_subtree_process_mode(node: Node, mode: int) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_subtree_process_mode(child, mode)

func _play_wrong_animation() -> void:
	print("Niepoprawny kod!")
	if anim_player and anim_player.has_animation("answer_lock"):
		shaker.position = Vector2.ZERO
		anim_player.stop(true)
		anim_player.play("answer_lock")
	else:
		push_warning("AnimationPlayer or animation 'answer_lock' not found.")
