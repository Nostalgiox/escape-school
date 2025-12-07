# TimerDisplay.gd
extends Label

@export var teacher_timer_path : NodePath  # wskaż TeacherTimer
var _timer : Node = null

func _ready():
	visible = true

	if teacher_timer_path != NodePath(""):
		_timer = get_node_or_null(teacher_timer_path)

	if _timer:
		# podłączamy się do sygnału odliczania
		_timer.timer_updated.connect(_on_timer_updated)
		# i od razu zaktualizuj wyświetlanie
		_on_timer_updated(_timer._remaining_seconds())

func _on_timer_updated(seconds: int):
	text = format_time(seconds)

func format_time(seconds: int) -> String:
	var h = seconds / 3600
	var m = (seconds / 60) % 60
	var s = seconds % 60

	# Jeśli czas < 1 godziny → MM:SS
	if h == 0:
		return "%02d:%02d" % [m, s]
	else:
		return "%02d:%02d:%02d" % [h, m, s]
