extends ColorRect

@onready var animator : AnimationPlayer = $AnimationPlayer
@onready var play_button : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_button : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var settings_button : Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton

@onready var inventory_ui : Control = $"../InventoryUI"
@onready var inventory_grid : GridContainer = $"../InventoryUI/Panel/MarginContainer/InventoryGrid"
@onready var main_menu : Control = $CenterContainer

@onready var settings_ui : Control = $SettingsUI

func _ready() -> void:
	settings_ui.visible = false
	inventory_ui.visible = false
	play_button.pressed.connect(unpause)
	settings_button.pressed.connect(settings)
	quit_button.pressed.connect(get_tree().quit)

func unpause():
	animator.play("Unpause")
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func pause():
	animator.play("pause")
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func settings():
	settings_ui.visible = true
	main_menu.visible = false
