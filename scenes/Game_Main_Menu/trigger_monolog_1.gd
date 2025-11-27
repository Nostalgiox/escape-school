extends Area3D

@export var monolog_lines : Array[String] = [
	"Tutaj coś jest...",
	"Może zobaczę co się tutaj kryje."
]
@export var monolog_duration : float = 2.5
# W Inspectorze możesz ustawić ścieżkę do node'a MonologUI (Control/MonologUI). 
# Eksportujemy jako NodePath żeby łatwo wskazać node z drzewa sceny.
@export var monolog_ui_path: NodePath = NodePath("")

# Jeśli true — trigger zadziała tylko raz (jak w twoim oryginale).
# Jeśli false — można triggerować wielokrotnie.
@export var trigger_once: bool = true

var has_been_triggered: bool = false
var _monolog_ui: Node = null

func _ready() -> void:
	# automatyczne podłączenie sygnału (jeśli nie zrobione w edytorze)
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	# spróbuj resolve monolog_ui z podanego pathu (jeśli ustawiony)
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)
		if _monolog_ui == null:
			push_warning("MonologTrigger: monolog_ui_path ustawiony, ale node nie znaleziony: %s" % str(monolog_ui_path))
	else:
		# fallback: szukamy node'a o nazwie "MonologUI" w current_scene (użyteczne przy prototypach)
		var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		if root:
			_monolog_ui = root.find_node("MonologUI", true, false)
			if _monolog_ui:
				print("MonologTrigger: autodetected MonologUI at: ", _monolog_ui.get_path())

	# debug
	print("[MonologTrigger] ready. trigger_once=", trigger_once, " monolog_ui=", _monolog_ui)


func _on_body_entered(body: Node) -> void:
	# early exit gdy już triggerowane i ustawiono jednorazowy trigger
	if trigger_once and has_been_triggered:
		return

	# sprawdź czy to gracz — preferujemy grupę "player"
	if not (body and body.is_in_group("player")):
		return

	# upewnij się, że mamy UI — jeśli nie, log i exit
	if _monolog_ui == null:
		push_warning("MonologTrigger: MonologUI not set or not found. Set monolog_ui_path in inspector or add a MonologUI node named 'MonologUI' to the scene.")
		return

	# wywołaj monolog
	if _monolog_ui.has_method("start_monolog"):
		_monolog_ui.start_monolog(monolog_lines, monolog_duration)
	else:
		push_warning("MonologTrigger: found node at monolog_ui_path but it has no method 'start_monolog'.")

	has_been_triggered = true
