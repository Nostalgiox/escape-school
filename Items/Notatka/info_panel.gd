extends Panel

func _ready():
	focus_mode = Panel.FOCUS_ALL

func _gui_input(event):
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		accept_event()
