extends Panel
class_name LockPanel

@export var correct_code: Array[int] = [4, 2, 7]
@export var auto_check: bool = false

@export var block_actions: Array[StringName] = [&"inventory", &"ui_cancel"]
@export var close_on_esc: bool = false

@export var freeze_world: bool = true
@export var manage_mouse: bool = true

@export var check_button: Button
@export var close_button: Button

@export var anim_player: AnimationPlayer

@export var play_cutscene_on_unlock: bool = true
@export var cutscene_camera_path: NodePath = NodePath("")
@export var cutscene_target_path: NodePath = NodePath("")
@export var camera_offset: Vector3 = Vector3(0, 1.6, -3)
@export var cutscene_move_time: float = 0.8
@export var cutscene_hold_time: float = 1.2

@export var monolog_lines: Array[String] = [
	"O, proszę… jednak dałeś radę.",
	"Szczerze mówiąc, spodziewałam się, że ta zagadka zajmie ci trochę więcej czasu.",
	"Zostawiłam ci klucz na ławce do kolejnego pokoju."
]
@export var monolog_duration: float = 2.5
@export var monolog_ui_path: NodePath = NodePath("")
@export var monolog_area_path: NodePath = NodePath("")
@export var monolog_area_scene: PackedScene
@export var start_monolog_immediately: bool = false
@export var start_monolog_during_cutscene: bool = true

@export var teacher_node_path: NodePath = NodePath("")
@export var door_anim_player_path: NodePath = NodePath("")
@export var door_anim_open_name: String = "teacher_door_open"
@export var door_anim_close_name: String = "teacher_door_close"
@export var teacher_show_delay: float = 0.0
@export var door_close_after_cutscene_delay: float = 0.5

@export var key_scene: PackedScene
@export var key_spawn_path: NodePath = NodePath("")

@export var key_camera_path: NodePath = NodePath("")
@export var key_camera_offset: Vector3 = Vector3(0, 0.6, -0.8)
@export var key_camera_move_time: float = 0.4
@export var key_camera_transition_delay_line_index: int = 2
@export var key_show_on_cutscene_start: bool = true
@export var key_camera_use_tween: bool = true

# SFX nodes (assign AudioStreamPlayer or AudioStreamPlayer3D nodes)
@export var sfx_wrong_answer_path: NodePath = NodePath("")
@export var sfx_open_padlock_path: NodePath = NodePath("")  # Open padlock sound
#@export var sfx_open_drawer_path: NodePath = NodePath("")   # Drawer open sound

# door SFX (same for open and close)
@export var door_sfx_path: NodePath = NodePath("")

# typing SFX for monolog (keyboard clicking)
@export var typing_sfx_player_path: NodePath = NodePath("")

@onready var shaker: Control = $Shaker

signal unlocked

var guess: Array[int] = []
@onready var wheels_container: Node = $"Shaker/HBoxContainer"
var wheels: Array[LockWheel] = []
var _prev_paused: bool = false

var _player_node: Node = null
var _player_had_set_controls: bool = false
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

var _monolog_area_node: Area3D = null

var _last_spawned_key: Node = null
var _key_camera: Camera3D = null
var _key_camera_prev_current: Camera3D = null
var _key_camera_pending_tween: Tween = null
var _key_camera_switched: bool = false

# transforms for smooth transitions
var _key_camera_desired_transform: Transform3D = Transform3D.IDENTITY
var _main_camera_orig_transform: Transform3D = Transform3D.IDENTITY

# runtime refs for SFX
var _sfx_wrong: Node = null
var _sfx_open_padlock: Node = null
var _sfx_open_drawer: Node = null
var _sfx_door: Node = null
var _typing_sfx_player: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	for child in wheels_container.get_children():
		if child is LockWheel:
			wheels.append(child)

	guess.resize(wheels.size())
	for i in range(wheels.size()):
		wheels[i].index = i
		wheels[i].value_changed.connect(_on_wheel_changed)
		guess[i] = wheels[i].value

	if check_button:
		check_button.pressed.connect(_on_check_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	_player_node = _auto_find_player_body()
	if _player_node:
		_player_had_set_controls = _player_node.has_method("set_controls_enabled")
		print("LockPanel: znaleziono player node:", _player_node, " has_set_controls:", _player_had_set_controls)
	else:
		print("LockPanel: nie znaleziono player node automatycznie.")

	if monolog_area_path != NodePath(""):
		var maybe_area: Node = get_node_or_null(monolog_area_path)
		if maybe_area and maybe_area is Area3D:
			_monolog_area_node = maybe_area as Area3D
			print("LockPanel: monolog area assigned from path:", _monolog_area_node)
		elif maybe_area != null:
			print("LockPanel: monolog_area_path wskazuje node, który nie jest Area3D:", maybe_area)

	# key camera lookup
	if key_camera_path != NodePath(""):
		_key_camera = get_node_or_null(key_camera_path) as Camera3D
		if _key_camera == null:
			print("LockPanel: key_camera_path ustawione ale nie znaleziono Camera3D:", key_camera_path)
	else:
		_key_camera = _find_node_by_name(get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root, "KeyCamera") as Camera3D
		if _key_camera:
			print("LockPanel: autodetected KeyCamera:", _key_camera)

	if _key_camera != null:
		_key_camera_desired_transform = _key_camera.global_transform

	# resolve SFX nodes
	if sfx_wrong_answer_path != NodePath(""):
		_sfx_wrong = get_node_or_null(sfx_wrong_answer_path)
	if sfx_open_padlock_path != NodePath(""):
		_sfx_open_padlock = get_node_or_null(sfx_open_padlock_path)
	#if sfx_open_drawer_path != NodePath(""):
		#_sfx_open_drawer = get_node_or_null(sfx_open_drawer_path)
	if door_sfx_path != NodePath(""):
		_sfx_door = get_node_or_null(door_sfx_path)
		if _sfx_door == null:
			print("LockPanel: door_sfx_path ustawione ale node nie znaleziono:", door_sfx_path)

	if typing_sfx_player_path != NodePath(""):
		_typing_sfx_player = get_node_or_null(typing_sfx_player_path)
		if _typing_sfx_player == null:
			print("LockPanel: typing_sfx_player_path ustawione ale node nie znaleziono:", typing_sfx_player_path)


func _on_wheel_changed(index: int, value: int) -> void:
	guess[index] = value
	if auto_check:
		_check()

func _on_check_pressed() -> void:
	print("Sprawdzam kod:", guess)
	_check()

func _on_close_pressed() -> void:
	close_panel()

func _check() -> void:
	print("LockPanel: _check() -> guess:", guess, " correct:", correct_code)
	if guess == correct_code:
		print("LockPanel: Kod poprawny!")
		# play open-padlock sfx immediately
		if _sfx_open_padlock and _sfx_open_padlock.has_method("play"):
			_sfx_open_padlock.call("play")
		# schedule open-drawer sfx slightly later
		if _sfx_open_drawer and _sfx_open_drawer.has_method("play"):
			var sdelay := 0.35
			var tw := get_tree().create_tween()
			tw.tween_callback(Callable(self, "_play_sfx_open_drawer")).set_delay(sdelay)
		_enable_monolog_area()
		unlocked.emit()
		close_panel()
		if play_cutscene_on_unlock:
			_play_cutscene_async()
	else:
		_play_wrong_animation()

func _play_sfx_open_drawer() -> void:
	if _sfx_open_drawer and _sfx_open_drawer.has_method("play"):
		_sfx_open_drawer.call("play")

func _play_cutscene_async() -> void:
	_play_cutscene()

func _play_cutscene() -> void:
	if cutscene_camera_path == NodePath(""):
		print("LockPanel: Cutscene skipped - cutscene_camera_path nie ustawiony.")
		if start_monolog_during_cutscene:
			var mon_ui_node: Node = _start_monolog_direct()
			await _wait_for_monolog_or_timeout(mon_ui_node)
		return

	var marker: Node = get_node_or_null(cutscene_camera_path)
	if marker == null:
		print("LockPanel: Cutscene skipped - nie znaleziono cutscene_camera_path:", cutscene_camera_path)
		if start_monolog_during_cutscene:
			var mon_ui_node2: Node = _start_monolog_direct()
			await _wait_for_monolog_or_timeout(mon_ui_node2)
		return

	var cam_to_move: Camera3D = get_viewport().get_camera_3d()
	if cam_to_move == null:
		print("LockPanel: Cutscene skipped - brak aktualnej kamery 3D.")
		if start_monolog_during_cutscene:
			var mon_ui_node3: Node = _start_monolog_direct()
			await _wait_for_monolog_or_timeout(mon_ui_node3)
		return

	var orig_transform: Transform3D = cam_to_move.global_transform
	var orig_current_camera: Camera3D = get_viewport().get_camera_3d()

	_prev_mouse_mode = Input.mouse_mode

	_disable_player_control()

	# open door animation + door sound
	_open_teacher_door()
	# show teacher (optionally delayed)
	if teacher_show_delay <= 0.0:
		_show_teacher()
	else:
		var dtw: Tween = get_tree().create_tween() as Tween
		dtw.tween_callback(Callable(self, "_show_teacher")).set_delay(teacher_show_delay)

	var restore_current: Camera3D = null
	if orig_current_camera != cam_to_move:
		restore_current = orig_current_camera
		cam_to_move.current = true

	var target_transform: Transform3D
	if marker is Camera3D:
		target_transform = (marker as Camera3D).global_transform
	elif marker is Node3D:
		target_transform = (marker as Node3D).global_transform
	else:
		print("LockPanel: Cutscene skipped - cutscene_camera_path musi być Camera3D lub Node3D.")
		_enable_player_control()
		Input.mouse_mode = _prev_mouse_mode
		if start_monolog_during_cutscene:
			var mon_ui_node4: Node = _start_monolog_direct()
			await _wait_for_monolog_or_timeout(mon_ui_node4)
		if restore_current:
			restore_current.current = true
		return

	if cutscene_target_path != NodePath(""):
		var tnode: Node = get_node_or_null(cutscene_target_path)
		if tnode and tnode is Node3D:
			var target_origin: Vector3 = (tnode as Node3D).global_transform.origin + camera_offset
			var dir: Vector3 = ((tnode as Node3D).global_transform.origin - target_origin)
			if dir.length() == 0:
				dir = Vector3(0, 0, -1)
			var basis: Basis = Basis.looking_at(dir.normalized(), Vector3.UP)
			target_transform = Transform3D(basis, target_transform.origin)
		else:
			print("LockPanel: cutscene_target_path ustawiony, ale nie znaleziono Node3D:", cutscene_target_path)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# spawn key at cutscene start if requested
	if key_show_on_cutscene_start:
		_spawn_key()
	if _last_spawned_key == null:
		var root_node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		_last_spawned_key = _find_node_by_name(root_node, "Level1_key")

	# ensure key camera reference
	if _key_camera == null and key_camera_path != NodePath(""):
		_key_camera = get_node_or_null(key_camera_path) as Camera3D
		if _key_camera:
			_key_camera_desired_transform = _key_camera.global_transform

	# schedule key camera switch when third line starts (if requested)
	if start_monolog_during_cutscene and _key_camera != null:
		var line_index := key_camera_transition_delay_line_index
		var delay_time := monolog_duration * float(max(0, line_index))
		delay_time += 0.05
		_key_camera_pending_tween = get_tree().create_tween()
		_key_camera_pending_tween.tween_callback(Callable(self, "_on_key_camera_switch_time")).set_delay(delay_time)

	# move camera to target
	var tw: Tween = get_tree().create_tween() as Tween
	tw.tween_property(cam_to_move, "global_transform", target_transform, cutscene_move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	# start monolog during cutscene
	var mon_ui: Node = null
	if start_monolog_during_cutscene:
		mon_ui = _start_monolog_direct()

	# calculate hold/wait time
	var hold_time: float = cutscene_hold_time
	if start_monolog_during_cutscene:
		var lines_count: int = max(1, monolog_lines.size())
		var needed: float = monolog_duration * float(lines_count)
		if needed > hold_time:
			hold_time = needed
	await _wait_for_monolog_or_timeout(mon_ui, hold_time)

	# return camera to original transform
	var tw2: Tween = get_tree().create_tween() as Tween
	tw2.tween_property(cam_to_move, "global_transform", orig_transform, cutscene_move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw2.finished

	# restore key camera if switched
	if _key_camera_switched:
		await _restore_from_key_camera()

	# restore previous current camera
	if restore_current:
		restore_current.current = true

	Input.mouse_mode = _prev_mouse_mode
	_enable_player_control()

	# delay, then close door, hide teacher, etc.
	if door_close_after_cutscene_delay > 0.0:
		var d_tw: Tween = get_tree().create_tween() as Tween
		d_tw.tween_interval(door_close_after_cutscene_delay)
		await d_tw.finished

	# play close door animation (and door sfx will be played by same handler)
	var close_anim_len: float = _close_teacher_door()
	if close_anim_len > 0.0:
		var wait_tw: Tween = get_tree().create_tween() as Tween
		wait_tw.tween_interval(close_anim_len)
		await wait_tw.finished

	_hide_teacher()

	print("LockPanel: Cutscene zakończona.")

func _on_key_camera_switch_time() -> void:
	_key_camera_pending_tween = null
	if _last_spawned_key == null:
		var root_node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		_last_spawned_key = _find_node_by_name(root_node, "Level1_key")
	if _last_spawned_key == null:
		print("LockPanel: nie znaleziono klucza do pokazania na key camera.")
		return
	if not (_key_camera and _last_spawned_key is Node3D):
		print("LockPanel: brak key_camera lub key nie jest Node3D.")
		return
	var key_node3 := _last_spawned_key as Node3D
	_key_camera_prev_current = get_viewport().get_camera_3d()
	if _key_camera_prev_current == null:
		print("LockPanel: brak poprzedniej kamery - nie można zrobić płynnego przejścia.")
		return
	_main_camera_orig_transform = _key_camera_prev_current.global_transform

	var desired_tf: Transform3D = _key_camera_desired_transform
	# dynamic focus on key (uncomment to compute dynamic transform)
	# var desired_origin: Vector3 = key_node3.global_transform.origin + key_camera_offset
	# var dir: Vector3 = (key_node3.global_transform.origin - desired_origin)
	# if dir.length() == 0:
	#     dir = Vector3(0,0,-1)
	# desired_tf = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), desired_origin)

	_key_camera.global_transform = _main_camera_orig_transform
	_key_camera.current = true

	if key_camera_use_tween and key_camera_move_time > 0.0:
		var ktw := get_tree().create_tween()
		ktw.tween_property(_key_camera, "global_transform", desired_tf, key_camera_move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await ktw.finished
		_key_camera.global_transform = desired_tf
	else:
		_key_camera.global_transform = desired_tf

	_key_camera_switched = true
	print("LockPanel: switched to KeyCamera for key closeup:", _key_camera)

func _restore_from_key_camera() -> void:
	if _key_camera == null or not _key_camera_switched:
		return
	if _key_camera_prev_current == null:
		_key_camera.current = false
		_key_camera_switched = false
		print("LockPanel: brak prev camera przy restore; key camera wyłączona.")
		return
	if key_camera_use_tween and key_camera_move_time > 0.0:
		var rt := get_tree().create_tween()
		rt.tween_property(_key_camera, "global_transform", _main_camera_orig_transform, key_camera_move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await rt.finished
		_key_camera.global_transform = _main_camera_orig_transform
	_key_camera_prev_current.current = true
	_key_camera.current = false
	_key_camera_switched = false
	_key_camera_prev_current = null
	print("LockPanel: restored camera after key closeup.")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event.is_pressed():
		return
	for action in block_actions:
		if event.is_action_pressed(action, false):
			if close_on_esc and action == "ui_cancel":
				close_panel()
			get_viewport().set_input_as_handled()
			return

func open_panel() -> void:
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if freeze_world:
		_prev_paused = get_tree().paused
		get_tree().paused = true
		self.process_mode = Node.PROCESS_MODE_WHEN_PAUSED as Node.ProcessMode
		_set_subtree_process_mode(self, Node.PROCESS_MODE_WHEN_PAUSED as Node.ProcessMode)
	show()
	grab_focus()

func close_panel() -> void:
	hide()
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if freeze_world:
		_set_subtree_process_mode(self, Node.PROCESS_MODE_INHERIT as Node.ProcessMode)
		get_tree().paused = _prev_paused

func _set_subtree_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_subtree_process_mode(child, mode)

func _play_wrong_animation() -> void:
	print("Niepoprawny kod!")
	# play wrong answer sfx
	if _sfx_wrong and _sfx_wrong.has_method("play"):
		_sfx_wrong.call("play")
	# play shake animation if available
	if anim_player and anim_player.has_animation("answer_lock"):
		shaker.position = Vector2.ZERO
		anim_player.stop(true)
		anim_player.play("answer_lock")
	else:
		push_warning("Brak animacji 'answer_lock'.")

func _enable_monolog_area() -> void:
	if _monolog_area_node:
		_configure_and_activate_area(_monolog_area_node)
		return
	if monolog_area_path != NodePath(""):
		var maybe_area: Node = get_node_or_null(monolog_area_path)
		if maybe_area and maybe_area is Area3D:
			_monolog_area_node = maybe_area as Area3D
			_configure_and_activate_area(_monolog_area_node)
			return
		else:
			print("LockPanel: monolog_area_path ustawione, ale node nie znaleziono lub nie jest Area3D:", monolog_area_path)
	if monolog_area_scene:
		var inst: Node = monolog_area_scene.instantiate()
		var current_scene: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		current_scene.add_child(inst)
		var found_area: Area3D = _find_node_by_type(inst, "Area3D") as Area3D
		if found_area:
			_monolog_area_node = found_area
			_configure_and_activate_area(_monolog_area_node)
			return
		else:
			if inst is Area3D:
				_monolog_area_node = inst as Area3D
				_configure_and_activate_area(_monolog_area_node)
				return
			print("LockPanel: zinstancjonowano monolog_area_scene, ale nie znaleziono Area3D w poddrzewie.")

func _configure_and_activate_area(area_node: Area3D) -> void:
	if area_node == null:
		return
	if "monolog_lines" in area_node:
		area_node.set("monolog_lines", monolog_lines)
	if "monolog_duration" in area_node:
		area_node.set("monolog_duration", monolog_duration)
	if "monolog_ui_path" in area_node:
		if monolog_ui_path != NodePath(""):
			area_node.set("monolog_ui_path", monolog_ui_path)
	if "trigger_once" in area_node:
		area_node.set("trigger_once", true)
	area_node.monitoring = true
	area_node.monitorable = true
	_enable_collision_shapes(area_node)
	_set_visible_recursive(area_node, true)
	print("LockPanel: Area3D configured and monitoring enabled (MonologTrigger pattern). area:", area_node)
	if start_monolog_immediately:
		var root: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		var mon_ui: Node = _find_node_by_name(root, "MonologUI")
		if mon_ui and mon_ui.has_method("start_monolog"):
			mon_ui.call("start_monolog", monolog_lines, monolog_duration)
			print("LockPanel: start_monolog_immediately -> wywołano start_monolog na MonologUI.")
		else:
			print("LockPanel: start_monolog_immediately ustawione, ale nie znaleziono MonologUI z metodą start_monolog.")

func _enable_collision_shapes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			var cs := child as CollisionShape3D
			if cs.has_method("set_disabled"):
				cs.set_disabled(false)
			elif "disabled" in cs:
				cs.disabled = false
		_enable_collision_shapes(child)

func _set_visible_recursive(node: Node, value: bool) -> void:
	if node == null:
		return
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = value
	for child in node.get_children():
		_set_visible_recursive(child, value)

# ---- nowe helpery do typing SFX ----

func _start_typing_sfx_for_monolog() -> void:
	if _typing_sfx_player == null:
		return
	if not _typing_sfx_player.has_method("play"):
		return
	_typing_sfx_player.call("play")

func _stop_typing_sfx() -> void:
	if _typing_sfx_player and _typing_sfx_player.has_method("stop"):
		_typing_sfx_player.call("stop")

# ------------------------------------

func _wait_for_monolog_or_timeout(mon_ui: Node, timeout: float = 0.0) -> void:
	if mon_ui != null:
		var signals := ["monolog_finished", "finished", "dialog_finished", "done", "completed"]
		for s in signals:
			if mon_ui.has_signal(s):
				print("LockPanel: waiting for MonologUI signal:", s)
				match s:
					"monolog_finished":
						await mon_ui.monolog_finished
					"finished":
						await mon_ui.finished
					"dialog_finished":
						await mon_ui.dialog_finished
					"done":
						await mon_ui.done
					"completed":
						await mon_ui.completed
				print("LockPanel: detected monolog finish signal:", s)

				_stop_typing_sfx()

				return
	var wait_time: float = timeout if timeout > 0.0 else cutscene_hold_time
	wait_time += 0.25
	var tw: Tween = get_tree().create_tween() as Tween
	tw.tween_interval(wait_time)
	await tw.finished
	print("LockPanel: waited fallback timeout:", wait_time)

	_stop_typing_sfx()

func _spawn_key() -> void:
	if key_scene == null:
		print("LockPanel: key_scene nie ustawione — brak klucza do spawnienia.")
		return
	var inst: Node = key_scene.instantiate()
	var current_scene: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
	current_scene.add_child(inst)
	_last_spawned_key = inst
	var spawn_transform: Transform3D = Transform3D.IDENTITY
	var spawn_node: Node = null
	if key_spawn_path != NodePath(""):
		spawn_node = get_node_or_null(key_spawn_path)
		if spawn_node == null:
			print("LockPanel: key_spawn_path ustawione, ale node nie znaleziono:", key_spawn_path)
	if spawn_node == null:
		var root: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		var names := ["KeySpawn", "KeySpawnPoint", "KeySpawnSpot", "Table", "Desk", "Key"]
		for nm in names:
			spawn_node = _find_node_by_name(root, nm)
			if spawn_node:
				break
	if spawn_node == null:
		if teacher_node_path != NodePath(""):
			var tnode: Node = get_node_or_null(teacher_node_path)
			if tnode and tnode is Node3D:
				spawn_transform = (tnode as Node3D).global_transform.translated(Vector3(0, 0, 0.5))
				print("LockPanel: key spawn fallback -> near teacher at:", spawn_transform.origin)
		else:
			print("LockPanel: Nie znaleziono punktu spawn (KeySpawn/Table) — używam instancji bez korekty pozycji (lokalny transform).")
	else:
		if spawn_node is Node3D:
			spawn_transform = (spawn_node as Node3D).global_transform
			print("LockPanel: Przygotowano spawn transform z node:", spawn_node.get_path())
		else:
			print("LockPanel: znaleziono spawn node, ale nie jest Node3D:", spawn_node)
	if inst is Node3D:
		(inst as Node3D).global_transform = spawn_transform
	if inst is RigidBody3D:
		var rb := inst as RigidBody3D
		if rb.has_method("set_linear_velocity"):
			rb.set_linear_velocity(Vector3.ZERO)
		elif "linear_velocity" in rb:
			rb.linear_velocity = Vector3.ZERO
		if rb.has_method("set_angular_velocity"):
			rb.set_angular_velocity(Vector3.ZERO)
		elif "angular_velocity" in rb:
			rb.angular_velocity = Vector3.ZERO
	print("LockPanel: Klucz zinstancjonowany:", inst, " parent:", current_scene)

func _start_monolog_direct() -> Node:
	var mon_ui: Node = null
	if monolog_ui_path != NodePath(""):
		mon_ui = get_node_or_null(monolog_ui_path)
		if mon_ui == null:
			print("LockPanel: monolog_ui_path ustawione ale nie znaleziono:", monolog_ui_path)
	if mon_ui == null:
		var root: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		mon_ui = _find_node_by_name(root, "MonologUI")
		if mon_ui:
			print("LockPanel: autodetected MonologUI at:", mon_ui.get_path())
	if mon_ui == null:
		print("LockPanel: Nie znaleziono MonologUI — nie można uruchomić monologu bezpośrednio.")
		return null
	var n: Node = mon_ui
	var depth: int = 0
	while n != null and depth < 8:
		if "visible" in n:
			n.visible = true
		n = n.get_parent()
		depth += 1
	if mon_ui.has_method("start_monolog"):
		print("LockPanel: Uruchamiam MonologUI.start_monolog()")
		mon_ui.call("start_monolog", monolog_lines, monolog_duration)
		_start_typing_sfx_for_monolog()
		return mon_ui
	var text: String = ""
	for i in range(monolog_lines.size()):
		if i > 0:
			text += "\n"
		text += str(monolog_lines[i])
	var label_node: Node = _find_node_by_type(mon_ui, "Label")
	if label_node:
		if "text" in label_node:
			label_node.set("text", text)
			print("LockPanel: fallback - ustawiono Label.text")
			_start_typing_sfx_for_monolog()
			return mon_ui
		if label_node.has_method("set_text"):
			label_node.call("set_text", text)
			print("LockPanel: fallback - wywołano Label.set_text")
			_start_typing_sfx_for_monolog()
			return mon_ui
	print("LockPanel: MonologUI znaleziono, ale nie ma metody start_monolog ani Label do fallbacku.")
	return mon_ui

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

func _disable_player_control() -> void:
	if _player_node == null:
		_player_node = _auto_find_player_body()
	if _player_node == null:
		_prev_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("LockPanel: nie znaleziono PlayerBody — zastosowano fallback (mouse visible).")
		return
	if _player_node.has_method("set_controls_enabled"):
		_player_node.call("set_controls_enabled", false)
		print("LockPanel: wywołano set_controls_enabled(false) na:", _player_node)
		return
	_prev_mouse_mode = Input.mouse_mode
	_player_node.set_process(false)
	_player_node.set_physics_process(false)
	print("LockPanel: wyłączono processing PlayerBody (fallback):", _player_node)

func _enable_player_control() -> void:
	if _player_node == null:
		Input.mouse_mode = _prev_mouse_mode
		print("LockPanel: przywrócono mouse_mode (brak PlayerBody).")
		return
	if _player_node.has_method("set_controls_enabled"):
		_player_node.call("set_controls_enabled", true)
		Input.mouse_mode = _prev_mouse_mode
		print("LockPanel: wywołano set_controls_enabled(true) na:", _player_node)
		return
	_player_node.set_process(true)
	_player_node.set_physics_process(true)
	Input.mouse_mode = _prev_mouse_mode
	print("LockPanel: przywrócono processing PlayerBody (fallback):", _player_node)

# ---------- teacher / door helpers ----------

func _open_teacher_door() -> void:
	# play door SFX (same for open and close) and play open animation
	if _sfx_door and _sfx_door.has_method("play"):
		_sfx_door.call("play")
	if door_anim_player_path == NodePath(""):
		var root: Node = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		var maybe_player: Node = _find_node_by_name(root, "DoorAnimationPlayer")
		if maybe_player and maybe_player is AnimationPlayer:
			var ap: AnimationPlayer = maybe_player as AnimationPlayer
			if ap.has_animation(door_anim_open_name):
				ap.play(door_anim_open_name)
				print("LockPanel: Odtwarzam animację drzwi (auto):", door_anim_open_name)
				return
			else:
				print("LockPanel: DoorAnimationPlayer istnieje, ale brak animacji:", door_anim_open_name)
		return
	else:
		var player_node: Node = get_node_or_null(door_anim_player_path)
		if player_node and player_node is AnimationPlayer:
			var ap2: AnimationPlayer = player_node as AnimationPlayer
			if ap2.has_animation(door_anim_open_name):
				ap2.play(door_anim_open_name)
				print("LockPanel: Odtwarzam animację drzwi (path):", door_anim_open_name)
			else:
				print("LockPanel: DoorAnimationPlayer (path) brak animacji:", door_anim_open_name)

# returns estimated animation length in seconds (0.0 if unknown), also plays door SFX
func _close_teacher_door() -> float:
	# same door sfx for close
	if _sfx_door and _sfx_door.has_method("play"):
		_sfx_door.call("play")
	var anim_len: float = 0.0
	if door_anim_player_path == NodePath(""):
		var root = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		var maybe_player = _find_node_by_name(root, "DoorAnimationPlayer")
		if maybe_player and maybe_player is AnimationPlayer:
			var ap: AnimationPlayer = maybe_player
			if ap.has_animation(door_anim_close_name):
				ap.play(door_anim_close_name)
				print("LockPanel: Odtwarzam animację zamknięcia drzwi:", door_anim_close_name)
				var anim = ap.get_animation(door_anim_close_name)
				if anim and "length" in anim:
					anim_len = anim.length
				else:
					anim_len = 0.5
			else:
				print("LockPanel: brak animacji zamykania drzwi:", door_anim_close_name)
	else:
		var ap_node = get_node_or_null(door_anim_player_path)
		if ap_node and ap_node is AnimationPlayer:
			var ap2: AnimationPlayer = ap_node
			if ap2.has_animation(door_anim_close_name):
				ap2.play(door_anim_close_name)
				print("LockPanel: Odtwarzam animację zamknięcia drzwi (path):", door_anim_close_name)
				var anim2 = ap2.get_animation(door_anim_close_name)
				if anim2 and "length" in anim2:
					anim_len = anim2.length
				else:
					anim_len = 0.5
			else:
				print("LockPanel: DoorAnimationPlayer (path) brak animacji:", door_anim_close_name)
	return anim_len

func _show_teacher() -> void:
	var tnode: Node = null
	if teacher_node_path != NodePath(""):
		tnode = get_node_or_null(teacher_node_path)
		if tnode == null:
			print("LockPanel: teacher_node_path ustawiony ale node nie znaleziono:", teacher_node_path)
	else:
		var root = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		tnode = _find_node_by_name(root, "Teacher")
	if tnode == null:
		print("LockPanel: _show_teacher() — brak nauczycielki")
		return
	if "visible" in tnode:
		tnode.visible = true
	_show_teacher_recursive(tnode)
	print("LockPanel: nauczycielka pokazana:", tnode)

func _show_teacher_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D:
			child.visible = true
		elif "visible" in child:
			child.visible = true
		_show_teacher_recursive(child)

func _hide_teacher() -> void:
	var tnode: Node = null
	if teacher_node_path != NodePath(""):
		tnode = get_node_or_null(teacher_node_path)
	else:
		var root = get_tree().get_current_scene() if get_tree().get_current_scene() else get_tree().root
		tnode = _find_node_by_name(root, "Teacher")
	if tnode == null:
		print("LockPanel: _hide_teacher() — nauczycielka nie znaleziona")
		return
	if "visible" in tnode:
		tnode.visible = false
	_set_visible_recursive(tnode, false)
	print("LockPanel: nauczycielka ukryta:", tnode)
