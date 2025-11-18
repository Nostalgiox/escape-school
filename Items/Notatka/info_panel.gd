extends Panel

@export var block_actions : Array[StringName] = [&"ui_cancel", &"inventory", &"pause", &"interact"]
@export var close_on_esc : bool = false

func _ready():
	focus_mode = Panel.FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	add_to_group("modal_ui")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event.is_pressed():
		return
	for a in block_actions:
		if event.is_action_pressed(a, false):
			if close_on_esc and a == &"ui_cancel":
				hide()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			accept_event()
			return

func _gui_input(event):
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		accept_event()
