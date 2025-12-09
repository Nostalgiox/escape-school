extends Node3D

signal computer_unlocked

var A: int
var B: int
var x: float
var y: float
var correct_code: int

var player_in_range: bool = false
var player_ref: Node3D = null
var prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var prev_player_process_mode: int = Node.PROCESS_MODE_INHERIT

@onready var ui: CanvasLayer = $ComputerUI
@onready var panel: Panel = $ComputerUI/Panel
@onready var label_equation: Label = $ComputerUI/Panel/MarginContainer/VBoxContainer/LabelEquation
@onready var message: Label = $ComputerUI/Panel/MarginContainer/VBoxContainer/LabelMessage
@onready var input_code: LineEdit = $ComputerUI/Panel/MarginContainer/VBoxContainer/HBoxCode/LineEditCode
@onready var notes_input: LineEdit = $ComputerUI/Panel/MarginContainer/VBoxContainer/HBoxNotes/NotesLineEdit
@onready var button_submit: Button = $ComputerUI/Panel/MarginContainer/VBoxContainer/HBoxButtons/ButtonSubmit
@onready var area: Area3D = $Area3D


func _ready():
	ui.visible = false

	# panel startowo całkowicie przezroczysty (do fade-in)
	panel.modulate.a = 0.0

	# ten node i UI działają zawsze
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	generate_equation()

	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	button_submit.pressed.connect(_on_ButtonSubmit_pressed)


func generate_equation():
	A = randi_range(10, 20)
	B = randi_range(2, 6)

	x = (A - B) / 2.0
	y = x + B
	correct_code = int(x * y)

	#label_equation.text = "Rozwiąż układ równań:\n1) x + y = %d\n2) y = x + %d" % [A, B]

	message.text = ""
	input_code.text = ""
	notes_input.text = ""


func interact():
	ui.visible = true

	# zapamiętaj tryb myszy i pokaż kursor
	prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# zamrażamy tylko gracza (jego _process/_physics_process nie działają)
	if player_ref:
		prev_player_process_mode = player_ref.process_mode
		player_ref.process_mode = Node.PROCESS_MODE_DISABLED

	# fade-in panelu
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	input_code.grab_focus()


func close_ui():
	ui.visible = false

	# przywróć tryb myszy
	Input.set_mouse_mode(prev_mouse_mode)

	# odmróź gracza
	if player_ref:
		player_ref.process_mode = prev_player_process_mode


func _process(_delta):
	# otwieranie panelu przy E (lub innej akcji "interact")
	if player_in_range and not ui.visible and Input.is_action_just_pressed("interact"):
		interact()

	# zamykanie panelu ESC (ui_cancel)
	if ui.visible and Input.is_action_just_pressed("ui_cancel"):
		close_ui()


func _on_area_body_entered(body: Node):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body as Node3D


func _on_area_body_exited(body: Node):
	if body.is_in_group("player"):
		player_in_range = false
		# nie zamykamy panelu automatycznie – tylko ESC lub przycisk
		# player_ref zostaje, żeby po zamknięciu odblokować gracza


func _on_ButtonSubmit_pressed():
	if input_code.text == "":
		message.text = "Wpisz kod."
		return

	var user_code := int(input_code.text)

	if user_code == correct_code:
		message.text = "✔ Poprawne rozwiązanie!"
		emit_signal("computer_unlocked")
		await get_tree().create_timer(1.2).timeout
		close_ui()
	else:
		message.text = "✘ Błędny kod. Spróbuj ponownie."
