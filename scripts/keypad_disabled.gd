extends Node

@export var monolog_lines : Array[String] = [
	"Chyba zablokowałem panel numeryczny..."
]
@export var monolog_duration : float = 2.5
@export var monolog_ui_path: NodePath = NodePath("")

@export var typing_sfx_player_path: NodePath = NodePath("")
@export var stop_sfx_after_monolog: bool = true

var has_been_triggered := false
var _monolog_ui: Node = null
var _typing_sfx_player: Node = null


func _ready() -> void:
	# znajdź MonologUI
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)
	else:
		var root = get_tree().current_scene
		if root:
			_monolog_ui = root.find_node("MonologUI", true, false)

	# dźwięk
	if typing_sfx_player_path != NodePath(""):
		_typing_sfx_player = get_node_or_null(typing_sfx_player_path)


# 🔥 TO WYWOŁA KEYPAD
func trigger_monolog() -> void:
	if has_been_triggered:
		return
	if _monolog_ui == null:
		return

	if _monolog_ui.has_method("start_monolog"):
		_monolog_ui.start_monolog(monolog_lines, monolog_duration)

	if _typing_sfx_player:
		_typing_sfx_player.play()
		if stop_sfx_after_monolog:
			await get_tree().create_timer(monolog_duration).timeout
			_typing_sfx_player.stop()

	has_been_triggered = true


func _on_key_pad_keypad_locked() -> void:
	trigger_monolog()
