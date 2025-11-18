extends Area3D

@export var monolog_ui: Control         # przeciągnij tu swój MonologUI
@export var door_path: NodePath        # przeciągnij tu node drzwi (ten, który ma unlock())
@export var door_delay: float = 0.20   # opcjonalne opóźnienie po monologu (s)

var has_been_triggered: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	var cb := Callable(self, "_on_body_entered")
	if not is_connected("body_entered", cb):
		connect("body_entered", cb)
	print("Trigger ready. monolog_ui:", monolog_ui, " door_path:", door_path)

func _on_body_entered(body: Node) -> void:
	if has_been_triggered:
		return
	if not (body and body.is_in_group("player")):
		return

	if monolog_ui == null:
		push_warning("Trigger: monolog_ui not set in Inspector!")
		return

	# start monolog and connect to finished signal
	monolog_ui.start_monolog(get_monolog_lines(), get_monolog_duration())
	var cb := Callable(self, "_on_monolog_finished")
	if not monolog_ui.is_connected("monolog_finished", cb):
		monolog_ui.connect("monolog_finished", cb)
	has_been_triggered = true
	print("Trigger: monolog started and waiting for finish...")

# optionally extractable, replace with your lines/duration if you keep them elsewhere
func get_monolog_lines() -> Array[String]:
	return [
		"Zanim zaczniemy… pewnie zastanawiasz się, dlaczego tu jesteś.",
		"To proste. Znowu przeszkadzałeś na lekcji.",
		"Znowu nie uważałeś, nie słuchałeś, nie robiłeś notatek.",
		"Każdy inny uczeń już dawno wyszedł do domu.",
		"Ale ty… ty zostałeś.",
		"Koza nie jest karą. To… szansa.",
		"Szansa, żeby wreszcie nadrobić to, czego nie potrafisz zapamiętać.",
		"Może tym razem coś do ciebie dotrze.",
		"A jeśli nie… mam mnóstwo czasu.",
		"Tak, dobrze słyszysz.",
		"Nikt nie będzie nam przeszkadzał.",
		"Tylko ty… i ja.",
		"Zacznijmy więc od początku."
	]

func get_monolog_duration() -> float:
	return 2.5


func _on_monolog_finished() -> void:
	print("Trigger: monolog_finished received.")
	# optional delay
	if door_delay > 0.0:
		var t = get_tree().create_timer(door_delay)
		await t.timeout

	# find door node
	var door_node: Node = null
	if door_path != NodePath(""):
		door_node = get_node_or_null(door_path)
	# fallback: search by name "Door" in current scene if not provided
	if door_node == null:
		var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		door_node = root.find_node("Door", true, false)

	if door_node == null:
		push_warning("Trigger: Door node not found. Check door_path or name 'Door' in scene.")
		return

	print("Trigger: found door node:", door_node.get_path(), " class:", door_node.get_class())

	# make sure it has unlock()
	if door_node.has_method("unlock"):
		# call deferred to be safe re: renderer
		door_node.call_deferred("unlock")
		print("Trigger: called deferred unlock() on door.")
	else:
		push_warning("Trigger: found node but it has no method unlock(): " + str(door_node.get_path()))
