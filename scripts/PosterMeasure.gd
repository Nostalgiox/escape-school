extends Node3D

@export var required_item_name: String = "Linijka 30 cm"
@export var inventory_handler_path: NodePath = NodePath("")
@export var monolog_ui_path: NodePath = NodePath("")
@export var area_path: NodePath = NodePath("")
@export var ruler_node_path: NodePath = NodePath("")
@export var interact_action: String = "interact"

var _inv_handler: Node = null
var _monolog_ui: Node = null
var _area: Area3D = null
var _ruler_node: Node3D = null
var player_in_area: bool = false

# --------------------------------------------------
# READY
# --------------------------------------------------
func _ready() -> void:
	if inventory_handler_path != NodePath(""):
		_inv_handler = get_node_or_null(inventory_handler_path)
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path)
	if area_path != NodePath(""):
		_area = get_node_or_null(area_path) as Area3D
	if ruler_node_path != NodePath(""):
		_ruler_node = get_node_or_null(ruler_node_path) as Node3D

	if _ruler_node == null:
		_ruler_node = find_child("Ruler_on_poster", true, false) as Node3D

	if _ruler_node:
		_ruler_node.visible = false

	if _area:
		_area.monitoring = true
		_area.monitorable = true
		var cb_in := Callable(self, "_on_area_body_entered")
		var cb_out := Callable(self, "_on_area_body_exited")
		if not _area.is_connected("body_entered", cb_in):
			_area.connect("body_entered", cb_in)
		if not _area.is_connected("body_exited", cb_out):
			_area.connect("body_exited", cb_out)

# --------------------------------------------------
# AREA ENTER / EXIT
# --------------------------------------------------
func _on_area_body_entered(body: Node) -> void:
	if body and (body.is_in_group("player") or str(body.name).to_lower() == "playerbody"):
		player_in_area = true

func _on_area_body_exited(body: Node) -> void:
	if body and (body.is_in_group("player") or str(body.name).to_lower() == "playerbody"):
		player_in_area = false

# --------------------------------------------------
# INPUT
# --------------------------------------------------
func _input(event: InputEvent) -> void:
	if not player_in_area:
		return
	if event.is_action_pressed(interact_action):
		_on_interact()

func _input_event(camera, event, click_position, click_normal, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _area and not player_in_area:
			_show_monolog(["Jesteś za daleko."])
			return
		_on_interact()

# --------------------------------------------------
# INTERACT LOGIC
# --------------------------------------------------
func _on_interact() -> void:
	if _inv_handler == null:
		var root = get_tree().current_scene if get_tree().current_scene else get_tree().root
		if root:
			var f = root.find_child("InventoryUI", true, false)
			if f:
				_inv_handler = f

	if _inv_handler and _player_has_required_item():
		_on_player_has_ruler()
	else:
		_on_player_missing_ruler()

# --------------------------------------------------
# CHECK INVENTORY
# --------------------------------------------------
func _player_has_required_item() -> bool:
	if _inv_handler == null:
		return false

	var slots = _inv_handler.get("InventorySlots")
	if typeof(slots) != TYPE_ARRAY:
		return false

	for s in slots:
		if s and s.SlotData and str(s.SlotData.ItemName) == required_item_name:
			return true

	return false

# --------------------------------------------------
# RULER ACTIONS
# --------------------------------------------------
func _on_player_has_ruler() -> void:
	if _ruler_node:
		_ruler_node.visible = true
		$Label3D.visible = true
	_show_monolog([
		"Linijka pasuje idealnie do okręgu.",
		"Średnica wynosi 6 cm — zapamiętaj to."
	])

func _on_player_missing_ruler() -> void:
	_show_monolog([
		"Czuję, że czegoś tu brakuje...",
		"Potrzebuję linijki."
	])

# --------------------------------------------------
# MONOLOG
# --------------------------------------------------
func _show_monolog(lines: Array[String]) -> void:
	if _monolog_ui and _monolog_ui.has_method("start_monolog"):
		_monolog_ui.start_monolog(lines, 2.5)
		return

	var dlg := AcceptDialog.new()
	var text := ""
	for i in range(lines.size()):
		text += str(lines[i])
		if i < lines.size() - 1:
			text += "\n\n"
	dlg.dialog_text = text

	var cs = get_tree().current_scene
	if cs:
		cs.add_child(dlg)
	else:
		get_tree().root.add_child(dlg)

	dlg.popup_centered(Vector2(420, 200))
	dlg.grab_focus()
