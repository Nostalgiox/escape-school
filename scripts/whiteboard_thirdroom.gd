extends Area3D
# Whiteboard Area script with separate cursor Label3D (no text-shift),
# Enter/backspace/space handling, blinking cursor, max lines cap.
# Fixed parent selection and explicit typing to avoid "Variant" issues.

@export var board_camera_path: NodePath = NodePath("")       # Camera3D to switch to
@export var board_label_path: NodePath = NodePath("")        # Label3D that displays the text
@export var allow_multiline: bool = true
@export var max_chars: int = 1024
@export var max_lines: int = 20
@export var initial_text: String = ""
@export var open_action: String = "interact"                 # action to enter/exit whiteboard (e.g. F)
@export var exit_action: String = "ui_cancel"                # ESC (ends editing)
@export var cursor_char: String = "|"                        # visual cursor char (separate node)
@export var cursor_blink_interval: float = 0.5
@export var autodetect_board_camera_name: String = "BoardCamera"
@export var autodetect_label_name: String = "Label3D"
@export var cursor_name: String = "Whiteboard_Cursor"        # created Label3D name for cursor

@export var max_chars_per_line: int = 40


# runtime state (typed where helpful)
var _player_in_area: bool = false
var _editing: bool = false
var _player_node: Node = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _prev_camera: Camera3D = null
var _board_camera: Camera3D = null
var _board_label: Node = null
var _cursor_label: Label3D = null

# text buffer (actual text without cursor)
var _text_buffer: String = ""
# cursor blinking
var _cursor_visible: bool = false
var _cursor_timer: float = 0.0

func _ready() -> void:
	# connect area signals (only once)
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))

	# find board camera & label
	if board_camera_path != NodePath(""):
		_board_camera = get_node_or_null(board_camera_path) as Camera3D
	else:
		_board_camera = _find_node_by_name(get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root, autodetect_board_camera_name) as Camera3D

	if board_label_path != NodePath(""):
		_board_label = get_node_or_null(board_label_path)
	else:
		_board_label = _find_node_by_name(get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root, autodetect_label_name)

	# init buffer & label
	if _board_label:
		_text_buffer = initial_text
		_set_label_text(_text_buffer)

	# ensure cursor label exists (but keep hidden until editing)
	_cursor_label = _get_or_create_cursor_label()

	# find player
	_player_node = _auto_find_player_body()
	if _player_node:
		# ensure enabled at startup
		if _player_node.has_method("set_controls_enabled"):
			_player_node.call("set_controls_enabled", true)
		else:
			_player_node.set_process(true)
			_player_node.set_physics_process(true)

	_prev_mouse_mode = Input.mouse_mode
	_editing = false
	_cursor_visible = false
	_cursor_timer = 0.0

	monitoring = true
	print("Whiteboard: ready. board_camera:", _board_camera, " label:", _board_label, " player:", _player_node)


func _process(delta: float) -> void:
	if _editing:
		_cursor_timer += delta
		if _cursor_timer >= cursor_blink_interval:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
			_update_cursor_visibility()


# area enter/exit
func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		_player_in_area = true
		print("Whiteboard: player entered area")


func _on_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		_player_in_area = false
		print("Whiteboard: player exited area")
		if _editing:
			_end_editing()


# input handling
func _input(event: InputEvent) -> void:
	# toggle edit mode only via action press (so letter keys like F type)
	if event.is_action_pressed(open_action) and not event.echo:
		if _player_in_area and not _editing:
			_start_editing()
			get_viewport().set_input_as_handled()
			return
	# if editing we capture inputs
	if _editing:
		# ESC / exit_action  -> end editing
		if event.is_action_pressed(exit_action) and not event.echo:
			_end_editing()
			get_viewport().set_input_as_handled()
			return

		# prefer InputEventKey handling
		if event is InputEventKey and event.pressed and not event.echo:
			# unicode may be 0 for non-text keys; unify as int
			var uni: int = int(event.unicode)
			# BACKSPACE detection via unicode 8 OR keycode Backspace
			if uni == 8 or event.keycode == KEY_BACKSPACE:
				_backspace()
				get_viewport().set_input_as_handled()
				return

			# ENTER / newline: unicode 13 OR keycodes for Enter/Keypad Enter
			if uni == 13 or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_try_append_newline()
				get_viewport().set_input_as_handled()
				return

			# printable characters include space (unicode 32)
			if uni >= 32:
				var ch: String = char(uni)
				_append_printable_char(ch)
				get_viewport().set_input_as_handled()
				return

		# fallback for InputEventText (IME/input systems)
		if typeof(event) == TYPE_OBJECT and event.get_class() == "InputEventText":
			if event.has_method("get_text"):
				var s: String = str(event.call("get_text"))
				for ch in s:
					if ch == "\r" or ch == "\n":
						_try_append_newline()
					else:
						_append_printable_char(ch)
				get_viewport().set_input_as_handled()
				return

		# block other inputs while editing to avoid game actions
		get_viewport().set_input_as_handled()
		return



# start / end editing
func _start_editing() -> void:
	if _editing:
		return
	if _board_label == null:
		push_warning("Whiteboard: brak Label3D; nie mogę edytować.")
		return

	_prev_mouse_mode = Input.mouse_mode
	_prev_camera = get_viewport().get_camera_3d()

	# camera switch
	if _board_camera:
		_board_camera.current = true
		print("Whiteboard: switched to board camera")
	else:
		print("Whiteboard: no BoardCamera detected")

	# disable player controls
	if _player_node == null:
		_player_node = _auto_find_player_body()

	if _player_node:
		if _player_node.has_method("set_controls_enabled"):
			_player_node.call("set_controls_enabled", false)
		else:
			_player_node.set_process(false)
			_player_node.set_physics_process(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_editing = true
	_cursor_visible = true
	_cursor_timer = 0.0
	# ensure buffer contains current label text (strip cursor if any)
	_text_buffer = _get_label_text()
	_update_cursor_position()
	_update_cursor_visibility()
	print("Whiteboard: editing started")


func _end_editing() -> void:
	if not _editing:
		return

	# restore camera
	if _prev_camera:
		_prev_camera.current = true
	_prev_camera = null

	# restore player controls
	if _player_node:
		if _player_node.has_method("set_controls_enabled"):
			_player_node.call("set_controls_enabled", true)
		else:
			_player_node.set_process(true)
			_player_node.set_physics_process(true)

	# restore mouse
	Input.mouse_mode = _prev_mouse_mode
	_editing = false
	_cursor_visible = false
	_set_label_text(_text_buffer) # final text without cursor
	_update_cursor_visibility()
	print("Whiteboard: editing ended")


# append/backspace/newline helpers
func _append_printable_char(ch: String) -> void:
	if ch == "":
		return

	# limit całkowitej liczby znaków
	if _text_buffer.length() >= max_chars:
		return

	var lines := _text_buffer.split("\n", false)
	var last_line := ""
	if lines.size() > 0:
		last_line = lines[lines.size() - 1]

	# jeśli linia pełna → auto newline (jeśli można)
	if last_line.length() >= max_chars_per_line:
		if not allow_multiline:
			return
		if lines.size() >= max_lines:
			return
		_text_buffer += "\n"

	# dodaj znak
	_text_buffer += ch
	_set_label_text(_text_buffer)
	_update_cursor_position()



func _try_append_newline() -> void:
	if not allow_multiline:
		return
	# enforce max lines
	var lines: Array = _text_buffer.split("\n", false)
	if lines.size() >= max_lines:
		return
	_text_buffer += "\n"
	_set_label_text(_text_buffer)
	_update_cursor_position()


func _backspace() -> void:
	if _text_buffer == "":
		return
	# remove last character
	_text_buffer = _text_buffer.substr(0, _text_buffer.length() - 1)
	_set_label_text(_text_buffer)
	_update_cursor_position()


# Label helpers
func _set_label_text(s: String) -> void:
	if _board_label == null:
		return
	if "text" in _board_label:
		_board_label.text = s
	elif _board_label.has_method("set_text"):
		_board_label.call("set_text", s)


func _get_label_text() -> String:
	if _board_label == null:
		return ""
	if "text" in _board_label:
		return str(_board_label.text)
	elif _board_label.has_method("get_text"):
		return str(_board_label.call("get_text"))
	return ""


# Cursor label creation & updates --------------------------------
func _get_or_create_cursor_label() -> Label3D:
	# try find existing under same parent as board_label
	var parent_node: Node = null
	if _board_label != null:
		var maybe_parent: Node = _board_label.get_parent()
		if maybe_parent != null and maybe_parent is Node:
			parent_node = maybe_parent as Node
	# fallback to self
	if parent_node == null:
		parent_node = self

	# look for existing by name
	var existing: Node = parent_node.get_node_or_null(cursor_name)
	if existing and existing is Label3D:
		return existing as Label3D

	# create new Label3D as cursor
	var newc: Label3D = Label3D.new()
	newc.name = cursor_name
	newc.text = cursor_char
	# add to parent deferred if the parent is busy setting up children
	parent_node.call_deferred("add_child", newc)
	newc.visible = false
	return newc


func _update_cursor_visibility() -> void:
	if _cursor_label == null:
		_cursor_label = _get_or_create_cursor_label()
	if _cursor_label:
		_cursor_label.visible = _editing and _cursor_visible


func _update_cursor_position() -> void:
	# place cursor at end of last line of _text_buffer
	if _cursor_label == null:
		_cursor_label = _get_or_create_cursor_label()
	if _board_label == null or _cursor_label == null:
		return

	# get local transform of board label (we'll position cursor relative to it)
	var board_origin: Vector3 = Vector3.ZERO
	var basis: Basis = Basis.IDENTITY
	if _board_label is Node3D:
		board_origin = (_board_label as Node3D).global_transform.origin
		basis = (_board_label as Node3D).global_transform.basis
	else:
		# fallback: use this node's transform if parent is Node3D
		var par: Node = _cursor_label.get_parent()
		if par and par is Node3D:
			board_origin = (par as Node3D).global_transform.origin
			basis = (par as Node3D).global_transform.basis

	# compute offset: measure last line width in world units using font if available
	var lines: Array = _text_buffer.split("\n", false)
	var last_line: String = ""
	if lines.size() > 0:
		last_line = str(lines[lines.size() - 1])

	var x_offset: float = 0.0
	var y_offset: float = 0.0
	# try to measure using font if accessible
	var font_found: bool = false
	if _board_label and _board_label.has_method("get_font"):
		var f: Object = _board_label.call("get_font")
		if f != null:
			# get_string_size may exist on DynamicFont/Font implementations
			if f.has_method("get_string_size"):
				var size2d: Vector2 = f.get_string_size(last_line)
				x_offset = size2d.x
				font_found = true
			elif f.has_method("get_glyph_advance"):
				var adv: float = 0.0
				for ch in last_line:
					if f.has_method("get_glyph_advance"):
						adv += float(f.get_glyph_advance(ord(ch)))
				x_offset = adv
				font_found = true

	# fallback approximate char width (world units) if no font measurement available
	if not font_found:
		x_offset = float(last_line.length()) * 0.03

	# compute vertical offset: approximate line height (if many lines stack downward)
	var line_index: int = max(0, lines.size() - 1)
	var line_height: float = 0.06
	y_offset = -float(line_index) * line_height

	# compute desired global position for cursor
	var desired_global: Vector3 = board_origin + basis.x * x_offset + basis.y * y_offset

	# set cursor global transform keeping same rotation as label
	var cur_tf: Transform3D = _cursor_label.global_transform
	cur_tf.origin = desired_global
	_cursor_label.global_transform = cur_tf

	# ensure cursor is visible state consistent
	_update_cursor_visibility()


# helpers to find player/cameras/labels
func _auto_find_player_body() -> Node:
	var root: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
	var p: Node = _find_node_by_name(root, "PlayerBody")
	if p:
		return p
	var by_type: Node = _find_node_by_type(root, "CharacterBody3D")
	if by_type:
		return by_type
	p = _find_node_by_name(root, "Player")
	if p:
		return p
	return null


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var res: Node = _find_node_by_name(child, target_name)
		if res:
			return res
	return null


func _find_node_by_type(node: Node, classname: String) -> Node:
	if node == null:
		return null
	if node.get_class() == classname:
		return node
	for child in node.get_children():
		var r: Node = _find_node_by_type(child, classname)
		if r:
			return r
	return null
