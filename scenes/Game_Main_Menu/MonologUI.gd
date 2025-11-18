extends Control

signal monolog_finished

@onready var monolog_panel = $MonologPanel
@onready var monolog_label = $MonologPanel/MonologLabel

var dialog_lines : Array[String] = []
var current_line_index : int = 0
var time_per_line : float = 2.50
var is_showing : bool = false
var wait_timer: float = 0.0

#typewriter effect
var full_text : String = ""
var displayed_text : String = ""
var letter_timer : float = 0.0
var letter_interval : float = 0.05
var current_char_index : int = 0
var line_fully_displayed : bool = false

func _ready():
	start_monolog([
		"Ale tutaj jakoś dziwnie...",
		"Czuję sie nieswojo",
		"Czy któs tu był wcześniej?"
	], 2.5)

func start_monolog(lines: Array[String], duration_per_line: float = 2.5):
	is_showing = false
	dialog_lines = lines
	time_per_line = duration_per_line
	current_line_index = 0
	is_showing = true
	monolog_panel.visible = true
	_start_line(dialog_lines[current_line_index])
	
func _start_line(text : String):
	full_text = text
	displayed_text = ""
	current_char_index = 0
	letter_timer = 0.0
	line_fully_displayed = false
	monolog_label.text = ""

func _process(delta: float) -> void:
	if not is_showing:
		return
	if not line_fully_displayed:
		letter_timer += delta
		if letter_timer >= letter_interval and current_char_index < full_text.length():
			displayed_text += full_text[current_char_index]
			monolog_label.text = displayed_text
			current_char_index += 1
			letter_timer = 0.0
		if current_char_index >= full_text.length():
			line_fully_displayed = true
			wait_timer = 0.0
	else:
		wait_timer += delta
		if wait_timer >= time_per_line:
			current_line_index += 1
			if current_line_index < dialog_lines.size():
				_start_line(dialog_lines[current_line_index])
			else:
				# KONIEC DIALOGU
				is_showing = false
				monolog_panel.visible = false
				emit_signal("monolog_finished")
