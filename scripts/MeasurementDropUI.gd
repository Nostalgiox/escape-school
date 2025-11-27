# MeasurementDropUI.gd
extends Control
class_name MeasurementDropUI

signal item_dropped(slot_id)  # emituje id slotu z inventory

@onready var temp_slot : InventorySlot = $TempSlot
@onready var info_label : Label = $Panel/VBoxContainer/Label

func _ready() -> void:
	# Temp slot ma działać jako target, więc blokujemy mysz
	mouse_filter = Control.MOUSE_FILTER_STOP
	info_label.text = "Przeciągnij tutaj linijkę, aby zmierzyć plak at"

	# Podłącz sygnał OnItemDropped z InventorySlot (temp_slot)
	if temp_slot.has_signal("OnItemDropped"):
		# OnItemDropped(fromSlotID, toSlotID) -> w naszym temp_slot to 'toSlotID' nieistotny
		temp_slot.OnItemDropped.connect(Callable(self, "_on_temp_slot_dropped"))

	# Upewnij się, że slot wygląda na pusty
	temp_slot.FillSlot(null, false)
	temp_slot.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_temp_slot_dropped(from_id: int, to_id: int) -> void:
	# kiedy gracz przeciągnie z inventory (zwracane from_id)
	emit_signal("item_dropped", from_id)
