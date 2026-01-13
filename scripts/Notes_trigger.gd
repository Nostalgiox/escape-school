# Notes_trigger.gd - tylko 'interact' (E) otwiera notatkę — LPM IGNOROWANE
extends Area3D

@export var notes_path: NodePath = NodePath("")  # ustaw w Inspectorze ścieżkę do Node Notes (np. ../Notes)
var notes: Node = null
var player_inside: bool = false
var _interact_prev_pressed: bool = false

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_enter"))
	connect("body_exited", Callable(self, "_on_exit"))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	notes = get_node_or_null(notes_path)
	# ustaw stan początkowy edge-detection
	_interact_prev_pressed = Input.is_action_pressed("interact")

	# jeśli chcesz debugować:
	# print("Notes_trigger ready, notes:", notes)

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _process(_delta: float) -> void:
	var cur := Input.is_action_pressed("interact")
	# reaguj tylko na przejście z false -> true i tylko jeśli gracz w obszarze
	if cur and not _interact_prev_pressed and player_inside:
		if notes and notes.has_method("show_panel"):
			notes.call("show_panel")
			# oznacz event jako obsłużony (zapobiega powtórnemu dotarciu)
			var vp := get_viewport()
			if vp and vp.has_method("set_input_as_handled"):
				vp.set_input_as_handled()
	_interact_prev_pressed = cur

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("enter_interaction_area"):
			body.enter_interaction_area(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("exit_interaction_area"):
			body.exit_interaction_area(self)
