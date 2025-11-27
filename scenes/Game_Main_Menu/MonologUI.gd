extends Control
class_name MonologUI

signal monolog_finished

@onready var panel := $MonologPanel
@onready var label := $MonologPanel/MonologLabel

var lines: Array[String] = []
var current := 0
var show_speed := 0.03
var auto_time := 2.0

var _full := ""
var _shown := ""
var _timer := 0.0
var _index := 0
var _typing := false
var _waiting := false

func _ready():
	visible = false
	panel.visible = false


# ============================
#      PUBLIC FUNCTION
# ============================
func start_monolog(text_lines: Array[String], per_line_time: float = 2.0):
	if text_lines.is_empty(): return
	
	lines = text_lines
	auto_time = per_line_time
	current = 0
	
	visible = true
	panel.visible = true

	_start_line(lines[current])


# ============================
#    INTERNAL FLOW
# ============================
func _start_line(t: String):
	_full = t
	_index = 0
	_shown = ""
	_typing = true
	_waiting = false
	label.text = ""


func _process(delta: float) -> void:
	if not visible:
		return

	# TYPEWRITER PHASE
	if _typing:
		_timer += delta
		if _timer >= show_speed:
			_timer = 0.0
			if _index < _full.length():
				_shown += _full[_index]
				_index += 1
				label.text = _shown
			else:
				_typing = false
				_waiting = true
				_timer = 0.0
		return

	# WAIT PHASE
	if _waiting:
		_timer += delta
		if _timer >= auto_time:
			_next_line()


func _next_line():
	current += 1
	if current >= lines.size():
		_finish()
	else:
		_start_line(lines[current])


func _finish():
	visible = false
	panel.visible = false
	emit_signal("monolog_finished")
