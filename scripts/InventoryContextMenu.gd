extends Panel
class_name InventoryContextMenu

signal drop_pressed

@onready var Title: Label = $VBoxContainer/Title
@onready var DropButton: Button = $VBoxContainer/DropButton

func setup(item: ItemData):
	Title.text = item.ItemName

func _ready():
	# podłącz przycisk jeśli istnieje
	if DropButton:
		DropButton.pressed.connect(func(): emit_signal("drop_pressed"))
