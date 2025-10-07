extends Control

var config_path = "user://settings.cfg"

var _dirty = false #czy są niezapisane zmiany
var _suppress = false #czy ignorować oznaczanie zmian

var applied_settings = {}

#Zakładki
@onready var zapisz_btn = $Zapisz
@onready var grafika_btn = $VBoxContainer/HBoxContainer/Grafika
@onready var dzwiek_btn = $VBoxContainer/HBoxContainer/Dzwiek
@onready var sterowanie_btn = $VBoxContainer/HBoxContainer/Sterowanie
@onready var inne_btn = $VBoxContainer/HBoxContainer/Inne
@onready var wstecz_btn = $VBoxContainer/HBoxContainer/Wstecz

#Panele
@onready var grafika_panel = $VBoxContainer/PanelContainer/GrafikaPanel
@onready var dzwiek_panel = $VBoxContainer/PanelContainer/DzwiekPanel
@onready var sterowanie_panel = $VBoxContainer/PanelContainer/SterowaniePanel
@onready var inne_panel = $VBoxContainer/PanelContainer/InnePanel

#Elementy panelu graficznego
@onready var fullscreen_checkbox = grafika_panel.get_node("FullscreenCheck")
@onready var resolution_dropdown = grafika_panel.get_node("ResolutionOption")
@onready var vsync_checkbox = grafika_panel.get_node("VSYNCCheck")
@onready var gamma_slider = grafika_panel.get_node("HBoxContainer/GammaSlider")
@onready var fov_slider = grafika_panel.get_node("HBoxContainer2/FOVSlider")
@onready var shadows_option = grafika_panel.get_node("ShadowsOption")
@onready var textures_option = grafika_panel.get_node("TexturesOption")

#Elementy panelu sterowania
@onready var mouse_sensitivity_slider = sterowanie_panel.get_node("MouseSensitivitySlider")

#Elementy panelu dzwieku
# --- Dźwięk ---
@onready var music_volume_slider = dzwiek_panel.get_node("HBoxContainer4/MusicVolumeSlider")
@onready var sfx_volume_slider = dzwiek_panel.get_node("HBoxContainer2/SFXVolumeSlider")
@onready var mute_checkbox = dzwiek_panel.get_node("MuteCheckbox")

@onready var click_player = $AudioStreamPlayer
@onready var volume_slider = $VBoxContainer/PanelContainer/DzwiekPanel/HBoxContainer/volume_slider

@export var main_menu_container : Control  # przeciągnij CenterContainer w edytorze


func _ready():
	print("Poprzednia scena:", Global.previous_scene_path)
	grafika_btn.pressed.connect(func(): show_panel("grafika"))
	dzwiek_btn.pressed.connect(func(): show_panel("dzwiek"))
	sterowanie_btn.pressed.connect(func(): show_panel("sterowanie"))
	inne_btn.pressed.connect(func(): show_panel("inne"))
	wstecz_btn.pressed.connect(_on_wstecz_pressed)
	
	zapisz_btn.pressed.connect(_on_zapisz_pressed)
	zapisz_btn.visible = false
	
	#Obsługa zmian ustawień
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	resolution_dropdown.item_selected.connect(_on_resolution_selected)
	vsync_checkbox.toggled.connect(_on_vsync_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	mute_checkbox.toggled.connect(_on_mute_toggled)

	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)

	gamma_slider.value_changed.connect(_on_gamma_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	shadows_option.item_selected.connect(_on_shadows_selected)
	textures_option.item_selected.connect(_on_textures_selected)

	# Wypełnienie opcji jakości
	shadows_option.clear()
	shadows_option.add_item("Niskie")
	shadows_option.add_item("Średnie")
	shadows_option.add_item("Wysokie")

	textures_option.clear()
	textures_option.add_item("Niskie")
	textures_option.add_item("Średnie")
	textures_option.add_item("Wysokie")
	
	_populate_resolutions()
	
	_suppress = true
	load_settings()
	apply_settings()
	applied_settings = get_current_settings()
	_suppress = false
	
	show_panel("grafika")  # domyślnie pokaż grafikę

	#var db = AudioServer.get_bus_volume_db(0)
	#volume_slider.value = db_to_linear(db)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_player.play()

func show_panel(name: String):
	# Ukryj wszystkie
	grafika_panel.visible = false
	dzwiek_panel.visible = false
	sterowanie_panel.visible = false
	inne_panel.visible = false
	
	match name:
		"grafika":
			grafika_panel.visible = true
		"dzwiek":
			dzwiek_panel.visible = true
		"sterowanie":
			sterowanie_panel.visible = true
		"inne":
			inne_panel.visible = true

func _on_fullscreen_toggled(pressed: bool):
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	if not _suppress:
		_set_dirty(true)

func _on_resolution_selected(index: int):
	var res = resolution_dropdown.get_item_text(index).split("x")
	if res.size() == 2:
		var width = int(res[0])
		var height = int(res[1])
		#DisplayServer.window_set_size(Vector2(width, height))
	if not _suppress:
		_set_dirty(true)

func _on_vsync_toggled(pressed: bool):
	#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)
	if not _suppress:
		_set_dirty(true)

func _on_wstecz_pressed():
	if _dirty: #jezeli sa niezapisane zmiany
		_restore_settings(applied_settings) #przywroc stare ustawienia
	self.visible = false
	get_parent().get_node("CenterContainer").visible = true
  

func _on_volume_changed(value):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(0, db)
	if not _suppress:
		_set_dirty(true)

# Przeliczanie z decybeli na wartość liniową (0.0–1.0)
func db_to_linear(db):
	return pow(10, db / 20)

# Przeliczanie z liniowej wartości (0.0–1.0) na decybele
func linear_to_db(linear):
	if linear <= 0:
		return -80  # cisza
	return 20 * log(linear)

#cfg
func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(config_path) == OK:
		fullscreen_checkbox.button_pressed = cfg.get_value("graphics", "fullscreen", false)
		var res_text = str(cfg.get_value("graphics", "resolution", "1280x720"))
		var idx = -1
		for i in range(resolution_dropdown.item_count):
			if resolution_dropdown.get_item_text(i) == res_text:
				idx = i
				#idx = 1
				break
		if idx == -1:
			idx = 0
		resolution_dropdown.select(idx)
		
		vsync_checkbox.button_pressed = cfg.get_value("graphics", "vsync", true)
		volume_slider.value = cfg.get_value("audio", "volume", 1.0)
		music_volume_slider.value = cfg.get_value("audio", "music_volume", 0.8)
		sfx_volume_slider.value = cfg.get_value("audio", "sfx_volume", 0.8)
		mute_checkbox.button_pressed = cfg.get_value("audio", "mute", false)

		# --- 🎮 Sterowanie ---
		mouse_sensitivity_slider.value = cfg.get_value("controls", "mouse_sensitivity", 0.5)

		# --- 🖥️ Grafika ---
		gamma_slider.value = cfg.get_value("graphics", "gamma", 1.0)
		fov_slider.value = cfg.get_value("graphics", "fov", 75)
		shadows_option.select(cfg.get_value("graphics", "shadows", 1))
		textures_option.select(cfg.get_value("graphics", "textures", 1))
func _populate_resolutions():
	var resolutions = [
		"1280x720",
		"1600x900",
		"1920x1080",
		"2560x1440",
		"3840x2160"
	]
	resolution_dropdown.clear()
	for res in resolutions:
		resolution_dropdown.add_item(res)

func _set_dirty(dirty: bool = true):
	_dirty = dirty
	if is_instance_valid(zapisz_btn):
		zapisz_btn.visible = dirty

func _on_zapisz_pressed():
	save_settings()
	apply_settings()
	applied_settings = get_current_settings()
	_set_dirty(false)

# --- 🎮 Sterowanie ---
func _on_mouse_sensitivity_changed(value: float) -> void:
	if not _suppress:
		_set_dirty(true)

# --- 🔊 Dźwięk ---
func _on_music_volume_changed(value: float) -> void:
	if not _suppress:
		_set_dirty(true)

func _on_sfx_volume_changed(value: float) -> void:
	if not _suppress:
		_set_dirty(true)

func _on_mute_toggled(pressed: bool) -> void:
	if pressed:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
	if not _suppress:
		_set_dirty(true)

# --- 🖥️ Grafika ---
func _on_gamma_changed(value: float) -> void:
	if not _suppress:
		_set_dirty(true)

func _on_fov_changed(value: float) -> void:
	if not _suppress:
		_set_dirty(true)

func _on_shadows_selected(index: int) -> void:
	if not _suppress:
		_set_dirty(true)

func _on_textures_selected(index: int) -> void:
	if not _suppress:
		_set_dirty(true)

func save_settings():
	var cfg := ConfigFile.new()
	var _err = cfg.load(config_path)  # jeśli plik nie istnieje, save() i tak go utworzy

	# grafika
	cfg.set_value("graphics", "fullscreen", fullscreen_checkbox.button_pressed)

	var res_text := "1280x720"
	if resolution_dropdown.selected >= 0:
		res_text = resolution_dropdown.get_item_text(resolution_dropdown.selected)
	cfg.set_value("graphics", "resolution", res_text)

	cfg.set_value("graphics", "vsync", vsync_checkbox.button_pressed)

	# audio
	cfg.set_value("audio", "volume", volume_slider.value)

	# --- 🔊 Dźwięk ---
	cfg.set_value("audio", "music_volume", music_volume_slider.value)
	cfg.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	cfg.set_value("audio", "mute", mute_checkbox.button_pressed)

	# --- 🎮 Sterowanie ---
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity_slider.value)

	# --- 🖥️ Grafika ---
	cfg.set_value("graphics", "gamma", gamma_slider.value)
	cfg.set_value("graphics", "fov", fov_slider.value)
	cfg.set_value("graphics", "shadows", get_current_settings()["shadows"])
	cfg.set_value("graphics", "textures", get_current_settings()["textures"])


	var err := cfg.save(config_path)
	if err != OK:
		push_warning("Nie udało się zapisać ustawień, kod błędu: %s" % [err])

func apply_settings():
	# grafika
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_checkbox.button_pressed
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

	if resolution_dropdown.selected >= 0:
		var res_text = resolution_dropdown.get_item_text(resolution_dropdown.selected)
		var parts = res_text.split("x")
		if parts.size() == 2:
			var w = int(parts[0])
			var h = int(parts[1])
			DisplayServer.window_set_size(Vector2i(w, h))

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_checkbox.button_pressed
		else DisplayServer.VSYNC_DISABLED
	)

	# audio
	AudioServer.set_bus_volume_db(0, linear_to_db(volume_slider.value))

	# --- 🔊 Dźwięk ---
	if mute_checkbox.button_pressed:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)

	# --- 🎮 Sterowanie ---
	Global.mouse_sensitivity = mouse_sensitivity_slider.value

	# --- 🖥️ Grafika ---
	# Przykładowe zastosowanie gamma i FOV, jeśli masz środowisko
	# if get_viewport().get_environment():
	# 	var env = get_viewport().get_environment()
	# 	env.adjustment_enabled = true
	# 	env.adjustment_brightness = gamma_slider.value

	Global.fov = fov_slider.value
	var shadow_index = 0
	var texture_index = 0

	var shadow_items = shadows_option.get_selected_items()
	if shadow_items.size() > 0:
		shadow_index = shadow_items[0]

	var texture_items = textures_option.get_selected_items()
	if texture_items.size() > 0:
		texture_index = texture_items[0]

	Global.shadow_quality = shadow_index
	Global.texture_quality = texture_index

func get_current_settings():
	var shadow_index = 0
	var texture_index = 0

	var shadow_items = shadows_option.get_selected_items()
	if shadow_items.size() > 0:
		shadow_index = shadow_items[0]

	var texture_items = textures_option.get_selected_items()
	if texture_items.size() > 0:
		texture_index = texture_items[0]
	return {
		"fullscreen": fullscreen_checkbox.button_pressed,
		"resolution": resolution_dropdown.selected,
		"vsync": vsync_checkbox.button_pressed,
		"volume": volume_slider.value,
		"gamma": gamma_slider.value,
		"music_volume": music_volume_slider.value,
		"sfx_volume": sfx_volume_slider.value,
		"mute": mute_checkbox.button_pressed,
		"mouse_sensitivity": mouse_sensitivity_slider.value,
		"fov": fov_slider.value,
		"shadows": shadow_index,
		"textures": texture_index
	}

func _restore_settings(s):
	_suppress = true
	fullscreen_checkbox.button_pressed = s["fullscreen"]
	resolution_dropdown.select(s["resolution"])
	vsync_checkbox.button_pressed = s["vsync"]
	volume_slider.value = s["volume"]
	music_volume_slider.value = s["music_volume"]
	sfx_volume_slider.value = s["sfx_volume"]
	mute_checkbox.button_pressed = s["mute"]

	mouse_sensitivity_slider.value = s["mouse_sensitivity"]

	gamma_slider.value = s["gamma"]
	fov_slider.value = s["fov"]
	shadows_option.deselect_all()
	shadows_option.select(s["shadows"])

	textures_option.deselect_all()
	textures_option.select(s["textures"])

	_suppress = false
	apply_settings() #zastosuj z powrotem co bylo
