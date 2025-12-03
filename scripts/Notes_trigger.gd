# Notes_trigger.gd - tylko 'interact' (np. E) otwiera notatkę — LPM IGNOROWANE
extends Area3D

@export var notatka_node_path : NodePath = NodePath("") # ustaw w Inspectorze (np. ../Notes)
var player_inside : bool = false
var notatka_node : Node = null
var _left_mouse_was_pressed : bool = false

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

	# pobierz node Notes (priorytet: ścieżka z Inspector)
	if notatka_node_path != NodePath(""):
		notatka_node = get_node_or_null(notatka_node_path)
		if not notatka_node:
			push_warning("Notes_trigger: nie znalazłem node'a pod notatka_node_path: %s" % str(notatka_node_path))

	if not notatka_node:
		# fallback: znajdź node o nazwie "Notes" rekurencyjnie
		notatka_node = _find_node_recursive(get_tree().get_root(), "Notes")
	if notatka_node:
		print("Notes_trigger: powiązano z node'em:", notatka_node.get_path())
	else:
		push_warning("Notes_trigger: NIE znaleziono node'a 'Notes'. Ustaw notatka_node_path w Inspectorze.")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		# reset myszy by edge detection (jeśli gdzieś indziej używany)
		_left_mouse_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		# print("Notes_trigger: player entered")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		_left_mouse_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		# print("Notes_trigger: player exited")

# prosty rekurencyjny finder (jeśli find_node nie daje oczekiwanych rezultatów)
func _find_node_recursive(root: Node, name_to_find: String) -> Node:
	if not root:
		return null
	if root.name == name_to_find:
		return root
	for c in root.get_children():
		var nodec := c as Node
		if not nodec:
			continue
		var f := _find_node_recursive(nodec, name_to_find)
		if f:
			return f
	return null

# Sprawdza, czy notatka (InfoPanel) jest obecnie otwarta/visible.
func _is_notes_panel_open() -> bool:
	if not notatka_node:
		# fallback globalny
		var root := get_tree().get_root()
		var global_p: Node = root.find_node("InfoPanel", true, false) as Node
		if global_p and "visible" in global_p:
			return bool(global_p.visible)
		return false

	# 1) property 'info_panel' (jeśli skrypt notatki expose'uje takie pole)
	if "info_panel" in notatka_node:
		var p := notatka_node.get("info_panel") as Node
		if p and "visible" in p:
			return bool(p.visible)

	# 2) dziecko o nazwie InfoPanel bezpośrednio pod notatka_node
	var child: Node = notatka_node.get_node_or_null("InfoPanel") as Node
	if child and "visible" in child:
		return bool(child.visible)

	# 3) fallback globalny
	var root2 := get_tree().get_root()
	var global2: Node = root2.find_node("InfoPanel", true, false) as Node
	if global2 and "visible" in global2:
		return bool(global2.visible)

	return false

func _process(delta: float) -> void:
	# aktualizuj stan tylko gdy gracz w polu
	if not player_inside:
		_left_mouse_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return

	# Jeśli panel notatki jest otwarty, ignorujemy interakcje
	if _is_notes_panel_open():
		_left_mouse_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return

	# REAGUJEMY TYLKO NA 'interact' (np. E). LPM IGNOROWANE.
	if Input.is_action_just_pressed("interact"):
		_interact()
		return

	# --- UWAGA: fragment LPM został świadomie usunięty ---
	# (jeśli będziesz chciał przywrócić LPM, dodaj mechanikę edge-detection tutaj)

func _interact() -> void:
	if not notatka_node:
		push_error("Notes_trigger: brak referencji do notatki. Ustaw notatka_node_path lub nazwy node'ów poprawnie.")
		return

	# dodatkowe bezpieczeństwo: jeśli panel został otwarty w międzyczasie — przerwij
	if _is_notes_panel_open():
		return

	if notatka_node.has_method("show_panel"):
		notatka_node.call("show_panel", true)
	else:
		push_error("Notes_trigger: node Notes nie ma metody show_panel().")
