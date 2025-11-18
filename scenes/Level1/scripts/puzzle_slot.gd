extends Control
class_name PuzzleSlot

signal request_insert_item(slot_id)

@export var SlotID: int
@export var IconSlot: TextureRect

var SlotData: ItemData

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_insert_item.emit(SlotID)

func FillSlot(item: ItemData):
	SlotData = item
	if item:
		IconSlot.texture = item.Icon
	else:
		IconSlot.texture = null
