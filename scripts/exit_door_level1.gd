# entry_door.gd
extends Node3D

@export var animation_player_path: NodePath = NodePath("")
@export var area_path: NodePath = NodePath("")
@export var inventory_handler_path: NodePath = NodePath("")
@export var monolog_ui_path: NodePath = NodePath("")

@export var open_animation: String = "open_entry_door"
@export var close_animation: String = "close_entry_door"
@export var interact_action: String = "interact"
@export var auto_close_after: float = 0.0

# dźwięki — ustaw w Inspectorze (AudioStreamPlayer lub AudioStreamPlayer3D)
@export var door_open_player_path: NodePath = NodePath("")
@export var door_closed_player_path: NodePath = NodePath("")

const KEY_NAME: String = "Klucz do drzwi"

var animator: AnimationPlayer = null
var area_node: Area3D = null
var _inv_handler: Node = null
var _monolog_ui: Control = null

var door_open_player: Node = null
var door_closed_player: Node = null

var player_in_area: bool = false
var is_open: bool = false
var _is_anim_playing: bool = false
var _auto_close_timer: SceneTreeTimer = null

# cooldown dla dźwięku "zamknięte" (sekundy)
var _closed_sound_cooldown: float = 1.0
var _last_closed_sound_time: float = -10.0

# we use a delta-based timer for cooldowns
var _time_passed: float = 0.0

func _ready() -> void:
	# animator
	if animation_player_path != NodePath(""):
		animator = get_node_or_null(animation_player_path) as AnimationPlayer
	if animator == null and has_node("AnimationPlayer"):
		animator = get_node("AnimationPlayer") as AnimationPlayer
	if animator == null:
		push_warning("EntryDoor: AnimationPlayer nie znaleziony.")

	# area
	if area_path != NodePath(""):
		area_node = get_node_or_null(area_path) as Area3D
	if area_node == null:
		for c in get_children():
			if c is Area3D:
				area_node = c
				break
	if area_node == null:
		push_warning("EntryDoor: Area3D nie znaleziony.")
	else:
		area_node.monitoring = true
		area_node.monitorable = true
		if not area_node.is_connected("body_entered", Callable(self, "_on_area_body_entered")):
			area_node.connect("body_entered", Callable(self, "_on_area_body_entered"))
		if not area_node.is_connected("body_exited", Callable(self, "_on_area_body_exited")):
			area_node.connect("body_exited", Callable(self, "_on_area_body_exited"))

	# inventory handler (opcjonalnie)
	if inventory_handler_path != NodePath(""):
		_inv_handler = get_node_or_null(inventory_handler_path)

	# monolog UI (opcjonalnie)
	if monolog_ui_path != NodePath(""):
		_monolog_ui = get_node_or_null(monolog_ui_path) as Control

	# autodetekcja MonologUI (jeśli nie podano)
	if _monolog_ui == null:
		var root = get_tree().current_scene
		if root:
			var found = root.find_child("MonologUI", true, false)
			if found and found is Control:
				_monolog_ui = found

	# dźwięki — resolve paths
	if door_open_player_path != NodePath(""):
		door_open_player = get_node_or_null(door_open_player_path)
	if door_closed_player_path != NodePath(""):
		door_closed_player = get_node_or_null(door_closed_player_path)

	print("EntryDoor ready. animator=", animator, " area=", area_node, " inv_handler=", _inv_handler, " monolog_ui=", _monolog_ui, " open_sfx=", door_open_player, " closed_sfx=", door_closed_player)

	set_process(true)


func _process(delta: float) -> void:
	_time_passed += delta
	if player_in_area and Input.is_action_just_pressed(interact_action):
		_attempt_interact()


func _on_area_body_entered(body: Node) -> void:
	if _is_node_player(body):
		player_in_area = true
		print("EntryDoor: player entered area.")


func _on_area_body_exited(body: Node) -> void:
	if _is_node_player(body):
		player_in_area = false
		print("EntryDoor: player left area.")


func _attempt_interact() -> void:
	# autodetect inventory handler jeśli nie ustawiono
	if _inv_handler == null:
		_inv_handler = _find_inventory_handler()
		if _inv_handler != null:
			print("EntryDoor: autodetected InventoryHandler at:", _inv_handler.get_path())

	if _player_has_item(KEY_NAME):
		_toggle_door()
	else:
		_play_closed_sound_with_cooldown()
		var lines: Array[String] = [
			"Wydaje się, że drzwi są zamknięte.",
			"Wygląda na to, że potrzebuję klucza, żeby je otworzyć."
		]
		if _monolog_ui != null and _monolog_ui.has_method("start_monolog"):
			_monolog_ui.start_monolog(lines, 2.5)
		else:
			_show_message_accept_dialog("Drzwi zamknięte\n\nPotrzebny przedmiot: %s" % KEY_NAME)


func _toggle_door() -> void:
	if animator == null:
		push_warning("EntryDoor: brak animatora -> nie mogę odtworzyć animacji.")
		return
	if _is_anim_playing:
		return

	_is_anim_playing = true

	if is_open:
		if animator.has_animation(close_animation):
			animator.play(close_animation)
			is_open = false
			var an = animator.get_animation(close_animation)
			var len = an.length if an != null else 0.5
			var t = get_tree().create_timer(len)
			await t.timeout
		else:
			push_warning("EntryDoor: brak animacji zamykania: " + str(close_animation))
			var td = get_tree().create_timer(0.25)
			await td.timeout
	else:
		if animator.has_animation(open_animation):
			animator.play(open_animation)
			is_open = true
			_play_open_sound()
			var an2 = animator.get_animation(open_animation)
			var len2 = an2.length if an2 != null else 0.5
			var t2 = get_tree().create_timer(len2)
			await t2.timeout
			if auto_close_after > 0.0:
				_auto_close_timer = get_tree().create_timer(auto_close_after)
				if not _auto_close_timer.is_connected("timeout", Callable(self, "_on_auto_close_timeout")):
					_auto_close_timer.connect("timeout", Callable(self, "_on_auto_close_timeout"))
		else:
			push_warning("EntryDoor: brak animacji otwierania: " + str(open_animation))
			var td2 = get_tree().create_timer(0.25)
			await td2.timeout

	_is_anim_playing = false


func _on_auto_close_timeout() -> void:
	_auto_close_timer = null
	call_deferred("_close_door_deferred")


func _close_door_deferred() -> void:
	if animator and animator.has_animation(close_animation):
		animator.play(close_animation)
		door_open_player.play()
		is_open = false


func _player_has_item(item_name: String) -> bool:
	if _inv_handler == null:
		return false

	var slots = null
	if _inv_handler.has_method("get"):
		slots = _inv_handler.get("InventorySlots")

	if slots == null:
		var tmp: Array = []
		for c in _inv_handler.get_children():
			var maybe_data = null
			if c.has_method("get"):
				maybe_data = c.get("SlotData")
			if maybe_data != null:
				tmp.append(c)
				continue
			if c.has_method("FillSlot"):
				tmp.append(c)
				continue
		if tmp.size() > 0:
			slots = tmp

	if slots == null:
		return false

	for s in slots:
		if s == null:
			continue
		var slotdata = null
		if s.has_method("get"):
			slotdata = s.get("SlotData")
		if slotdata != null:
			var iname = null
			if typeof(slotdata) == TYPE_OBJECT and slotdata.has_method("get"):
				iname = slotdata.get("ItemName")
			else:
				iname = str(slotdata)
			if iname != null and str(iname) == item_name:
				return true
	return false


func _find_inventory_handler() -> Node:
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if root == null:
		return null

	if str(root.name) == "InventoryUI" or str(root.name) == "InventoryHandler":
		return root

	var stack: Array = [root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		if cur == null:
			continue

		var lname := str(cur.name)
		if lname == "InventoryUI" or lname == "InventoryHandler":
			return cur

		if cur.has_method("PickupItem") or cur.has_method("open_for_measurement"):
			return cur
		if cur.has_method("get"):
			var maybe_slots = cur.get("InventorySlots")
			if maybe_slots != null:
				return cur

		for child in cur.get_children():
			if child != null:
				stack.append(child)

	return null


func _show_message_accept_dialog(text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = text
	var cs = get_tree().current_scene
	if cs:
		cs.add_child(dlg)
	else:
		get_tree().root.add_child(dlg)
	dlg.popup_centered()
	dlg.grab_focus()


func _is_node_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	if str(body.name).to_lower() == "playerbody":
		return true
	var cls := body.get_class()
	if cls.find("CharacterBody") != -1:
		return true
	return false


# -------------------------
# DŹWIĘK: pomocniki
# -------------------------
func _play_open_sound() -> void:
	if door_open_player != null and door_open_player.has_method("play"):
		door_open_player.play()

func _play_closed_sound_with_cooldown() -> void:
	if _time_passed - _last_closed_sound_time < _closed_sound_cooldown:
		return
	_last_closed_sound_time = _time_passed
	if door_closed_player != null and door_closed_player.has_method("play"):
		door_closed_player.play()
