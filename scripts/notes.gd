# notatka.gd - auto-detekcja node'ów (priorytet: self -> canvas_layer -> global) + eksportowane teksty
extends Node3D

# Eksportowane NodePathy (możesz je nadal ustawić w Inspectorze jeśli chcesz)
@export var canvas_layer_path : NodePath = NodePath("")
@export var info_panel_path   : NodePath = NodePath("")
@export var texture_rect_path : NodePath = NodePath("")
@export var left_label_path   : NodePath = NodePath("")
@export var right_label_path  : NodePath = NodePath("")
@export var single_label_path : NodePath = NodePath("")
@export var close_button_path : NodePath = NodePath("")
@export var anim_player_path  : NodePath = NodePath("")

# Eksportowane teksty (wpisz w Inspectorze jeśli chcesz)
@export var zadanie2_text : String = """
[center][b]Zadanie 2[/b][/center]

Na ścianie znajduje się plakat z okręgiem.
Zmierz jego średnicę, a następnie oblicz [b]pole koła[/b] korzystając z wzoru:

[center]P = π * r²[/center]

gdzie r to połowa zmierzonej średnicy, a π ≈ 3.14159.

Wpisz otrzymany wynik jako [b]drugą cyfrę[/b] kodu.
"""

@export var zadanie3_text : String = """
[center][b]Zadanie 3[/b][/center]

Ustaw lampę tak, aby cień przedmiotu padał wyraźnie na blat.
Przyjrzyj się uważnie kształtowi cienia — zauważysz, że tworzy on cyfrę.

Odczytaj tę cyfrę i wpisz ją jako [b]trzecią cyfrę[/b] kodu.

Podpowiedź: poprawne ustawienie daje cyfrę: [b]7[/b].
"""

# Jakie akcje blokujemy, gdy panel otwarty
@export var block_actions : Array[StringName] = [&"inventory", &"ui_cancel"]
@export var close_on_esc : bool = true

# Referencje (wypełniane w _ready)
var canvas_layer : CanvasLayer = null
var info_panel : Panel = null
var texture_rect : TextureRect = null
var left_label : RichTextLabel = null
var right_label : RichTextLabel = null
var single_label : RichTextLabel = null
var close_button : Button = null
var anim_player : AnimationPlayer = null

# Fallback label (jeśli RichTextLabel nie działa)
var fallback_label : RichTextLabel = null

# Blocker: pełnoekranowy Control, zjada kliknięcia
var input_blocker : Control = null

# Debounce (zapobiega szybkiemu ponownemu otwarciu)
var _can_open : bool = true
var _debounce_ms : int = 300

# ---------------- pomocnicze funkcje ----------------

func find_node_recursive(root: Node, name_to_find: String) -> Node:
	if root == null:
		return null
	if root.name == name_to_find:
		return root
	for child in root.get_children():
		var node_child := child as Node
		if not node_child:
			continue
		var found := find_node_recursive(node_child, name_to_find)
		if found:
			return found
	return null

func _object_has_property(obj: Object, prop_name: String) -> bool:
	if not obj:
		return false
	var plist := obj.get_property_list()
	for p in plist:
		if typeof(p) == TYPE_DICTIONARY and p.has("name"):
			if String(p["name"]) == prop_name:
				return true
	return false

# Próbuje ustawić tekst w RichTextLabel różnymi metodami (fallback API)
func _try_set_richtext(node: Node, text: String) -> bool:
	if not node:
		return false
	if node.has_method("clear"):
		node.call("clear")
	if node.has_method("append_bbcode"):
		node.call("append_bbcode", text)
		return true
	if node.has_method("set_bbcode"):
		node.call("set_bbcode", text)
		return true
	if node.has_method("set_bbcode_text"):
		node.call("set_bbcode_text", text)
		return true
	if _object_has_property(node, "bbcode_text"):
		node.set("bbcode_text", text)
		return true
	if node.has_method("set_text"):
		node.call("set_text", text)
		return true
	if node.has_method("add_text"):
		node.call("add_text", text)
		return true
	return false

# Tworzy fallback RichTextLabel jeśli normalne label'e nie działają
func _create_fallback_label() -> void:
	if fallback_label:
		return
	if not canvas_layer:
		canvas_layer = find_node_recursive(get_tree().get_root(), "CanvasLayer") as CanvasLayer
		if not canvas_layer:
			push_error("notatka.gd: brak CanvasLayer - fallback nie może być utworzony.")
			return
	fallback_label = RichTextLabel.new()
	fallback_label.name = "FallbackNoteLabel"
	if _object_has_property(fallback_label, "bbcode_enabled"):
		fallback_label.set("bbcode_enabled", true)
	# prosty layout (anchory); dostosuj w razie potrzeby w Inspectorze
	fallback_label.anchor_left = 0.18
	fallback_label.anchor_top = 0.12
	fallback_label.anchor_right = 0.82
	fallback_label.anchor_bottom = 0.88
	# margins jeśli dostępne
	if fallback_label.has_method("set_margin"):
		fallback_label.set_margin(0, 0)
		fallback_label.set_margin(1, 0)
		fallback_label.set_margin(2, 0)
		fallback_label.set_margin(3, 0)
	fallback_label.z_index = 1000
	canvas_layer.add_child(fallback_label)

func _show_fallback_text(left_text: String, right_text: String) -> void:
	if not fallback_label:
		_create_fallback_label()
	if not fallback_label:
		return
	if fallback_label.has_method("clear"):
		fallback_label.call("clear")
	var combined := left_text + "\n\n---\n\n" + right_text
	if fallback_label.has_method("append_bbcode"):
		fallback_label.call("append_bbcode", combined)
	elif fallback_label.has_method("set_bbcode"):
		fallback_label.call("set_bbcode", combined)
	elif _object_has_property(fallback_label, "bbcode_text"):
		fallback_label.set("bbcode_text", combined)
	elif fallback_label.has_method("set_text"):
		fallback_label.call("set_text", combined)
	fallback_label.visible = true

func _hide_fallback() -> void:
	if fallback_label:
		fallback_label.visible = false

func _prepare_control(ctrl: Control) -> void:
	if not ctrl:
		return
	if "visible" in ctrl:
		ctrl.visible = true
	if ctrl.has_method("grab_focus"):
		ctrl.grab_focus()
	if info_panel and ctrl.get_parent() == info_panel:
		info_panel.move_child(ctrl, info_panel.get_child_count() - 1)

# ---------------- input_blocker (full screen control) ----------------

func _create_input_blocker() -> void:
	if input_blocker:
		return
	if not canvas_layer:
		canvas_layer = find_node_recursive(get_tree().get_root(), "CanvasLayer") as CanvasLayer
		if not canvas_layer:
			return
	input_blocker = Control.new()
	input_blocker.name = "NoteInputBlocker"
	input_blocker.anchor_left = 0.0
	input_blocker.anchor_top = 0.0
	input_blocker.anchor_right = 1.0
	input_blocker.anchor_bottom = 1.0
	if input_blocker.has_method("set_margin"):
		input_blocker.set_margin(0, 0)
		input_blocker.set_margin(1, 0)
		input_blocker.set_margin(2, 0)
		input_blocker.set_margin(3, 0)
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	input_blocker.focus_mode = Control.FOCUS_ALL
	input_blocker.visible = false
	input_blocker.z_index = 2000
	input_blocker.connect("gui_input", Callable(self, "_on_blocker_gui_input"))
	canvas_layer.add_child(input_blocker)
	canvas_layer.move_child(input_blocker, canvas_layer.get_child_count() - 1)

func _on_blocker_gui_input(event: InputEvent) -> void:
	if event:
		if input_blocker and input_blocker.has_method("accept_event"):
			input_blocker.accept_event()
		var vp := get_viewport()
		if vp and vp.has_method("set_input_as_handled"):
			vp.set_input_as_handled()

# ---------------- inicjalizacja (auto-detekcja) ----------------

func _ready() -> void:
	# 1) CanvasLayer: preferuj exportowana ścieżka, potem self.get_node_or_null("CanvasLayer"), potem global find
	if canvas_layer_path != NodePath(""):
		canvas_layer = get_node_or_null(canvas_layer_path) as CanvasLayer
	if not canvas_layer:
		canvas_layer = get_node_or_null("CanvasLayer") as CanvasLayer
	if not canvas_layer:
		canvas_layer = find_node_recursive(get_tree().get_root(), "CanvasLayer") as CanvasLayer

	# 2) InfoPanel: priorytetowo: export path -> child of self -> child of canvas_layer -> global
	if info_panel_path != NodePath(""):
		info_panel = get_node_or_null(info_panel_path) as Panel
	if not info_panel:
		info_panel = get_node_or_null("InfoPanel") as Panel
	if not info_panel and canvas_layer:
		info_panel = canvas_layer.get_node_or_null("InfoPanel") as Panel
	if not info_panel:
		info_panel = find_node_recursive(get_tree().get_root(), "InfoPanel") as Panel

	# 3) TextureRect: export -> child of info_panel -> child of self -> global
	if texture_rect_path != NodePath(""):
		texture_rect = get_node_or_null(texture_rect_path) as TextureRect
	if not texture_rect and info_panel:
		texture_rect = info_panel.get_node_or_null("TextureRect") as TextureRect
	if not texture_rect:
		texture_rect = get_node_or_null("TextureRect") as TextureRect
	if not texture_rect:
		texture_rect = find_node_recursive(get_tree().get_root(), "TextureRect") as TextureRect

	# 4) Labels (Left / Right / Single)
	if left_label_path != NodePath(""):
		left_label = get_node_or_null(left_label_path) as RichTextLabel
	if not left_label and info_panel:
		left_label = info_panel.get_node_or_null("InfoLabelLeft") as RichTextLabel
	if not left_label:
		left_label = get_node_or_null("InfoLabelLeft") as RichTextLabel
	if not left_label:
		left_label = find_node_recursive(get_tree().get_root(), "InfoLabelLeft") as RichTextLabel

	if right_label_path != NodePath(""):
		right_label = get_node_or_null(right_label_path) as RichTextLabel
	if not right_label and info_panel:
		right_label = info_panel.get_node_or_null("InfoLabelRight") as RichTextLabel
	if not right_label:
		right_label = get_node_or_null("InfoLabelRight") as RichTextLabel
	if not right_label:
		right_label = find_node_recursive(get_tree().get_root(), "InfoLabelRight") as RichTextLabel

	if single_label_path != NodePath(""):
		single_label = get_node_or_null(single_label_path) as RichTextLabel
	if not single_label and info_panel:
		single_label = info_panel.get_node_or_null("InfoLabel") as RichTextLabel
	if not single_label:
		single_label = get_node_or_null("InfoLabel") as RichTextLabel
	if not single_label:
		single_label = find_node_recursive(get_tree().get_root(), "InfoLabel") as RichTextLabel

	# 5) Close button
	if close_button_path != NodePath(""):
		close_button = get_node_or_null(close_button_path) as Button
	if not close_button and info_panel:
		close_button = info_panel.get_node_or_null("CloseButton") as Button
	if not close_button:
		close_button = get_node_or_null("CloseButton") as Button
	if not close_button:
		close_button = find_node_recursive(get_tree().get_root(), "CloseButton") as Button

	# 6) AnimationPlayer
	if anim_player_path != NodePath(""):
		anim_player = get_node_or_null(anim_player_path) as AnimationPlayer
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not anim_player:
		anim_player = find_node_recursive(get_tree().get_root(), "AnimationPlayer") as AnimationPlayer

	# connect close button
	if close_button:
		close_button.pressed.connect(Callable(self, "_on_close_pressed"))

	# mouse_filter: info_panel/texture_rect stop clicks
	if info_panel and info_panel is Control:
		info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if texture_rect and texture_rect is Control:
		texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# create blocker
	_create_input_blocker()

	# connect gui_input defensywnie
	if info_panel:
		if info_panel.has_method("connect"):
			info_panel.connect("gui_input", Callable(self, "_on_info_gui_input"))
		if _object_has_property(info_panel, "focus_mode"):
			info_panel.set("focus_mode", 2) # FOCUS_ALL

	# start hidden
	if info_panel:
		info_panel.visible = false
	_hide_fallback()

# ---------------- ustawianie tekstu / show/hide ----------------

func set_page_texts(left_text: String, right_text: String) -> void:
	var set_succeeded := false
	if left_label and right_label:
		if _try_set_richtext(left_label, left_text):
			if _try_set_richtext(right_label, right_text):
				set_succeeded = true
	if not set_succeeded and single_label:
		if _try_set_richtext(single_label, left_text + "\n\n\n\n" + right_text):
			set_succeeded = true
	if not set_succeeded:
		_show_fallback_text(left_text, right_text)
	else:
		_hide_fallback()

func show_panel(auto_fill_with_tasks: bool = true) -> void:
	# DEBUG — zobacz w konsoli czy znaleziono label'e przed ustawieniem
	print("notatka.gd: show_panel() — left_label:", left_label, " right_label:", right_label, " single_label:", single_label)

	if not _can_open:
		print("notatka.gd: show_panel blocked by debounce")
		return

	# zawsze ustaw teksty — nawet jeśli były już ustawione kiedyś
	if auto_fill_with_tasks:
		set_page_texts(zadanie2_text, zadanie3_text)

	if anim_player and anim_player.has_animation("open"):
		anim_player.play("open")

	# show info_panel and controls defensively
	if info_panel:
		info_panel.visible = true
		if info_panel.has_method("grab_focus"):
			info_panel.grab_focus()

	if texture_rect and texture_rect is Control:
		texture_rect.visible = true
	if left_label:
		left_label.visible = true
	if right_label:
		right_label.visible = true
	if single_label:
		single_label.visible = true

	_hide_fallback()

	# ensure blocker on top
	if input_blocker and canvas_layer:
		canvas_layer.move_child(input_blocker, canvas_layer.get_child_count() - 1)
		input_blocker.visible = true
		input_blocker.grab_focus()

	# if info_panel is direct child of canvas_layer, bring to top too
	if canvas_layer and info_panel and info_panel.get_parent() == canvas_layer:
		canvas_layer.move_child(info_panel, canvas_layer.get_child_count() - 1)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# force redraw/update for labels
	if left_label and left_label.has_method("update"):
		left_label.update()
	if right_label and right_label.has_method("update"):
		right_label.update()
	if single_label and single_label.has_method("update"):
		single_label.update()

	# DEBUG — sprawdź zawartość bbcode_text (jeśli istnieje)
	if left_label and _object_has_property(left_label, "bbcode_text"):
		var s := left_label.get("bbcode_text")
		print("notatka.gd: left_label.bbcode_text len:", s.length() if typeof(s) == TYPE_STRING else str(s))

func hide_panel() -> void:
	# DEBUG
	print("notatka.gd: HIDE_PANEL called")

	if anim_player and anim_player.has_animation("close"):
		anim_player.play("close")

	if info_panel:
		info_panel.visible = false

	_hide_fallback()

	if input_blocker:
		input_blocker.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_start_open_debounce()

func toggle_panel() -> void:
	if info_panel and info_panel.visible:
		hide_panel()
	else:
		show_panel(true)

func set_panel_texture(path: String) -> void:
	var tex := load(path)
	if not tex:
		push_error("Nie udało się załadować tekstury: %s" % path)
		return
	if texture_rect:
		texture_rect.texture = tex
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand = true

func _on_close_pressed() -> void:
	hide_panel()

func _ensure_label_on_top() -> void:
	if not info_panel:
		return
	if texture_rect and texture_rect.get_parent() == info_panel:
		info_panel.move_child(texture_rect, 0)
	var last_index := info_panel.get_child_count() - 1
	if left_label and left_label.get_parent() == info_panel:
		info_panel.move_child(left_label, last_index)
		last_index -= 1
	if right_label and right_label.get_parent() == info_panel:
		info_panel.move_child(right_label, last_index)
		last_index -= 1
	if single_label and single_label.get_parent() == info_panel:
		info_panel.move_child(single_label, last_index)

# debounce (await jest wymagany w Godot 4)
func _start_open_debounce() -> void:
	_can_open = false
	await get_tree().create_timer(float(_debounce_ms) / 1000.0).timeout
	_can_open = true

# ---------------- wejście: blokujemy akcje gdy panel otwarty ----------------

func _on_info_gui_input(event: InputEvent) -> void:
	if not info_panel or not info_panel.visible:
		return

	# swallow mouse clicks defensively
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if info_panel.has_method("accept_event"):
				info_panel.accept_event()
			var vp := get_viewport()
			if vp and vp.has_method("set_input_as_handled"):
				vp.set_input_as_handled()
			return

	# swallow keys (I/inventory, etc.)
	if event is InputEventKey and event.pressed and not event.echo:
		# raw I key
		if event.keycode == KEY_I:
			if info_panel.has_method("accept_event"):
				info_panel.accept_event()
			return
		for action in block_actions:
			if event.is_action_pressed(action, false):
				if info_panel.has_method("accept_event"):
					info_panel.accept_event()
				if close_on_esc and action == "ui_cancel":
					hide_panel()
				return

func _input(event: InputEvent) -> void:
	# only active when panel visible
	if not info_panel or not info_panel.visible:
		return

	# swallow mouse buttons globally
	if event is InputEventMouseButton and event.pressed:
		var vp2 := get_viewport()
		if vp2 and vp2.has_method("set_input_as_handled"):
			vp2.set_input_as_handled()
		return

	# handle keys (block actions)
	if not event.is_pressed():
		return

	for action in block_actions:
		if event.is_action_pressed(action, false):
			if close_on_esc and action == "ui_cancel":
				hide_panel()
			var vp := get_viewport()
			if vp and vp.has_method("set_input_as_handled"):
				vp.set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if not info_panel or not info_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("interact"):
			hide_panel()
			return

# ---------------- debug helpers (opcjonalne) ----------------

func debug_dump_panel() -> void:
	print("--- DEBUG PANEL DUMP ---")
	print("info_panel:", info_panel)
	if info_panel and info_panel is Control:
		var c := info_panel as Control
		print(" rect_size:", c.rect_size, " visible:", c.visible, " mouse_filter:", c.mouse_filter)
	else:
		print("info_panel not Control or null:", info_panel)
	print("input_blocker:", input_blocker, " visible:", input_blocker.visible if input_blocker else "N/A")
	print("--- END DEBUG ---")
