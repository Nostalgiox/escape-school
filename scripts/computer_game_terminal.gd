extends Control

@export var next_scene: PackedScene

@onready var input_field = $VBoxContainer/LineEdit
@onready var fade_overlay = $Blackground
@onready var label = $VBoxContainer/Label
@onready var global_numbers = Global.global_numbers

var step = 0

func _ready():
	input_field.grab_focus()
	label.text = "Zadanie polega na tym:
	\n1.Zadeklaruj pustą tablice liczby tak jak to się robi w godocie.
	\n2.Do tablicy dodaj liczby, które znalazłeś w pomieszczeniu.
	\nHINT: Wielkość liczb ma znaczenie"
	input_field.connect("text_submitted", Callable(self, "_on_text_submitted"))
	fade_overlay.visible = false
	#pulsate_label()

#func pulsate_label():
	#var tween = create_tween().set_loops() # Powtarzająca się animacja
	#tween.tween_property(label, "modulate:a", 0.3, 1.0) # Zanikanie
	#tween.tween_property(label, "modulate:a", 1.0, 1.0) # Powrót

func _on_text_submitted(new_text):
	#01100101 01111000 01101001 01110100
	if new_text.strip_edges().to_lower() == "exit":
		start_blackout()
	elif step == 0 and is_correct_declaration(new_text):
		step = 1
		label.text = "Z tym sobie poradziłeś! Teraz wprowadź dane do tablicy."
		input_field.clear()
	elif step == 1 and is_correct_number_sequence(new_text):
		start_blackout()
	else:
		glitch_label()

func is_correct_declaration(input_text):
	return input_text.strip_edges() == "var liczby = []"

func is_correct_number_sequence(input_text):
	# Konwertujemy globalną tablicę na format [x, x, x, x]
	var expected_sequence = "liczby = [" + ", ".join(global_numbers.map(func(n): return str(n))) + "]"
	
	# Sprawdzamy, czy użytkownik wpisał poprawną sekwencję liczb
	return input_text.strip_edges() == expected_sequence

func glitch_label():
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(input_field, "position:x", input_field.position.x + randi_range(-10, 10), 0.05)
		tween.tween_property(input_field, "position:x", input_field.position.x, 0.05)

func start_blackout():
	fade_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/Main/main.tscn")
