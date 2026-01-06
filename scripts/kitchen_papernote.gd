extends Node3D

@export var panel_path: NodePath = NodePath("")   # CanvasLayer/InfoPanel
@export var interact_action := "interact"

@onready var panel: Control = null
@onready var area: Area3D = $Area3D

var player_in_range := false
var panel_open := false
var prev_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# znajdź panel
	if panel_path != NodePath(""):
		panel = get_node_or_null(panel_path) as Control
	else:
		push_error("workstation_note.gd: panel_path nie ustawiony")

	if panel:
		panel.visible = false

	# Area3D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_in_range and not panel_open:
		if Input.is_action_just_pressed(interact_action):
			_open_panel()


func _open_panel() -> void:
	if not panel:
		return

	panel.visible = true
	panel_open = true

	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# zatrzymujemy input gry
	get_tree().paused = false  # WAŻNE: nie pauzujemy gry globalnie

	# focus (opcjonalne)
	if panel.has_method("grab_focus"):
		panel.grab_focus()


func _close_panel() -> void:
	if not panel:
		return

	panel.visible = false
	panel_open = false
	Input.mouse_mode = prev_mouse_mode


# =========================
# AREA
# =========================

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false


# =========================
# INPUT BLOKADY
# =========================

func _input(event: InputEvent) -> void:
	if not panel_open:
		return

	# BLOK INVENTORY
	if event.is_action_pressed("inventory", false):
		get_viewport().set_input_as_handled()
		return

	# BLOK PAUSE + ESC ZAMYKA PANEL
	if event.is_action_pressed("ui_cancel", false):
		_close_panel()
		get_viewport().set_input_as_handled()
		return
