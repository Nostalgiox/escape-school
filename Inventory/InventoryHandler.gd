extends Node
class_name InventoryHandler

signal MeasurementItemDropped(from_slot_id, item_data) # emitted when player chooses item for measurement

@export var PlayerBody: CharacterBody3D
@export_flags_3d_physics var CollisionMask: int

@export var ItemSlotsCount: int = 63

@export var InventoryGrid: GridContainer
@export var InventorySlotPrefab: PackedScene = preload("res://Inventory/InventorySlot.tscn")

# Panel z detalami (nieużywany w tej wersji, ale zostawiam)
@export var DetailsRoot: Control

# Prawa kolumna – podgląd i opis (przypnij w Inspectorze do RightPane kontrolki w inventory)
@export var PreviewContainer: SubViewportContainer
@export var PreviewViewport: SubViewport
@export var PreviewRoot: Node3D
@export var PreviewCamera: Camera3D
@export var PreviewTitle: Label
@export var PreviewDesc: RichTextLabel
@export var PreviewTurntableSpeed: float = 15.0

# Prefab (opcjonalny) mały UI do dropowania w trybie measurement (możesz zostawić null)
@export var MeasurementDropUIPrefab: PackedScene
@export var RightPane: Control
@onready var InventoryRoot: Control = $"." 
var _measurement_ui: Control = null
var _right_pane_saved_visible: bool = true

# ---------------------
# DŹWIĘK (Opcja A - przypnij AudioStreamPlayer/AudioStreamPlayer3D w Inspectorze)
# ---------------------
# możesz przypiąć tu plik audio (ogg/wav) w Inspectorze
@export var PickupSound: AudioStream
# Głośność w decybelach (0 = domyślna), możesz ustawić np. -6.0
@export var PickupSoundVolumeDb: float = 0.0
# Ścieżka do AudioStreamPlayer / AudioStreamPlayer3D w scenie (przypnij node, np. Player/pickup)
@export var PickupAudioPlayerNode: NodePath = NodePath("")

# Referencja runtime (może być AudioStreamPlayer lub AudioStreamPlayer3D)
var _fixed_audio_player: Node = null

# Stan
var InventorySlots: Array[InventorySlot] = []
var _openDetails: Control = null
var EquippedSlot: int = -1

var _preview_pivot: Node3D = null
var _preview_instance: Node3D = null

func _ready() -> void:
	# Walidacja referencji
	if InventoryGrid == null:
		push_error("InventoryGrid = null (przypnij w Inspectorze: LeftPane/.../InventoryGrid).")
		return
	if InventorySlotPrefab == null:
		push_error("InventorySlotPrefab = null (przypnij InventorySlot.tscn).")
		return

	_build_slots()
	call_deferred("_fix_layout_flags")

	# Detale – domyślnie ukryte
	if is_instance_valid(DetailsRoot):
		DetailsRoot.visible = false
		DetailsRoot.mouse_filter = Control.MOUSE_FILTER_STOP

	# Pivot do obracania podglądu 3D
	if is_instance_valid(PreviewRoot):
		_preview_pivot = Node3D.new()
		PreviewRoot.add_child(_preview_pivot)

	# Jeśli użytkownik przypiął AudioStreamPlayer w Inspectorze — pobierz go
	if PickupAudioPlayerNode != NodePath(""):
		var node = get_node_or_null(PickupAudioPlayerNode)
		if node and (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
			_fixed_audio_player = node
			print("InventoryHandler: znaleziono audio player przez NodePath:", PickupAudioPlayerNode)
		else:
			push_warning("PickupAudioPlayerNode nie wskazuje poprawnego AudioStreamPlayer. Może Player jest instancjonowany dynamicznie lub ścieżka jest niepoprawna.")

	# Jeśli nie znaleziono jeszcze - spróbuj znaleźć audio jako child PlayerBody (runtime)
	if _fixed_audio_player == null and is_instance_valid(PlayerBody):
		# 1) bezpośredni child o nazwie "pickup"
		var candidate := PlayerBody.get_node_or_null("pickup")
		if candidate and (candidate is AudioStreamPlayer or candidate is AudioStreamPlayer3D):
			_fixed_audio_player = candidate
			print("InventoryHandler: znaleziono audio player jako direct child 'pickup' w PlayerBody.")
		else:
			# 2) find_node po nazwie 'pickup' w drzewie PlayerBody
			candidate = PlayerBody.find_node("pickup", true, false)
			if candidate and (candidate is AudioStreamPlayer or candidate is AudioStreamPlayer3D):
				_fixed_audio_player = candidate
				print("InventoryHandler: znaleziono audio player przez find_node('pickup') w PlayerBody.")
			else:
				# 3) fallback: znajdź pierwszy AudioStreamPlayer / AudioStreamPlayer3D rekurencyjnie
				for child in PlayerBody.get_children():
					var found := _find_audio_recursive(child)
					if found:
						_fixed_audio_player = found
						print("InventoryHandler: znaleziono pierwszy AudioStreamPlayer w drzewie PlayerBody:", found)
						break

	# Debug
	if _fixed_audio_player == null:
		push_warning("InventoryHandler: nie znaleziono AudioStreamPlayer dla pickup. Upewnij się, że node 'pickup' istnieje w PlayerBody lub ustaw PickupAudioPlayerNode w Inspectorze.")
	else:
		print("InventoryHandler ready. Audio player:", _fixed_audio_player.get_path())

	# Debug info ogólne
	print("InventoryHandler ready. Slots:", ItemSlotsCount, " RightPane:", RightPane != null, " MeasurementPrefab:", MeasurementDropUIPrefab != null)

func _fix_layout_flags() -> void:
	if InventoryGrid:
		if InventoryGrid.columns <= 0:
			InventoryGrid.columns = 9
		InventoryGrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		InventoryGrid.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _process(delta: float) -> void:
	if is_instance_valid(_preview_pivot) and PreviewTurntableSpeed != 0.0:
		_preview_pivot.rotate_y(deg_to_rad(PreviewTurntableSpeed * delta))

# ---------------------
# Sloty i ekwipunek
# ---------------------
func _build_slots() -> void:
	InventorySlots.clear()

	for i in range(ItemSlotsCount):
		var node := InventorySlotPrefab.instantiate()
		if node == null:
			push_error("Nie mogę zinstancjonować InventorySlotPrefab.")
			continue

		var slot := node as InventorySlot
		if slot == null:
			push_error("Prefab '%s' nie ma skryptu class_name InventorySlot podpiętego do root (obecnie: %s)." % [InventorySlotPrefab.resource_path, str(node)])
			InventoryGrid.add_child(node)
			continue

		InventoryGrid.add_child(slot)
		slot.InventorySlotID = i

		# Podłącz sygnały defensywnie
		if slot.has_signal("OnItemDropped"):
			slot.OnItemDropped.connect(Callable(self, "ItemDroppedOnSlot"))
		if slot.has_signal("OnItemEquiped"):
			slot.OnItemEquiped.connect(Callable(self, "ItemEquipped"))
		if slot.has_signal("OnItemInspect"):
			slot.OnItemInspect.connect(Callable(self, "ItemInspected"))
		if slot.has_signal("OnItemClicked"):
			slot.OnItemClicked.connect(Callable(self, "ItemClicked"))

		InventorySlots.append(slot)

	print("Grid children after:", InventoryGrid.get_child_count())

# pomocnicza funkcja rekurencyjna do odnalezienia AudioStreamPlayer(3D)
func _find_audio_recursive(node: Node) -> Node:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		return node
	for c in node.get_children():
		var r = _find_audio_recursive(c)
		if r:
			return r
	return null

# Funkcja odtwarzająca dźwięk pickup (używa przypisanego AudioStreamPlayer lub AudioStreamPlayer3D)
func _play_pickup_sound_at(pos: Vector3) -> void:
	# jeśli mamy stały przypisany player (najczęstszy przypadek)
	if _fixed_audio_player:
		# AudioStreamPlayer (2D) - pozycja ignorowana
		if _fixed_audio_player is AudioStreamPlayer:
			var p2 := _fixed_audio_player as AudioStreamPlayer
			if PickupSound:
				p2.stream = PickupSound
			p2.volume_db = PickupSoundVolumeDb
			p2.play()
			return
		# AudioStreamPlayer3D - ustaw pozycję i stream
		if _fixed_audio_player is AudioStreamPlayer3D:
			var p3 := _fixed_audio_player as AudioStreamPlayer3D
			if PickupSound:
				p3.stream = PickupSound
			p3.volume_db = PickupSoundVolumeDb
			# ustaw globalną pozycję odtwarzacza aby dźwięk był słyszalny w 3D
			var gt := p3.global_transform
			gt.origin = pos
			p3.global_transform = gt
			p3.play()
			return
		# inny typ - warn
		push_warning("Podpięty pickup player nie jest AudioStreamPlayer ani AudioStreamPlayer3D.")
		return

	# jeśli nie mamy przypisanego playera, spróbuj stworzyć tymczasowy (3D) - fallback
	if PickupSound == null:
		# nic do odtworzenia
		return
	var ap := AudioStreamPlayer3D.new()
	ap.stream = PickupSound
	ap.volume_db = PickupSoundVolumeDb
	ap.global_transform = Transform3D(Basis.IDENTITY, pos)
	add_child(ap)
	ap.play()
	# posprzątaj po skończeniu
	if ap.has_signal("finished"):
		ap.connect("finished", Callable(ap, "queue_free"))
	else:
		var t := Timer.new()
		t.one_shot = true
		var wait_time := 1.0
		if PickupSound.has_method("get_length"):
			wait_time = float(PickupSound.get_length())
		t.wait_time = max(0.1, wait_time)
		ap.add_child(t)
		t.start()
		t.timeout.connect(Callable(ap, "queue_free"))

func PickupItem(item: ItemData) -> void:
	for slot in InventorySlots:
		if slot and not slot.SlotFilled:
			slot.FillSlot(item, false)

			# zagraj dźwięk blisko gracza - używamy pozycji PlayerBody jako miejsce źródła
			var pos := Vector3.ZERO
			if is_instance_valid(PlayerBody):
				# CharacterBody3D ma global_position
				pos = PlayerBody.global_position
			_play_pickup_sound_at(pos)

			return

	var newItem := item.ItemModelPrefab.instantiate() as Node3D
	# upewnijmy się, że PlayerBody jest valid przed użyciem
	if is_instance_valid(PlayerBody) and PlayerBody.get_parent():
		PlayerBody.get_parent().add_child(newItem)
		newItem.global_position = PlayerBody.global_position + PlayerBody.global_transform.basis.x * 2.0
	else:
		# fallback: dodajemy jako child InventoryHandler (nie idealne ale bezpieczne)
		add_child(newItem)
		newItem.position = Vector3.ZERO

	# zagraj dźwięk w miejscu spawn przedmiotu
	if is_instance_valid(newItem):
		_play_pickup_sound_at(newItem.global_position)

func ItemEquipped(slotID: int) -> void:
	if EquippedSlot != -1:
		InventorySlots[EquippedSlot].FillSlot(InventorySlots[EquippedSlot].SlotData, false)

	if slotID != EquippedSlot and InventorySlots[slotID].SlotData != null:
		InventorySlots[slotID].FillSlot(InventorySlots[slotID].SlotData, true)
		EquippedSlot = slotID
	else:
		EquippedSlot = -1

func ItemDroppedOnSlot(fromSlotID: int, toSlotID: int) -> void:
	if EquippedSlot != -1:
		if EquippedSlot == fromSlotID:
			EquippedSlot = toSlotID
		elif EquippedSlot == toSlotID:
			EquippedSlot = fromSlotID

	var toSlotItem = InventorySlots[toSlotID].SlotData
	var fromSlotItem = InventorySlots[fromSlotID].SlotData

	InventorySlots[toSlotID].FillSlot(fromSlotItem, EquippedSlot == toSlotID)
	InventorySlots[fromSlotID].FillSlot(toSlotItem, EquippedSlot == fromSlotID)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data["Type"] == "Item"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# drop to world (stara logika)
	if EquippedSlot == data["ID"]:
		EquippedSlot = -1

	var newItem = InventorySlots[data["ID"]].SlotData.ItemModelPrefab.instantiate() as Node3D
	InventorySlots[data["ID"]].FillSlot(null, false)
	if is_instance_valid(PlayerBody) and PlayerBody.get_parent():
		PlayerBody.get_parent().add_child(newItem)
	else:
		add_child(newItem)
	newItem.global_position = GetWorldMousePosition()

func GetWorldMousePosition() -> Vector3:
	var mousePos = get_viewport().get_mouse_position()
	var cam = get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(PlayerBody):
		# fallback: zwróć (0,0,0) jeżeli nie mamy kamery lub PlayerBody
		return Vector3.ZERO
	var ray_start = cam.project_ray_origin(mousePos)
	var ray_end = ray_start + cam.project_ray_normal(mousePos) * cam.global_position.distance_to(PlayerBody.global_position) * 2.0
	var world3d: World3D = PlayerBody.get_world_3d()
	var space_state = world3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, CollisionMask)
	var results = space_state.intersect_ray(query)
	if results:
		return results["position"] as Vector3 + Vector3(0.0, 0.5, 0.0)
	return ray_start.lerp(ray_end, 0.5) + Vector3(0.0, 0.5, 0.0)

# ---------------------
# Detale (PPM “inspekt”)
# ---------------------
func ItemInspected(slotID: int, mouse_pos: Vector2) -> void:
	# default: drop item on inspect
	print("PPM inspect -> dropping item from slot:", slotID)
	_drop_item_from_slot(slotID)

func _drop_item_from_slot(slotID: int) -> void:
	if slotID < 0 or slotID >= InventorySlots.size():
		return
	var slot := InventorySlots[slotID]
	if slot == null:
		return
	if slot.SlotData == null:
		return

	var drop_item := slot.SlotData.ItemModelPrefab.instantiate() as Node3D
	if is_instance_valid(PlayerBody) and PlayerBody.get_parent():
		PlayerBody.get_parent().add_child(drop_item)
		drop_item.global_position = PlayerBody.global_position + Vector3(0, 1.5, 0)
	else:
		add_child(drop_item)
		drop_item.global_position = Vector3.ZERO

	# odpowiednio: możesz chcieć odtworzyć inny dźwięk przy rzuceniu — tutaj nie robimy nic
	slot.FillSlot(null, false)

# ---------------------
# Details / preview
# ---------------------
func _show_item_details(item: ItemData) -> void:
	if not DetailsRoot:
		push_warning("DetailsRoot is not assigned!")
		return
	if _openDetails:
		_openDetails.queue_free()
		_openDetails = null

	var p := Panel.new()
	p.custom_minimum_size = Vector2(500, 300)
	p.focus_mode = Control.FOCUS_ALL

	var vb := VBoxContainer.new()
	vb.anchor_right = 1.0; vb.anchor_bottom = 1.0
	vb.offset_left = 16; vb.offset_top = 16; vb.offset_right = -16; vb.offset_bottom = -16

	var title := Label.new(); title.text = item.ItemName

	var text := RichTextLabel.new()
	text.fit_content = true
	text.bbcode_enabled = true
	text.bbcode_text = item.DetailsText

	var btn := Button.new(); btn.text = "Zamknij"
	btn.pressed.connect(_on_details_closed)

	vb.add_child(title); vb.add_child(text); vb.add_child(btn)
	p.add_child(vb)
	DetailsRoot.add_child(p)
	_openDetails = p
	DetailsRoot.visible = true
	p.grab_focus()

func _on_details_closed() -> void:
	if _openDetails:
		_openDetails.queue_free()
		_openDetails = null
	if DetailsRoot:
		DetailsRoot.visible = false

func IsDetailsOpen() -> bool:
	return DetailsRoot != null and DetailsRoot.visible

# ---------------------
# Preview (LPM click)
# ---------------------
func ItemClicked(slotID: int) -> void:
	var data := InventorySlots[slotID].SlotData
	if data == null:
		_clear_preview()
		return
	_show_preview_for_item(data)

func _clear_preview() -> void:
	if is_instance_valid(_preview_instance):
		_preview_instance.queue_free()
		_preview_instance = null
	if PreviewTitle:
		PreviewTitle.text = ""
	if PreviewDesc:
		PreviewDesc.text = ""

func _show_preview_for_item(item: ItemData) -> void:
	_clear_preview()
	if PreviewTitle:
		PreviewTitle.text = item.ItemName

	if PreviewDesc:
		var txt := item.DetailsText if item.DetailsText != null and item.DetailsText != "" else "[i]Brak opisu[/i]"
		print("DEBUG: setting PreviewDesc text length:", txt.length())
		PreviewDesc.bbcode_enabled = true
		PreviewDesc.bbcode_text = txt
		PreviewDesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PreviewDesc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		PreviewDesc.custom_minimum_size = Vector2(200, 80)
		PreviewDesc.visible = true
		if PreviewDesc.has_method("scroll_to_line"):
			PreviewDesc.scroll_to_line(0)

	call_deferred("_finalize_show_preview_deferred", item)

func _finalize_show_preview_deferred(item: ItemData) -> void:
	if not item:
		return
	if item.ItemModelPrefab == null or not is_instance_valid(PreviewRoot):
		return

	_preview_instance = item.ItemModelPrefab.instantiate() as Node3D
	if _preview_instance == null:
		return

	if _preview_pivot == null:
		_preview_pivot = Node3D.new()
		PreviewRoot.add_child(_preview_pivot)

	_preview_pivot.transform = Transform3D()
	_preview_instance.transform = Transform3D()
	_preview_pivot.add_child(_preview_instance)

	var aabb := _find_first_aabb(_preview_instance)
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim <= 0.0001:
		max_dim = 1.0
	var target_size := 0.8
	var scale := target_size / max_dim
	_preview_instance.scale = Vector3.ONE * scale

	if PreviewCamera:
		PreviewCamera.transform = Transform3D.IDENTITY
		PreviewCamera.position = Vector3(0, 0.15, 2.0)
		PreviewCamera.look_at(Vector3.ZERO, Vector3.UP)

func _find_first_aabb(node: Node) -> AABB:
	var stack: Array[Node] = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var a: AABB = (n as MeshInstance3D).get_aabb()
			if a.size.length() > 0.0:
				return a
		for c in n.get_children():
			stack.push_back(c)
	return AABB(Vector3.ZERO, Vector3.ONE)

# ---------------------
# Measurement mode API
# ---------------------
func open_for_measurement() -> void:
	# pokaż inventory jeżeli mamy referencję do root UI
	if InventoryRoot:
		# w niektórych przypadkach InventoryRoot może być niewidoczny (np. ukrywasz cały UI)
		InventoryRoot.visible = true
	else:
		# fallback: tylko debug jeśli nie ustawione
		push_warning("InventoryHandler.open_for_measurement: InventoryRoot nie przypisany w Inspectorze.")

	# ukryj prawą kolumnę i zapamiętaj stan
	if RightPane:
		_right_pane_saved_visible = RightPane.visible
		RightPane.visible = false

	# upewnij się, że mysz jest widoczna (gracz będzie przeciągać przedmioty)
	# używamy Input.set_mouse_mode aby był kompatybilny z Godot4
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# stwórz measurement UI jeśli masz prefab - opcjonalne
	if MeasurementDropUIPrefab and _measurement_ui == null:
		_measurement_ui = MeasurementDropUIPrefab.instantiate() as Control
		if _measurement_ui == null:
			push_warning("InventoryHandler: nie udało się zinstancjonować MeasurementDropUIPrefab.")
			return

		_measurement_ui.name = "TMP_MeasurementDropUI"
		# dodajemy jako child InventoryHandler (możesz trzymać w InventoryRoot jeśli wolisz)
		add_child(_measurement_ui)

		# podłącz sygnał skierowany do InventoryHandler
		if _measurement_ui.has_signal("item_dropped"):
			# upewnij się że nie łączysz wielokrotnie
			if not _measurement_ui.is_connected("item_dropped", Callable(self, "_on_measurement_item_dropped")):
				_measurement_ui.connect("item_dropped", Callable(self, "_on_measurement_item_dropped"))
		# measurement UI może potrzebować referencji do tego handlera - ustaw jeśli ma property/metodę
		if _measurement_ui.has_method("set_inventory_handler"):
			_measurement_ui.call("set_inventory_handler", self)


func close_measurement_mode() -> void:
	# usuń measurement UI
	if _measurement_ui and is_instance_valid(_measurement_ui):
		# odłącz sygnały defensywnie
		if _measurement_ui.has_signal("item_dropped") and _measurement_ui.is_connected("item_dropped", Callable(self, "_on_measurement_item_dropped")):
			_measurement_ui.disconnect("item_dropped", Callable(self, "_on_measurement_item_dropped"))
		_measurement_ui.queue_free()
		_measurement_ui = null

	# przywróć right pane
	if RightPane:
		RightPane.visible = _right_pane_saved_visible

	# przywróć tryb myszy do capture (jeśli chcesz)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_measurement_item_dropped(from_slot_id: int) -> void:
	print("[InventoryHandler] Measurement drop received from slot:", from_slot_id)

	# pobierz przedmiot
	if from_slot_id < 0 or from_slot_id >= InventorySlots.size():
		push_warning("Invalid slot id")
		return

	var item_data = InventorySlots[from_slot_id].SlotData
	if item_data == null:
		push_warning("Slot empty")
		return

	# usuń item ze slotu
	InventorySlots[from_slot_id].FillSlot(null, false)

	# wyemituj sygnał dalej, PosterMeasure to odbierze
	emit_signal("MeasurementItemDropped", from_slot_id, item_data)

	# zamknij tryb measurement
	close_measurement_mode()
