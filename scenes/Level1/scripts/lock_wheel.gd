# LockWheel.gd
class_name LockWheel
extends VBoxContainer

@export var index: int = 0
@export var start_value: int = 0

signal value_changed(index: int, value: int)

var value: int = 0

@onready var btn_up: Button = $Button
@onready var btn_down: Button = $Button2
@onready var lbl_value: Label = $Label

func _ready() -> void:
	value = start_value % 10
	_refresh()
	btn_up.pressed.connect(_inc)
	btn_down.pressed.connect(_dec)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_inc()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dec()

func _inc() -> void:
	value = (value + 1) % 10
	_refresh()
	value_changed.emit(index, value)

func _dec() -> void:
	value = (value + 9) % 10
	_refresh()
	value_changed.emit(index, value)

func _refresh() -> void:
	lbl_value.text = str(value)
