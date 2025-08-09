extends Control

var config_path = "user://settings.cfg"

var _dirty = false #czy są niezapisane zmiany
var _suppress = false #czy ignorować oznaczanie zmian

#Zakładki
@onready var zapisz_btn = $VBoxContainer/HBoxContainer/Zapisz
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

@onready var click_player = $AudioStreamPlayer
@onready var volume_slider = $VBoxContainer/PanelContainer/DzwiekPanel/HBoxContainer/volume_slider

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
	
	_populate_resolutions()
	
	_suppress = true
	load_settings()
	apply_settings()
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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	if not _suppress:
		_set_dirty(true)

func _on_resolution_selected(index: int):
	var res = resolution_dropdown.get_item_text(index).split("x")
	if res.size() == 2:
		var width = int(res[0])
		var height = int(res[1])
		DisplayServer.window_set_size(Vector2(width, height))
	if not _suppress:
		_set_dirty(true)

func _on_vsync_toggled(pressed: bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)
	if not _suppress:
		_set_dirty(true)

func _on_wstecz_pressed():
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
				idx = 1
				break
		if idx == -1:
			idx = 0
		resolution_dropdown.select(idx)
		
		vsync_checkbox.button_pressed = cfg.get_value("graphics", "vsync", true)
		volume_slider.value = cfg.get_value("audio", "volume", 1.0)

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
	_set_dirty(false)

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
