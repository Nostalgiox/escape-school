extends Area3D

@onready var info_panel = $CanvasLayer/InfoPanel
@onready var info_label = $CanvasLayer/InfoPanel/InfoLabel
@onready var animator: AnimationPlayer = $AnimationPlayer
@onready var button = $CanvasLayer/InfoPanel/Button
@onready var exclamation = $Exclamation

@export var door: NodePath
@export_multiline var note_text: String = "" # jeśli puste, użyj tego co wpisane w InfoLabel
@export var type_cps: float = 45.0 # litery na sekundę
@export var pause_mult_fullstop: float = 6.0 # pauza po . ! ?
@export var pause_mult_comma: float = 3.0 # pauza po , ; :

var door_node: Node = null
var player_in_range: bool = false
var note_read: bool = false

var _typing: bool = false
var _skip: bool = false
var _full_text: String = ""
var _index: int = 0
var _type_timer: Timer = null

func _ready():
	animator.play("1")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	# Timer do efektu pisania
	_type_timer = Timer.new()
	_type_timer.one_shot = false
	add_child(_type_timer)
	_type_timer.timeout.connect(_on_type_tick)
	if door != null:
		door_node = get_node(door)

func _process(delta):
	# if player_in_range and Input.is_action_just_pressed("interact"):
	# 	var opening = not info_panel.visible
	# 	info_panel.visible = opening
	# 	info_panel.grab_focus()
	# 	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) else Input.MOUSE_MODE_CAPTURED
	# 	if opening and not note_read:
	# 		note_read = true
	# 		if door_node:
	# 			door_node.unlock()
	if player_in_range and Input.is_action_just_pressed("interact"):
		if info_panel.visible:
			close_note()
		else:
			open_note()
			if not note_read:
				note_read = true
				#if door_node and door_node.has_method("unlock"):
					#door_node.unlock()

# SKIP typewriter (LPM lub Enter) – przechwytujemy, gdy panel widoczny i trwa pisanie
func _input(event: InputEvent) -> void:
	if not info_panel.visible or not _typing:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept", false):
		_skip = true
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "PlayerBody":
		player_in_range = false
		if info_panel.visible:
			close_note()

func open_note():
	info_panel.show()
	info_panel.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_typewriter()

func close_note():
	info_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	exclamation.visible = false
	_stop_typewriter()

# --- TYPEWRITER (Timer + visible_characters) ---
func _start_typewriter() -> void:
	if not info_label:
		return
	_full_text = note_text.strip_edges() if note_text.strip_edges() != "" else info_label.text
	_index = 0
	_typing = true
	_skip = false

	info_label.text = _full_text
	info_label.visible_characters = 0

	if _type_timer:
		_type_timer.wait_time = maxf(1.0 / maxf(type_cps, 1.0), 0.001)
		_type_timer.start()

func _stop_typewriter() -> void:
	_typing = false
	_skip = false
	_index = 0
	if _type_timer:
		_type_timer.stop()
	if info_label:
		info_label.visible_characters = -1

func _on_type_tick() -> void:
	if not _typing or not info_panel.visible:
		_stop_typewriter()
		return

	if _skip:
		info_label.visible_characters = -1
		_stop_typewriter()
		return

	_index += 1
	info_label.visible_characters = _index

	if _index >= _full_text.length():
		_stop_typewriter()
		return

	var ch: String = _full_text.substr(_index - 1, 1)
	var base: float = maxf(1.0 / maxf(type_cps, 1.0), 0.001)
	if ch == "." or ch == "!" or ch == "?":
		_type_timer.wait_time = base * pause_mult_fullstop
	elif ch == "," or ch == ":" or ch == ";":
		_type_timer.wait_time = base * pause_mult_comma
	else:
		_type_timer.wait_time = base
