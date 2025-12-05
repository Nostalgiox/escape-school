extends Area3D

@export var monolog_lines : Array[String] = [
	"Ale tu ciemno, ledwo widzę cokolwiek. Muszę znaleźć sposób, żeby zapalić światło."
]
@export var monolog_duration : float = 2.5
@export var monolog_ui_path: NodePath = NodePath("")

@export var trigger_once: bool = true

# ---- NOWE ZMIENNE DŹWIĘKU ----
# Ścieżka do AudioStreamPlayer/AudioStreamPlayer3D z efektem klikania
@export var typing_sfx_player_path: NodePath = NodePath("")
# Czy dźwięk ma być automatycznie zatrzymany po monolog_duration
@export var stop_sfx_after_monolog: bool = true

var has_been_triggered: bool = false
var _monolog_ui: Node = null
var _typing_sfx_player: Node = null


func _ready() -> void:
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)
		if _monolog_ui == null:
			push_warning("MonologTrigger: monolog_ui_path ustawiony, ale node nie znaleziony: %s" % str(monolog_ui_path))
	else:
		var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		if root:
			_monolog_ui = root.find_node("MonologUI", true, false)
			if _monolog_ui:
				print("MonologTrigger: autodetected MonologUI at: ", _monolog_ui.get_path())

	# ---- INIT DŹWIĘKU ----
	if typing_sfx_player_path != NodePath(""):
		_typing_sfx_player = get_node_or_null(typing_sfx_player_path)
		if _typing_sfx_player == null:
			push_warning("MonologTrigger: typing_sfx_player_path ustawiony, ale node nie znaleziony: %s" % str(typing_sfx_player_path))

	# debug
	print("[MonologTrigger] ready. trigger_once=", trigger_once, " monolog_ui=", _monolog_ui, " typing_sfx=", _typing_sfx_player)


func _on_body_entered(body: Node) -> void:
	if trigger_once and has_been_triggered:
		return
	if not (body and body.is_in_group("player")):
		return
	if _monolog_ui == null:
		push_warning("MonologTrigger: MonologUI not set or not found. Set monolog_ui_path in inspector or add a MonologUI node named 'MonologUI' to the scene.")
		return

	# uruchamiamy monolog
	if _monolog_ui.has_method("start_monolog"):
		_monolog_ui.start_monolog(monolog_lines, monolog_duration)
	else:
		push_warning("MonologTrigger: found node at monolog_ui_path but it has no method 'start_monolog'.")
		return

	# ---- URUCHAMIANIE DŹWIĘKU ----
	if _typing_sfx_player and _typing_sfx_player.has_method("play"):
		_typing_sfx_player.play()

		# Opcjonalnie zatrzymujemy dźwięk po czasie trwania monologu
		if stop_sfx_after_monolog:
			_stop_sfx_later(monolog_duration)

	has_been_triggered = true


# Oddzielna funkcja asynchroniczna do zatrzymania dźwięku po czasie
func _stop_sfx_later(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if _typing_sfx_player and _typing_sfx_player.has_method("stop"):
		_typing_sfx_player.stop()
