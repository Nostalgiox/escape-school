extends Area3D
# TeacherMonologTrigger.gd
# Po wejściu gracza odtwarza monolog (nauczycielka) i po jego zakończeniu odblokowuje drzwi.

@export var monolog_ui_path: NodePath = NodePath("")   # Control -> MonologUI
@export var door_node_path: NodePath = NodePath("")   # node drzwi (ma metodę unlock() lub AnimationPlayer)
@export var monolog_lines: Array[String] = [
	"Zanim zaczniemy… pewnie zastanawiasz się, dlaczego tu jesteś.",
	"To proste. Znowu przeszkadzałeś na lekcji.",
	"Znowu nie uważałeś, nie słuchałeś, nie robiłeś notatek.",
	"Każdy inny uczeń już dawno wyszedł do domu.",
	"Ale ty… ty został(e)ś.",
	"Koza nie jest karą. To… szansa.",
	"Szansa, żeby wreszcie nadrobić to, czego nie potrafisz zapamiętać.",
	"Może tym razem coś do ciebie dotrze.",
	"A jeśli nie… mam mnóstwo czasu.",
	"Tak, dobrze słyszysz.",
	"Nikt nie będzie nam przeszkadzał.",
	"Tylko ty… i ja.",
	"Zacznijmy więc od początku."
]
@export var monolog_duration: float = 2.5   # sekundy na linię (przekaż takie samo do MonologUI)
@export var trigger_once: bool = true

var _monolog_ui: Control = null
var _door_node: Node = null
var _has_triggered: bool = false

# Flaga zabezpieczająca przed natychmiastowym odpalenie przy starcie sceny
var _ready_complete: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true

	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path) as Control
	if door_node_path != NodePath(""):
		_door_node = get_node_or_null(door_node_path)

	# defensywny connect
	var cb := Callable(self, "_on_body_entered")
	if not is_connected("body_entered", cb):
		connect("body_entered", cb)

	print("[TeacherMonologTrigger] ready. monolog_ui:", _monolog_ui, " door:", _door_node)

	# opóźnij aktywację triggera o jedną klatkę — dzięki temu wejścia które już
	# zaszły przy inicjalizacji nie będą liczone jako 'wejście gracza'.
	call_deferred("_finish_ready")


func _finish_ready() -> void:
	_ready_complete = true
	# dodatkowy debug: kto jest aktualnie w obszarze (opcjonalny)
	# To może pomóc: (Area3D ma metodę get_overlapping_bodies() w niektórych wersjach)
	if has_method("get_overlapping_bodies"):
		var list = get_overlapping_bodies()
		print("[TeacherMonologTrigger] finish_ready: overlapping bodies:", list)
	else:
		print("[TeacherMonologTrigger] finish_ready: ready_complete set, overlapping bodies not available.")


func _on_body_entered(body: Node) -> void:
	# ignoruj zdarzenia zanim _ready_complete zostanie ustawione
	if not _ready_complete:
		print("[TeacherMonologTrigger] Ignoring body_entered during init. body:", body)
		return

	if _has_triggered and trigger_once:
		print("[TeacherMonologTrigger] already triggered, ignoring.")
		return
	if not _is_node_player(body):
		print("[TeacherMonologTrigger] body_entered but not player:", body)
		return

	print("[TeacherMonologTrigger] body_entered -> player detected:", body)
	_has_triggered = true

	# Jeśli jest MonologUI i ma metodę start_monolog -> uruchom
	if _monolog_ui != null and _monolog_ui.has_method("start_monolog"):
		# jeżeli MonologUI emituje sygnał monolog_finished — użyj go
		if _monolog_ui.has_signal("monolog_finished"):
			# podłącz jednorazowo
			if not _monolog_ui.is_connected("monolog_finished", Callable(self, "_on_monolog_finished")):
				_monolog_ui.connect("monolog_finished", Callable(self, "_on_monolog_finished"))
			_monolog_ui.call("start_monolog", monolog_lines, monolog_duration)
			print("[TeacherMonologTrigger] started monolog -> waiting for monolog_finished signal.")
			return
		else:
			# brak sygnału — użyj estymowanego timera (liczba linii * duration + margin)
			_monolog_ui.call("start_monolog", monolog_lines, monolog_duration)
			var est: float = max(0.1, float(monolog_lines.size()) * monolog_duration + 0.5)
			print("[TeacherMonologTrigger] started monolog -> using estimated timer:", est)
			var t: SceneTreeTimer = get_tree().create_timer(est)
			t.connect("timeout", Callable(self, "_on_monolog_finished_estimated"))
			return

	# Fallback: brak MonologUI -> odpal od razu unlock
	print("[TeacherMonologTrigger] MonologUI not found -> unlocking immediately.")
	_call_unlock()


func _on_monolog_finished() -> void:
	print("[TeacherMonologTrigger] monolog_finished received.")
	_call_unlock()


func _on_monolog_finished_estimated() -> void:
	print("[TeacherMonologTrigger] estimated monolog timeout reached.")
	_call_unlock()


func _call_unlock() -> void:
	if _door_node == null:
		print("[TeacherMonologTrigger] door node not set - nothing to unlock.")
		return

	# jeśli ma metodę unlock(), wywołaj ją deferred
	if _door_node.has_method("unlock"):
		_door_node.call_deferred("unlock")
		print("[TeacherMonologTrigger] Called unlock() on door node (deferred).")
		return

	# fallback: jeśli ma AnimationPlayer child o nazwie "AnimationPlayer"
	var anim: AnimationPlayer = null
	if _door_node.has_node("AnimationPlayer"):
		anim = _door_node.get_node("AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation("open_entry_door"):
		anim.play("open_entry_door")
		print("[TeacherMonologTrigger] fallback: played open_entry_door on AnimationPlayer.")
		return

	print("[TeacherMonologTrigger] door node has no unlock() and no suitable animation - nothing done.")


func _is_node_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	if str(body.name).to_lower() == "playerbody":
		return true
	return false
