# Whiteboard.gd - poprawiona wersja (typy, set_title(), fallback na kamerę z PlayerBody)
extends Node3D
class_name Whiteboard

@export var InteractionCamera: Camera3D
@export var PlayerBody: Node3D = null
@export var InteractionMaxDistance: float = 6.0

@export var LabelDepthOffset: float = 0.01
@export var LabelScale: Vector3 = Vector3.ONE * 0.08
@export var LabelColor: Color = Color(0,0,0)
@export var LabelFont: Font = null

var _labels: Array = []
var _popup_dialog: AcceptDialog = null
var _input_line: LineEdit = null

var _last_hit_position: Vector3 = Vector3.ZERO
var _last_hit_normal: Vector3 = Vector3.UP

func _ready() -> void:
	_create_input_popup()

	# jeśli nie przypisano kamery w Inspectorze, spróbuj znaleźć ją w PlayerBody
	if InteractionCamera == null and is_instance_valid(PlayerBody):
		# najpierw poszukaj node o nazwie Camera3D bezpośrednio
		var c: Node = PlayerBody.get_node_or_null("Camera3D")
		if c and c is Camera3D:
			InteractionCamera = c as Camera3D
		else:
			# znajdź rekurencyjnie pierwszą Camera3D w drzewie PlayerBody
			InteractionCamera = _find_camera_recursive(PlayerBody)

	if InteractionCamera == null:
		push_warning("Whiteboard: przypisz InteractionCamera (player camera) w Inspectorze lub podaj PlayerBody zawierający Camera3D.")
	# warn jeśli nie ma colliderów (pomoże debugować)
	if _find_first_collision_object(self) == null:
		push_warning("Whiteboard: nie znaleziono obiektów kolizyjnych w potomkach. Dodaj StaticBody3D + CollisionShape3D lub włącz generowanie kolizji przy imporcie .glb.")
	print("Whiteboard ready. InteractionCamera:", InteractionCamera, " PlayerBody:", PlayerBody)

func _create_input_popup() -> void:
	_popup_dialog = AcceptDialog.new()
	# bezpieczne ustawienie tytułu
	if _popup_dialog.has_method("set_title"):
		_popup_dialog.set_title("Napisz na tablicy")
	elif _popup_dialog.has_property("title"):
		_popup_dialog.title = "Napisz na tablicy"
	# minimal size
	_popup_dialog.rect_min_size = Vector2(360, 120)

	var vb: VBoxContainer = VBoxContainer.new()
	var l: Label = Label.new()
	l.text = "Napisz na tablicy:"
	vb.add_child(l)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Wpisz tekst..."
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_input_line)

	_popup_dialog.add_child(vb)
	_popup_dialog.connect("confirmed", Callable(self, "_on_popup_confirmed"))
	_input_line.connect("text_submitted", Callable(self, "_on_line_submitted"))

	# Dodajemy popup do root, żeby był widoczny (RootViewport ma CanvasLayer)
	var root := get_tree().root
	if root:
		root.add_child(_popup_dialog)
	else:
		get_tree().get_root().add_child(_popup_dialog)

func _input(event) -> void:
	if Input.is_action_just_pressed("interact"):
		_try_open_input_at_crosshair()

func _try_open_input_at_crosshair() -> void:
	if InteractionCamera == null:
		return
	var vp: Viewport = InteractionCamera.get_viewport()
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	var origin: Vector3 = InteractionCamera.project_ray_origin(center)
	var dir: Vector3 = InteractionCamera.project_ray_normal(center)
	var end: Vector3 = origin + dir * InteractionMaxDistance

	var space := InteractionCamera.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, end)
	var res: Dictionary = space.intersect_ray(q)
	if res.empty():
		return
	var collider: Node = res.get("collider")
	if collider == null:
		return
	# zaakceptuj trafienie tylko jeśli collider jest potomkiem tej tablicy (.glb root)
	if not _is_node_descendant_of(collider, self):
		return
	# opcjonalnie: ogranicz odległość względem PlayerBody
	if PlayerBody and is_instance_valid(PlayerBody):
		if PlayerBody.global_position.distance_to(res.get("position")) > InteractionMaxDistance:
			return

	_last_hit_position = res.get("position")
	_last_hit_normal = res.get("normal")
	_input_line.text = ""
	_popup_dialog.popup_centered()
	_input_line.grab_focus()

func _on_line_submitted(new_text: String) -> void:
	_popup_dialog.hide()
	_on_popup_confirmed()

func _on_popup_confirmed() -> void:
	var txt: String = _input_line.text.strip_edges()
	if txt == "":
		return
	_create_label_at_hit(txt)

func _create_label_at_hit(text: String) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.scale = LabelScale
	label.modulate = LabelColor
	if LabelFont:
		var theme: Theme = Theme.new()
		theme.set_font("font", "Label3D", LabelFont)
		label.theme = theme

	# umieść label jako child tej tablicy (root .glb), żeby poruszał się razem z nią
	add_child(label)

	# ustaw globalne położenie lekko nad powierzchnią
	var place_pos: Vector3 = _last_hit_position + _last_hit_normal * LabelDepthOffset
	label.global_position = place_pos

	# obróć tak, aby patrzył w stronę kamery tylko po yaw (by był czytelny)
	if InteractionCamera and is_instance_valid(InteractionCamera):
		var to_cam: Vector3 = (InteractionCamera.global_position - label.global_position).normalized()
		var yaw: float = atan2(to_cam.x, to_cam.z)
		label.global_rotation = Vector3(0.0, yaw, 0.0)

	_labels.append(label)
	print("Whiteboard: dodano label:", text, " at ", place_pos)

func clear_all_labels() -> void:
	for l in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()

func undo_last_label() -> void:
	if _labels.size() == 0:
		return
	var last: Node = _labels.pop_back()
	if is_instance_valid(last):
		last.queue_free()

# pomocnicze
func _is_node_descendant_of(node: Node, ancestor: Node) -> bool:
	var cur: Node = node
	while cur:
		if cur == ancestor:
			return true
		cur = cur.get_parent()
	return false

func _find_first_collision_object(node: Node) -> Node:
	if node is StaticBody3D or node is Area3D:
		return node
	for c in node.get_children():
		var r: Node = _find_first_collision_object(c)
		if r:
			return r
	return null

func _find_camera_recursive(node: Node) -> Camera3D:
	for c in node.get_children():
		if c is Camera3D:
			return c as Camera3D
		var r := _find_camera_recursive(c)
		if r:
			return r
	return null
