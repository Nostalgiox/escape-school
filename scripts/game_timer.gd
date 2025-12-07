# TeacherTimer.gd
# Godot 4.x — finalna poprawiona wersja (jawne Array[String] przy wywołaniu monologu)
extends Node

# --- SYGNAŁY ---
signal cutscene_started()
signal cutscene_ended()
signal timer_updated(remaining_seconds : int)
signal timer_finished()

# --- EXPORTY (ustaw w Inspectorze) ---
@export var total_time_seconds : int = 30 * 60        # 30 minut domyślnie
@export var interval_seconds : int = 3 * 60           # co ile sekund pojawia się nauczycielka
@export var fallback_cutscene_duration : float = 10.0 # fallback, jeśli dialog nie emituje zakończenia

@export var teacher_path : NodePath = NodePath("")        # parent (np. StaticBody3D)
@export var teacher_visual_path : NodePath = NodePath("") # bezpośredni MeshInstance3D / VisualInstance3D (opcjonalny)
@export var teacher_camera_path : NodePath = NodePath("") # Camera3D / Camera2D
@export var monolog_ui_path : NodePath = NodePath("")     # node UI obsługujący dialog (Control / CanvasLayer)

@export var hints : Array = ["Spójrz na zegar.", "Może klucz jest w szufladzie.", "Pomyśl o równaniu z zadania."]

# nazwa metody w monolog_ui do wywołania (domyślnie nie używana w Twoim MonologUI)
@export var monolog_method_name : String = "show_hint"
# nazwa sygnału, który monolog emituje po zakończeniu (Twój MonologUI używa 'monolog_finished')
@export var monolog_finished_signal_name : String = "monolog_finished"

# --- Internal ---
var _teacher : Node = null
var _teacher_visual : Node = null
var _teacher_camera : Node = null
var _monolog_ui : Node = null
var _hint_index : int = 0

var _countdown_timer : Timer
var _interval_timer : Timer
var _tick_timer : Timer

var _cutscene_running : bool = false

# --- READY ---
func _ready() -> void:
	# resolve nodes z exportów
	if teacher_path != NodePath(""):
		_teacher = get_node_or_null(teacher_path)
	if teacher_visual_path != NodePath(""):
		_teacher_visual = get_node_or_null(teacher_visual_path)
	if teacher_camera_path != NodePath(""):
		_teacher_camera = get_node_or_null(teacher_camera_path)
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)

	# jeśli nie ustawiono teacher_visual ręcznie -> znajdź pierwszy visual descendant
	if _teacher_visual == null and _teacher:
		_teacher_visual = _find_visual_descendant(_teacher)

	# domyślnie ukryj teacher visual
	if _teacher_visual:
		_safe_set_visible(_teacher_visual, false)

	# zabezpieczenie interval_seconds
	if interval_seconds <= 0:
		interval_seconds = 3 * 60
		push_warning("TeacherTimer: interval_seconds was <= 0 — reset to 180s to avoid immediate cutscene.")

	# jeżeli kamera miała current w edytorze — dezaktywuj ją
	if _teacher_camera and (_teacher_camera is Camera3D or _teacher_camera is Camera2D):
		_teacher_camera.current = false

	# utworzenie timerów
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = float(total_time_seconds)
	_countdown_timer.one_shot = true
	add_child(_countdown_timer)
	_countdown_timer.timeout.connect(Callable(self, "_on_countdown_finished"))

	_interval_timer = Timer.new()
	_interval_timer.wait_time = float(interval_seconds)
	_interval_timer.one_shot = false
	add_child(_interval_timer)
	_interval_timer.timeout.connect(Callable(self, "_on_interval_timeout"))

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.timeout.connect(Callable(self, "_on_tick"))

	# start timerów (interval start(x) — pierwszy timeout po pełnym interwale)
	_countdown_timer.start()
	_tick_timer.start()
	_interval_timer.start(float(interval_seconds))

	# podłącz sygnał zakończenia dialogu jeśli node i nazwa sygnału ustawione
	if _monolog_ui and monolog_finished_signal_name != "":
		if _monolog_ui.has_signal(monolog_finished_signal_name):
			_monolog_ui.connect(monolog_finished_signal_name, Callable(self, "_on_monolog_finished"))

	# emit initial timer state
	emit_signal("timer_updated", int(_remaining_seconds()))
	print("TeacherTimer ready — interval_seconds:", interval_seconds, "total:", total_time_seconds)

# --- TIMERY ---
func _on_tick() -> void:
	emit_signal("timer_updated", int(_remaining_seconds()))

func _remaining_seconds() -> int:
	if _countdown_timer:
		return int(ceil(_countdown_timer.time_left))
	return 0

func _on_countdown_finished() -> void:
	emit_signal("timer_updated", 0)
	emit_signal("timer_finished")
	if _interval_timer:
		_interval_timer.stop()
	if _tick_timer:
		_tick_timer.stop()

func _on_interval_timeout() -> void:
	print("[TeacherTimer] interval timeout — attempting to start cutscene")
	play_teacher_cutscene()

# --- GŁÓWNA FUNKCJA CUTSCENE ---
func play_teacher_cutscene() -> void:
	# zabezpieczenia
	if _cutscene_running:
		print("[TeacherTimer] cutscene already running -> skip")
		return
	if _countdown_timer and _countdown_timer.time_left <= 0:
		print("[TeacherTimer] global countdown finished -> skip cutscene")
		return

	print("=== play_teacher_cutscene() called ===")
	_print_node_info("teacher", _teacher)
	_print_node_info("teacher_visual", _teacher_visual)
	_print_node_info("teacher_camera", _teacher_camera)
	_print_node_info("monolog_ui", _monolog_ui)

	# pokaż visual(e)
	var visuals : Array = []
	if _teacher_visual:
		visuals = _find_all_visual_descendants(_teacher_visual)
	elif _teacher:
		visuals = _find_all_visual_descendants(_teacher)

	print("[TeacherTimer] found visuals:", visuals.size())
	for v in visuals:
		_safe_set_visible(v, true)
		print("[TeacherTimer] show visual:", v.get_path(), "class:", v.get_class())

	if visuals.size() == 0:
		push_warning("TeacherTimer: Nie znaleziono visual descendants dla teacher. Ustaw teacher_visual_path na MeshInstance3D/VisualInstance3D, lub sprawdź strukturę sceny.")

	# ustaw kamerę jako active (jeżeli to Camera3D/Camera2D)
	if _teacher_camera:
		if _teacher_camera is Camera3D or _teacher_camera is Camera2D:
			_teacher_camera.current = true
			print("[TeacherTimer] teacher_camera set to current:", _teacher_camera.get_path())
		else:
			print("[TeacherTimer] teacher_camera ma nieoczekiwany typ:", _teacher_camera.get_class())

	# przygotuj hint
	var hint_text : String = ""
	if hints.size() > 0:
		hint_text = hints[_hint_index % hints.size()]
	_hint_index += 1

	# --- WYWOŁANIE MONOLOGU — teraz z jawnym Array[String] jeśli potrzeba ---
	var used_monolog : bool = false
	if _monolog_ui:
		# debugging - wypisz dostępne metody i sygnały
		var method_names : Array = []
		for m in _monolog_ui.get_method_list():
			if typeof(m) == TYPE_DICTIONARY and m.has("name"):
				method_names.append(String(m["name"]))
		print("[TeacherTimer] monolog_ui methods:", method_names)

		var signal_names : Array = []
		for s in _monolog_ui.get_signal_list():
			if typeof(s) == TYPE_DICTIONARY and s.has("name"):
				signal_names.append(String(s["name"]))
		print("[TeacherTimer] monolog_ui signals:", signal_names)

		# preferowane: jeśli target jest Twoją klasą MonologUI (class_name MonologUI) lub metoda to start_monolog -> wywołaj z Array[String]
		var is_monolog_class: bool = (_monolog_ui.get_class() == "MonologUI")
		var should_call_with_array: bool = false
		if monolog_method_name == "start_monolog" or is_monolog_class:
			should_call_with_array = true

		# 1) jeśli wyraźnie mamy monolog_method_name i node ma taką metodę
		if monolog_method_name != "" and _monolog_ui.has_method(monolog_method_name):
			if should_call_with_array:
				print("[TeacherTimer] Calling monolog method (typed Array[String]) :", monolog_method_name)
				# jawnie utwórz typowaną tablicę Array[String]
				var lines : Array[String] = [hint_text]
				_monolog_ui.call(monolog_method_name, lines, 2.0)
			else:
				print("[TeacherTimer] Calling monolog method (string) :", monolog_method_name)
				_monolog_ui.call(monolog_method_name, hint_text)
			used_monolog = true
		else:
			# 2) spróbuj najczęściej spotykanych aliasów; jeżeli nazwa zawiera 'monolog' lub to klasa MonologUI -> wywołaj z Array[String]
			for alt_name in ["start_dialog", "show_dialog", "show_monologue", "start_monolog", "open_dialog", "show_hint", "start_conversation"]:
				if _monolog_ui.has_method(alt_name):
					var alt_should_array: bool = (alt_name == "start_monolog") or is_monolog_class or (alt_name.find("monolog") != -1)
					print("[TeacherTimer] Found alternative monolog method:", alt_name, "use_array:", alt_should_array)
					if alt_should_array:
						var alt_lines : Array[String] = [hint_text]
						_monolog_ui.call(alt_name, alt_lines, 2.0)
					else:
						_monolog_ui.call(alt_name, hint_text)
					used_monolog = true
					break

		# jeśli metoda została wywołana, ale nie ma sygnału zakończenia — ustaw fallback timer
		if used_monolog:
			if monolog_finished_signal_name == "" or not (_monolog_ui and _monolog_ui.has_signal(monolog_finished_signal_name)):
				_start_fallback_cutscene_timer()
	else:
		push_warning("TeacherTimer: monolog_ui nie jest ustawiony (null). Ustaw monolog_ui_path w Inspectorze, jeśli chcesz wyświetlić dialog.")

	# jeżeli nie użyto monologu wcale — ustaw fallback timer
	if not used_monolog:
		print("[TeacherTimer] monolog not used -> starting fallback timer")
		_start_fallback_cutscene_timer()

	_cutscene_running = true
	emit_signal("cutscene_started")
	print("=== play_teacher_cutscene() end ===")

# --- ZAKOŃCZENIE CUTSCENE ---
func _on_monolog_finished(...args) -> void:
	_end_cutscene()

func _on_fallback_cutscene_timeout() -> void:
	_end_cutscene()

func _end_cutscene() -> void:
	# ukryj znalezione visual descendants
	var visuals : Array = []
	if _teacher_visual:
		visuals = _find_all_visual_descendants(_teacher_visual)
	elif _teacher:
		visuals = _find_all_visual_descendants(_teacher)
	for v in visuals:
		_safe_set_visible(v, false)

	# deaktywuj kamerę nauczyciela (jeżeli to Camera3D/Camera2D)
	if _teacher_camera and (_teacher_camera is Camera3D or _teacher_camera is Camera2D):
		_teacher_camera.current = false

	_cutscene_running = false
	emit_signal("cutscene_ended")
	print("[TeacherTimer] cutscene ended, visuals hidden, camera reset")

# --- HELPERY I DEBUG ---
func _start_fallback_cutscene_timer() -> void:
	var fallback_timer := Timer.new()
	fallback_timer.wait_time = fallback_cutscene_duration
	fallback_timer.one_shot = true
	add_child(fallback_timer)
	fallback_timer.timeout.connect(Callable(self, "_on_fallback_cutscene_timeout"))
	fallback_timer.start()

func _find_visual_descendant(root: Node) -> Node:
	if root == null:
		return null
	if root is VisualInstance3D or root is MeshInstance3D or root is Sprite3D or root is CanvasItem:
		return root
	for child in root.get_children():
		if child is Node:
			var found := _find_visual_descendant(child)
			if found:
				return found
	return null

func _find_all_visual_descendants(root: Node) -> Array:
	var visuals : Array = []
	if root == null:
		return visuals
	if root is VisualInstance3D or root is MeshInstance3D or root is Sprite3D or root is CanvasItem:
		visuals.append(root)
	for child in root.get_children():
		if child is Node:
			visuals += _find_all_visual_descendants(child)
	return visuals

# sprawdza czy node ma property o danej nazwie
func _node_has_property(node: Node, prop_name: String) -> bool:
	if node == null:
		return false
	for p in node.get_property_list():
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p["name"]) == prop_name:
			return true
	return false

# bezpieczne ustawienie widoczności
func _safe_set_visible(node: Node, value: bool) -> void:
	if node == null:
		return

	# 1) preferowane: show()/hide()
	if node.has_method("show") and node.has_method("hide"):
		if value:
			node.show()
		else:
			node.hide()
		return

	# 2) jeśli ma property 'visible' -> ustaw bezpośrednio
	if _node_has_property(node, "visible"):
		node.visible = value
		return

	# 3) nie da się ustawić -> wypisz ostrzeżenie
	print("[TeacherTimer] _safe_set_visible: nie można ustawić 'visible' dla:", node.get_path(), "klasa:", node.get_class())

func _print_node_info(name: String, node: Node) -> void:
	if node == null:
		print("[TeacherTimer] %s: null" % name)
	else:
		print("[TeacherTimer] %s: %s (type: %s)" % [name, node.get_path(), node.get_class()])
