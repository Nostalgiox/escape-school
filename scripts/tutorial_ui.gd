extends CanvasLayer

@onready var panel = $Panel
var tutorial_active := true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = true
	get_tree().paused = true
	set_process_input(true)

func _input(event):
	if not tutorial_active:
		return

	if event.is_action_pressed("ui_cancel"):
		panel.visible = false
		get_tree().paused = false
		tutorial_active = false

		get_viewport().set_input_as_handled()
