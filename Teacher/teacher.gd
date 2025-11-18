extends CharacterBody3D

@export var monolog_node_path: NodePath = NodePath("") # opcjonalnie ustaw w inspectorze, jeśli chcesz auto-connect
@export var voice_lines: Array[AudioStream] = []       # opcjonalne: dźwięki per linia
@onready var voice: AudioStreamPlayer = $Voice         # jeżeli masz AudioStreamPlayer o tej nazwie

var _connected: bool = false

func _ready() -> void:
	# jeśli w inspectorze ustawiono ścieżkę do MonologUI — spróbuj połączyć się automatycznie
	if monolog_node_path != NodePath(""):
		var mu = get_node_or_null(monolog_node_path)
		if mu:
			connect_to_monolog(mu)


# Wywołaj tę funkcję aby podłączyć się do MonologUI
func connect_to_monolog(monolog_ui: Node) -> void:
	if not monolog_ui or _connected:
		return
	# podłączamy sygnały
	monolog_ui.connect("line_started", Callable(self, "_on_line_started"))
	monolog_ui.connect("monolog_finished", Callable(self, "_on_monolog_finished"))
	_connected = true


func _on_line_started(line_index: int, text: String) -> void:
	# minimalne zachowanie: wypisz do konsoli i (opcjonalnie) odtwórz dźwięk powiązany z tą linijką
	print("Teacher: line started #", line_index, ": ", text)
	if voice and voice_lines.size() > line_index and voice_lines[line_index] != null:
		voice.stream = voice_lines[line_index]
		voice.play()


func _on_monolog_finished() -> void:
	print("Teacher: monolog finished")
	# nic więcej — scena może zostać, albo trigger może usunąć teachera jeśli chcesz
