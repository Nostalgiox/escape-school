extends Control
class_name InventorySlot

# signal OnItemEquiped(SlotID)
signal OnItemDropped(fromSlotID, toSlotID)
signal OnItemEquiped(SlotID)
signal OnItemInspect(SlotID, mouse_pos)
signal OnItemClicked(SlotID)

@export var EquippedHighlight : Panel
@export var IconSlot : TextureRect

var InventorySlotID : int = -1
var SlotFilled : bool = false

var SlotData : ItemData

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if IconSlot:
		IconSlot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if (event.button_index == MOUSE_BUTTON_RIGHT and SlotFilled):
			OnItemInspect.emit(InventorySlotID, get_viewport().get_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click and SlotFilled:
			print("Equipping item in slot: ", InventorySlotID)
			OnItemEquiped.emit(InventorySlotID)
			accept_event()
	if event is InputEventMouseButton and event.pressed and SlotFilled:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.double_click:
			OnItemClicked.emit(InventorySlotID)
			accept_event()

func FillSlot(data : ItemData, equipped : bool):
	SlotData = data
	# EquippedHighlight.visible = equipped
	# if (SlotData != null):
	# 	SlotFilled = true
	# 	IconSlot.texture = data.Icon
	# else:
	# 	SlotFilled = false
	# 	IconSlot.texture = null
	SlotFilled = SlotData != null
	if EquippedHighlight:
		EquippedHighlight.visible = equipped
	if IconSlot:
		IconSlot.texture = SlotData.Icon if SlotData else null
		IconSlot.tooltip_text = (SlotData.ShortDescription if (SlotData and SlotData.ShortDescription != "") else "")
	

func _get_drag_data(at_position: Vector2) -> Variant:
	if (SlotFilled):
		var preview : TextureRect = TextureRect.new()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = IconSlot.size
		preview.pivot_offset = IconSlot.size / 2.0
		preview.rotation = 2.0
		preview.texture = IconSlot.texture
		set_drag_preview(preview)
		return {"Type": "Item", "ID": InventorySlotID}
	else:
		return false

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data["Type"] == "Item"
	

func _drop_data(at_position: Vector2, data: Variant) -> void:
	OnItemDropped.emit(data["ID"], InventorySlotID)
