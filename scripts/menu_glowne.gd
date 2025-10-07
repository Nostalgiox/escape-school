extends Control

@onready var zagraj_btn = $CenterContainer/VBoxContainer/Zagraj
@onready var ustawienia_btn = $CenterContainer/VBoxContainer/Ustawienia
@onready var wyjdz_btn = $CenterContainer/VBoxContainer/Wyjdz
@onready var click_player = $AudioStreamPlayer

@onready var settings_ui : Control = $SettingsUI
@onready var menu_container : CenterContainer = $CenterContainer

func _ready():

	settings_ui.visible = false
	# Nie potrzebujesz już grupy ani podpinania pod przyciski
	zagraj_btn.pressed.connect(_on_zagraj_pressed)
	ustawienia_btn.pressed.connect(_on_ustawienia_pressed)
	wyjdz_btn.pressed.connect(_on_wyjdz_pressed)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_player.play()

func _on_zagraj_pressed():
	Global.should_fade_in_on_load = true
	get_tree().change_scene_to_file("res://scenes/Game_Main_Menu/prolog.tscn")

func _on_ustawienia_pressed():
	# Global.previous_scene_path = get_tree().current_scene.scene_file_path
	# get_tree().change_scene_to_file("res://scenes/settings.tscn")
	settings_ui.visible = true
	menu_container.visible = false

func _on_wyjdz_pressed():
	get_tree().quit()
