extends Node3D

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $CanvasLayer
@export var monolog: Area3D
@export var mesh: MeshInstance3D

var unlocked := false
var player_in_range := false

func _ready():
	# BLOKADA NA START
	area.monitoring = false
	area.monitorable = false
	ui.visible = false
	mesh.visible = false

func unlock_puzzle():
	unlocked = true
	area.monitoring = true
	area.monitorable = true
	monolog.monitoring = true
	monolog.monitorable = true
	mesh.visible = true
	print("Zagadka 3 odblokowana")

func _process(_delta):
	if unlocked and player_in_range and Input.is_action_just_pressed("interact"):
		open_ui()

func open_ui():
	ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_ui():
	ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_Area3D_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_Area3D_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false


func _on_kitchen_papernote_note_solved() -> void:
	unlock_puzzle()
