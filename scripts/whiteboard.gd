extends Area3D
# Whiteboard Area script with blinking cursor, proper backspace, space, and 20-line limit

@export var board_camera_path: NodePath = NodePath("")
@export var board_label_path: NodePath = NodePath("")
@export var allow_multiline: bool = true
@export var max_chars: int = 1024
@export var max_lines: int = 20
@export var initial_text: String = ""
@export var open_action: String = "interact"   # action to enter/exit whiteboard (e.g. F)
@export var exit_action: String = "ui_cancel"  # ESC

@export var autodetect_board_camera_name: String = "BoardCamera"
@export var autodetect_label_name: String = "Label3D"

# cursor config
@export var cursor_char: String = "|"
@export var cursor_blink_interval: float = 0.5

var _player_in_area: bool = false
var _editing: bool = false
var _player_node: Node = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _prev_camera: Camera3D = null
var _board_camera: Camera3D = null
var _board_label: Node = null

# text buffer (actual text without cursor)
var _text_buffer: String = ""
# cursor state
var _cursor_visible: bool = false
var _cursor_timer: float = 0.0

func _ready() -> void:
	# connect area signals
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

	# init label text and buffer
	if _board_label:
		_text_buffer = initial_text
		_set_label_text(_text_buffer)

	# find player
	_player_node = _auto_find_player_body()
	if _player_node:
		# ensure enabled at startup (safe)
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
			_update_label_with_cursor()


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
	# toggle edit mode only via action press (so letter keys like F still type)
	if event.is_action_pressed(open_action) and not event.echo:
		if _player_in_area and not _editing:
			_start_editing()
			get_viewport().set_input_as_handled()
			return
	# If not editing, do nothing here (other inputs pass through)

	# when editing we capture keys manually
	if _editing:
		# ESC => exit (use action because ESC is usually mapped to ui_cancel)
		if event.is_action_pressed(exit_action) and not event.echo:
			_end_editing()
			get_viewport().set_input_as_handled()
			return

		# prefer character handling from InputEventKey
		if event is InputEventKey and event.pressed and not event.echo:
			# handle backspace: unicode 8 (and sometimes 0), try fallback with scancode check
			var uni := int(event.unicode)
			# Backspace (unicode 8)
			if uni == 8:
				_backspace()
				get_viewport().set_input_as_handled()
				return

			# Enter/newline (unicode 13) -> only here create newline
			if uni == 13:
				_try_append_newline()
				get_viewport().set_input_as_handled()
				return

			# Printable character (space is 32)
			if uni >= 32:
				_append_printable_char(char(uni))
				get_viewport().set_input_as_handled()
				return

		# fallback for InputEventText (some platforms / IME)
		# guard access safely
		if typeof(event) == TYPE_OBJECT and event.get_class() == "InputEventText":
			# try to call get_text if available
			if event.has_method("get_text"):
				var s := str(event.call("get_text"))
				# InputEventText gives full text typed; append respecting limits
				for ch in s:
					if ch == "\r" or ch == "\n":
						_try_append_newline()
					else:
						_append_printable_char(ch)
				get_viewport().set_input_as_handled()
				return

		# block other inputs while editing so game actions don't trigger
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
	# ensure buffer contains current label text (strip any cursor)
	_text_buffer = _get_label_text()
	_update_label_with_cursor()
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
	print("Whiteboard: editing ended")


# append/backspace helpers
func _append_printable_char(ch: String) -> void:
	if ch == "":
		return
	# enforce max chars
	var newt := _text_buffer + ch
	if newt.length() > max_chars:
		return
	# if ch is newline handled elsewhere, but here we only get printable, so safe
	_text_buffer = newt
	_update_label_with_cursor()


func _try_append_newline() -> void:
	if not allow_multiline:
		return
	# enforce max lines
	var lines := _text_buffer.split("\n", false)
	if lines.size() >= max_lines:
		# do not append further newlines
		return
	_text_buffer += "\n"
	_update_label_with_cursor()


func _backspace() -> void:
	if _text_buffer == "":
		return
	# remove last unicode rune (simple substring is OK for basic ASCII/UTF-8)
	# to be robust with UTF-8, use rfind of last UTF-8 char:
	var newt := ""
	# simple approach: remove last codepoint
	# GDScript substr indices are in characters, so:
	newt = _text_buffer.substr(0, _text_buffer.length() - 1)
	_text_buffer = newt
	_update_label_with_cursor()


# label helpers (safely set/get)
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


func _update_label_with_cursor() -> void:
	var display := _text_buffer
	if _editing and _cursor_visible:
		display += cursor_char
	_set_label_text(display)


# helpers to find player/cameras/labels
func _auto_find_player_body() -> Node:
	var root = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
	var p := _find_node_by_name(root, "PlayerBody")
	if p:
		return p
	var by_type := _find_node_by_type(root, "CharacterBody3D")
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
		var res := _find_node_by_name(child, target_name)
		if res:
			return res
	return null


func _find_node_by_type(node: Node, classname: String) -> Node:
	if node == null:
		return null
	if node.get_class() == classname:
		return node
	for child in node.get_children():
		var r := _find_node_by_type(child, classname)
		if r:
			return r
	return null
