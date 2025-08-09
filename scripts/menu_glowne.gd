extends Control

@onready var zagraj_btn = $VBoxContainer/Zagraj
@onready var ustawienia_btn = $VBoxContainer/Ustawienia
@onready var wyjdz_btn = $VBoxContainer/Wyjdz
@onready var click_player = $AudioStreamPlayer

func _ready():
	# Nie potrzebujesz już grupy ani podpinania pod przyciski
	zagraj_btn.pressed.connect(_on_zagraj_pressed)
	ustawienia_btn.pressed.connect(_on_ustawienia_pressed)
	wyjdz_btn.pressed.connect(_on_wyjdz_pressed)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_player.play()

func _on_zagraj_pressed():
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/Main/level1.tscn")

func _on_ustawienia_pressed():
	await get_tree().create_timer(0.2).timeout
	Global.previous_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_wyjdz_pressed():
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
