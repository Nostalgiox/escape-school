# notes.gd – wspólny skrypt dla wszystkich notatek
extends Node3D

@export_group("UI Paths")
@export var panel_path: NodePath
@export var left_label_path: NodePath
@export var right_label_path: NodePath

@export_group("Texts")
@export var left_text: String = ""
@export var right_text: String = ""

@onready var panel: Control = get_node(panel_path)
@onready var left_label: RichTextLabel = get_node(left_label_path)
@onready var right_label: RichTextLabel = get_node(right_label_path)
@onready var area: Area3D = $Area3D

var player_in_range := false


func _ready() -> void:
	print("NOTES READY:", get_path())

	# HARD RESET – CanvasLayer i Panel
	panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_in_range and not panel.visible:
		if Input.is_action_just_pressed("interact"):
			show_panel()


func show_panel() -> void:
	left_label.text = ""
	right_label.text = ""

	left_label.append_text(left_text)
	right_label.append_text(right_text)

	panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if panel.has_method("grab_focus"):
		panel.grab_focus()


func hide_panel() -> void:
	panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("ui_cancel", false):
		hide_panel()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
