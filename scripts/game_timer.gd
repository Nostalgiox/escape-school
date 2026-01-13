# TeacherTimer.gd
# Godot 4.x

extends Node

# --- SYGNAŁY ---
signal cutscene_started()
signal cutscene_ended()
signal timer_updated(remaining_seconds : int)
signal timer_finished()

# --- EXPORTY (USTAW W INSPECTORZE) ---
@export var total_time_seconds : int = 30 * 60        # całkowity czas gry
@export var interval_seconds : int = 60 * 60          # 3600s -> nauczycielka praktycznie nigdy
@export var fallback_cutscene_duration : float = 10.0

@export var teacher_path : NodePath = NodePath("")
@export var teacher_visual_path : NodePath = NodePath("")
@export var teacher_camera_path : NodePath = NodePath("")
@export var monolog_ui_path : NodePath = NodePath("")

@export var hints : Array = ["Spójrz na zegar.", "Może klucz jest w szufladzie.", "Pomyśl o równaniu z zadania."]

@export var monolog_method_name : String = "show_hint"
@export var monolog_finished_signal_name : String = "monolog_finished"

# --- UI PORAŻKI (EXPORTY) ---
@export var fail_panel : Control
@export var fail_label : Label
@export var retry_button : Button

# --- INTERNAL ---
var _teacher : Node = null
var _teacher_visual : Node = null
var _teacher_camera : Node = null
var _monolog_ui : Node = null
var _hint_index : int = 0

var _countdown_timer : Timer
var _interval_timer : Timer
var _tick_timer : Timer

var _cutscene_running : bool = false

const BLOCKED_ACTIONS := [
	"ui_cancel",
	"inventory",
	"interact",
	"ui_accept"
]
var _cutscene_active: bool = false



# --- READY ---
func _ready() -> void:
	# resolve nodes
	if teacher_path != NodePath(""):
		_teacher = get_node_or_null(teacher_path)
	if teacher_visual_path != NodePath(""):
		_teacher_visual = get_node_or_null(teacher_visual_path)
	if teacher_camera_path != NodePath(""):
		_teacher_camera = get_node_or_null(teacher_camera_path)
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)

	# ukryj wizual nauczycielki
	if _teacher_visual:
		_safe_set_visible(_teacher_visual, false)

	# kamery
	if _teacher_camera and (_teacher_camera is Camera3D or _teacher_camera is Camera2D):
		_teacher_camera.current = false

	# --- TIMERY ---
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = float(total_time_seconds)
	_countdown_timer.one_shot = true
	add_child(_countdown_timer)
	_countdown_timer.timeout.connect(_on_countdown_finished)

	_interval_timer = Timer.new()
	_interval_timer.wait_time = float(interval_seconds)
	_interval_timer.one_shot = false
	add_child(_interval_timer)
	_interval_timer.timeout.connect(_on_interval_timeout)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick)

	_countdown_timer.start()
	_interval_timer.start()
	_tick_timer.start()

	# UI porażki
	if fail_panel:
		fail_panel.visible = false

	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)

	emit_signal("timer_updated", int(_remaining_seconds()))
	print("TeacherTimer ready — total:", total_time_seconds)


# --- TIMER TICK ---
func _on_tick() -> void:
	emit_signal("timer_updated", int(_remaining_seconds()))

func _remaining_seconds() -> int:
	if _countdown_timer:
		return int(ceil(_countdown_timer.time_left))
	return 0


# --- KONIEC CZASU (SEDNO) ---
func _on_countdown_finished() -> void:
	emit_signal("timer_updated", 0)
	emit_signal("timer_finished")

	if _interval_timer:
		_interval_timer.stop()
	if _tick_timer:
		_tick_timer.stop()

	_show_fail_panel()


# --- PANEL PORAŻKI ---
func _show_fail_panel() -> void:
	print("[TeacherTimer] Time over — showing fail panel")

	if fail_label:
		fail_label.text = "Nie udało Ci się ukończyć gry.\nSpróbuj ponownie."

	if fail_panel:
		fail_panel.visible = true

	# pokaż mysz (UI)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_retry_pressed() -> void:
	print("[TeacherTimer] Retry pressed — reload level1")
	get_tree().change_scene_to_file("res://scenes/menu_glowne.tscn")


# --- INTERWAŁ (NAUCZYCIELKA, ALE PRAKTYCZNIE WYŁĄCZONA) ---
func _on_interval_timeout() -> void:
	if _cutscene_running:
		return
	if _countdown_timer.time_left <= 0:
		return
	play_teacher_cutscene()


# --- CUTSCENE (ZOSTAWIONE, ALE NIE UŻYWANE) ---
func play_teacher_cutscene() -> void:
	_cutscene_running = true
	emit_signal("cutscene_started")

	await get_tree().create_timer(fallback_cutscene_duration).timeout
	_end_cutscene()


func _end_cutscene() -> void:
	if _teacher_visual:
		_safe_set_visible(_teacher_visual, false)

	if _teacher_camera and (_teacher_camera is Camera3D or _teacher_camera is Camera2D):
		_teacher_camera.current = false

	_cutscene_running = false
	emit_signal("cutscene_ended")

func _input(event: InputEvent) -> void:
	if not _cutscene_running:
		return

	for action in BLOCKED_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return



# --- HELPERY ---
func _safe_set_visible(node: Node, value: bool) -> void:
	if node == null:
		return
	if node.has_method("show") and node.has_method("hide"):
		if value:
			node.show()
		else:
			node.hide()
