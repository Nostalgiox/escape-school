extends Control

@onready var zagraj_btn = $CenterContainer/VBoxContainer/Zagraj
@onready var ustawienia_btn = $CenterContainer/VBoxContainer/Ustawienia
@onready var wyjdz_btn = $CenterContainer/VBoxContainer/Wyjdz
@onready var click_player = $SFX
@onready var music_player = $Music

@onready var settings_ui : Control = $SettingsUI
@onready var menu_container : CenterContainer = $CenterContainer

@onready var anim_player : AnimationPlayer = $AnimationPlayer

@onready var world_view : SubViewportContainer = $WorldView
@onready var world_vp : SubViewport = $WorldView/SubViewport

const HEADROOM_LINEAR = 0.3

func lin_to_db(linear):
	if linear <= 0.0001:
		return -80  # cisza
	return 20 * (log(linear) / log(10.0))

func _ready():

	world_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.z_index = 0
	menu_container.z_index = 10
	settings_ui.z_index = 20

	_resize_world_vp()
	resized.connect(_resize_world_vp)

	anim_player.play("logo_animation")
	settings_ui.visible = false

	_ensure_buses()
	_apply_saved_audio()

	if music_player and not music_player.playing:
		music_player.bus = "Music"
		music_player.stream_paused = false
		music_player.volume_db = -20.0  # Zacznij cicho
		if music_player.stream == null:
			push_warning("Music player has no audio stream assigned!")
		else:

			music_player.play()
			create_tween().tween_property(music_player, "volume_db", lin_to_db(HEADROOM_LINEAR), 0.8)

	# Nie potrzebujesz już grupy ani podpinania pod przyciski
	zagraj_btn.pressed.connect(_on_zagraj_pressed)
	ustawienia_btn.pressed.connect(_on_ustawienia_pressed)
	wyjdz_btn.pressed.connect(_on_wyjdz_pressed)

# func _input(event):
# 	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# 		click_player.play()
func _resize_world_vp():
	if world_vp == null:
		world_vp.get_node_or_null("WorldView/SubViewport")
		if world_vp == null:
			push_warning("Could not find SubViewport node!")
			return
	var r = get_viewport_rect()
	world_vp.size = Vector2i(r.size)


func _ensure_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) == -1:
			var pos = AudioServer.get_bus_count()
			AudioServer.add_bus(pos)
			AudioServer.set_bus_name(pos, name)
			AudioServer.set_bus_send(pos, "Master")

func _apply_saved_audio() -> void:
	var master = 0.8
	var music = 0.8
	var sfx = 0.8
	var cfg = ConfigFile.new()
	var mute = false
	if cfg.load("user://settings.cfg") == OK:
		master = cfg.get_value("audio", "volume", master)
		music = cfg.get_value("audio", "music_volume",music)
		sfx = cfg.get_value("audio", "sfx_volume", sfx)
		mute = cfg.get_value("audio", "mute", mute)
	var mb = AudioServer.get_bus_index("Master")
	var m = AudioServer.get_bus_index("Music")
	var s = AudioServer.get_bus_index("SFX")

	AudioServer.set_bus_volume_db(mb, lin_to_db(master * HEADROOM_LINEAR))
	AudioServer.set_bus_volume_db(m, lin_to_db(music * HEADROOM_LINEAR))
	AudioServer.set_bus_volume_db(s, lin_to_db(sfx * HEADROOM_LINEAR))
	AudioServer.set_bus_mute(mb, mute)

func _on_zagraj_pressed():
	_play_click_sound()

	zagraj_btn.disabled = true
	ustawienia_btn.disabled = true
	wyjdz_btn.disabled = true
	if music_player:
		create_tween().tween_property(music_player, "volume_db", -30.0, 0.3)
	
	var fade = $FadeLayer
	fade.fade_out_with_loading("res://scenes/Game_Main_Menu/prolog.tscn")

func _on_ustawienia_pressed():
	_play_click_sound()
	# Global.previous_scene_path = get_tree().current_scene.scene_file_path
	# get_tree().change_scene_to_file("res://scenes/settings.tscn")
	settings_ui.visible = true
	menu_container.visible = false

func _on_wyjdz_pressed():
	_play_click_sound()
	get_tree().quit()

func _play_click_sound():
	if click_player.playing:
		click_player.stop()
	click_player.play()
