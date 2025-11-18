extends Control

var config_path = "user://settings.cfg"

var _dirty = false # czy są niezapisane zmiany
var _suppress = false # czy ignorować oznaczanie zmian

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
@onready var bindings_container: VBoxContainer = sterowanie_panel.get_node("Bindings")

const REBIND_ACTIONS := [
	{"action": "ui_up", "label": "Ruch do przodu"},
	{"action": "ui_down", "label": "Ruch do tyłu"},
	{"action": "ui_left", "label": "Ruch w lewo"},
	{"action": "ui_right", "label": "Ruch w prawo"},
	{"action": "jump", "label": "Skok"},
	{"action": "sprint", "label": "Sprint"},
	{"action": "interact", "label": "Interakcja"},
	{"action": "ui_accept", "label": "Potwierdź"},
	{"action": "ui_cancel", "label": "Anuluj"}
]

var _listen_action: StringName = &""
var _listen_button: Button = null

#Elementy panelu dzwieku
# --- Dźwięk ---
@onready var music_volume_slider = dzwiek_panel.get_node("HBoxContainer4/MusicVolumeSlider")
@onready var sfx_volume_slider = dzwiek_panel.get_node("HBoxContainer2/SFXVolumeSlider")
@onready var mute_checkbox = dzwiek_panel.get_node("MuteCheckbox")


@onready var volume_slider = $VBoxContainer/PanelContainer/DzwiekPanel/HBoxContainer/volume_slider

@onready var MASTER_BUS := AudioServer.get_bus_index("Master")
@onready var MUSIC_BUS := AudioServer.get_bus_index("Music")
@onready var SFX_BUS := AudioServer.get_bus_index("SFX")

@export var main_menu_container: Control # przeciągnij CenterContainer w edytorze


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

	_build_binding_rows()
	
	_suppress = true
	load_settings()
	apply_settings()
	applied_settings = get_current_settings()
	_suppress = false

	_refresh_binding_labels()
	
	show_panel("grafika") # domyślnie pokaż grafikę

	#var db = AudioServer.get_bus_volume_db(0)
	#volume_slider.value = db_to_linear(db)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listen_action == &"":
		return
	if not event.is_pressed() or event.is_echo():
		return

	# ESC = anuluj nasłuchiwanie (nie przypisujemy ESC)
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_cancel_listen()
		accept_event()
		return

	if event is InputEventKey:
		var e := event as InputEventKey
		var ne := InputEventKey.new()
		ne.physical_keycode = e.physical_keycode
		ne.keycode = e.keycode
		ne.shift_pressed = e.shift_pressed
		ne.alt_pressed = e.alt_pressed
		ne.ctrl_pressed = e.ctrl_pressed
		ne.meta_pressed = e.meta_pressed   # <- tu zmiana nazwy właściwości
		ne.pressed = true
		_apply_event_to_action(_listen_action, ne)
		accept_event()
		return
	elif event is InputEventMouseButton:
		var mb := InputEventMouseButton.new()
		mb.button_index = (event as InputEventMouseButton).button_index
		mb.pressed = true
		_apply_event_to_action(_listen_action, mb)
		accept_event()
		return
	elif event is InputEventJoypadButton:
		var jb := InputEventJoypadButton.new()
		jb.button_index = (event as InputEventJoypadButton).button_index
		jb.pressed = true
		_apply_event_to_action(_listen_action, jb)
		accept_event()
		return

	# na wszelki wypadek zjedz inne eventy w trybie nasłuchu, by UI nie reagowało
	accept_event()


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
	if _dirty: # jezeli sa niezapisane zmiany
		_restore_settings(applied_settings) # przywroc stare ustawienia
	self.visible = false
	get_parent().get_node("CenterContainer").visible = true

const HEADROOM_LINEAR = 0.3

# Przeliczanie z decybeli na wartość liniową (0.0–1.0)
func db_to_linear(db):
	return pow(10, db / 20)

# Przeliczanie z liniowej wartości (0.0–1.0) na decybele
func linear_to_db(linear):
	if linear <= 0.0001:
		return -80 # cisza
	return 20 * (log(linear) / log(10.0))

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

		if cfg.has_section_key("controls", "bindings"):
			var map: Dictionary = cfg.get_value("controls", "bindings", {})
			for action in map.keys():
				InputMap.action_erase_events(action)
				for evd in map[action]:
					var ev = _dict_to_event(evd)
					if ev: InputMap.action_add_event(action, ev)

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
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value * HEADROOM_LINEAR))
	if not _suppress:
		_set_dirty(true)

func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value * HEADROOM_LINEAR))
	if not _suppress:
		_set_dirty(true)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(value * HEADROOM_LINEAR))
	if not _suppress:
		_set_dirty(true)

func _on_mute_toggled(pressed: bool) -> void:
	AudioServer.set_bus_mute(MASTER_BUS, pressed)
	if not _suppress:
		_set_dirty(true)

# --- 🖥️ Grafika ---
func _on_gamma_changed(value: float) -> void:
	_apply_gamma_everywhere(value)
	if not _suppress:
		_set_dirty(true)

func _on_fov_changed(value: float) -> void:
	Global.set_fov(value)
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
	var _err = cfg.load(config_path) # jeśli plik nie istnieje, save() i tak go utworzy

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

	var bindings : Dictionary =  {}
	for item in REBIND_ACTIONS:
		var action = item.action
		var arr = []
		for ev in InputMap.action_get_events(action):
			arr.append(_event_to_dict(ev))
		bindings[action] = arr
	cfg.set_value("controls", "bindings", bindings)


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
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(volume_slider.value * HEADROOM_LINEAR))
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(music_volume_slider.value * HEADROOM_LINEAR))
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(sfx_volume_slider.value * HEADROOM_LINEAR))

	# --- 🔊 Dźwięk ---
	AudioServer.set_bus_mute(MASTER_BUS, mute_checkbox.button_pressed)

	# --- 🎮 Sterowanie ---
	Global.mouse_sensitivity = mouse_sensitivity_slider.value

	# --- 🖥️ Grafika ---
	_apply_gamma_everywhere(gamma_slider.value)

	Global.set_fov(fov_slider.value)
	
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
	apply_settings() # zastosuj z powrotem co bylo

func _build_binding_rows() -> void:
	if not is_instance_valid(bindings_container):
		push_warning("Brak SterowaniePanel/Bindings.")
		return
	# clear
	for c in bindings_container.get_children():
		c.queue_free()
	# build
	for item in REBIND_ACTIONS:
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = item.label
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.text = _get_action_binding_text(item.action)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(func():
			_start_listen(item.action, btn))

		var clr := Button.new()
		clr.text = "Wyczyść"
		clr.pressed.connect(func():
			InputMap.action_erase_events(item.action)
			btn.text = "<nie przypisano>"
			if not _suppress: _set_dirty(true))

		hb.add_child(lbl)
		hb.add_child(btn)
		hb.add_child(clr)
		bindings_container.add_child(hb)

func _get_action_binding_text(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "<nie przypisano>"
	return _event_to_text(evs[0])

func _start_listen(action: String, btn: Button) -> void:
	_listen_action = StringName(action)
	_listen_button = btn
	btn.text = "Naciśnij klawisz..."
	btn.disabled = true
	grab_focus()

func _cancel_listen() -> void:
	if _listen_button:
		_listen_button.disabled = false
		_listen_button.text = _get_action_binding_text(String(_listen_action))
	_listen_action = &""
	_listen_button = null

func _apply_event_to_action(action: StringName, ev: InputEvent) -> void:
	InputMap.action_erase_events(action) # jeden bind na akcję; jeśli chcesz wiele, usuń tę linię
	InputMap.action_add_event(action, ev)
	if _listen_button:
		_listen_button.text = _event_to_text(ev)
		_listen_button.disabled = false
	_listen_action = &""
	_listen_button = null
	if not _suppress: _set_dirty(true)

func _event_to_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var s := k.as_text()
		if s == "":
			s = OS.get_keycode_string(k.keycode)
		return s
	elif ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LPM"
			MOUSE_BUTTON_RIGHT: return "PPM"
			MOUSE_BUTTON_MIDDLE: return "ŚPM"
			_: return "Przycisk myszy %d" % (ev as InputEventMouseButton).button_index
	elif ev is InputEventJoypadButton:
		return "Pad %d" % (ev as InputEventJoypadButton).button_index
	return "?"

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {
			"type": "key",
			"physical": k.physical_keycode,
			"key": k.keycode,
			"shift": k.shift_pressed,
			"alt": k.alt_pressed,
			"ctrl": k.ctrl_pressed,
			"meta": k.meta_pressed
		}
	elif ev is InputEventMouseButton:
		return {"type": "mouse", "button": (ev as InputEventMouseButton).button_index}
	elif ev is InputEventJoypadButton:
		return {"type": "joy", "button": (ev as InputEventJoypadButton).button_index}
	return {}

func _dict_to_event(d: Dictionary) -> InputEvent:
	if not d.has("type"): return null
	match String(d["type"]):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("physical", 0))
			k.keycode = int(d.get("key", 0))
			k.shift_pressed = bool(d.get("shift", false))
			k.alt_pressed = bool(d.get("alt", false))
			k.ctrl_pressed = bool(d.get("ctrl", false))
			k.meta_pressed = bool(d.get("meta", false))
			k.pressed = true
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button", MOUSE_BUTTON_LEFT))
			m.pressed = true
			return m
		"joy":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.get("button", 0))
			j.pressed = true
			return j
	return null

func _refresh_binding_labels() -> void:
	if not is_instance_valid(bindings_container): return
	var i := 0
	for item in REBIND_ACTIONS:
		var hb := bindings_container.get_child(i) as HBoxContainer
		var btn := hb.get_child(1) as Button
		btn.text = _get_action_binding_text(item.action)
		i += 1

func _apply_gamma_everywhere(val: float) -> void:
	# Zakres roboczy, np. 0.5–1.5 (1.0 = domyślna jasność)
	var g := clampf(val, 0.5, 1.5)

	# 1) Domyślne środowisko z Project Settings (jeśli używasz)
	var def_env_path = ProjectSettings.get_setting("rendering/environment/defaults/default_environment", "")
	if typeof(def_env_path) == TYPE_STRING and def_env_path != "":
		var def_env : Environment = load(def_env_path) as Environment
		if def_env:
			def_env.adjustment_enabled = true
			def_env.adjustment_brightness = g

	# 2) Wszystkie WorldEnvironment w drzewie (poziomy + SubViewport w menu)
	for we in get_tree().get_nodes_in_group("world_env"):
		if we is WorldEnvironment and we.environment:
			we.environment.adjustment_enabled = true
			we.environment.adjustment_brightness = g

	# 3) Fallback: środowisko bieżącego Viewportu (gdyby brakowało WorldEnvironment)
	var w3d : World3D = get_viewport().world_3d
	if w3d and w3d.environment:
		w3d.environment.adjustment_enabled = true
		w3d.environment.adjustment_brightness = g
	
