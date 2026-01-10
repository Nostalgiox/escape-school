extends Node3D

# =====================
# REFERENCJE
# =====================

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $CanvasLayer
@onready var panel: Control = $CanvasLayer/Panel
@onready var answer_input: LineEdit = $CanvasLayer/Panel/MarginContainer/VBoxContainer/AnswerContainer/AnswerLineEdit
@onready var confirm_button: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/Button
@onready var message_label: Label = $CanvasLayer/Panel/MarginContainer/VBoxContainer/MessageLabel

@export var cutscene_controller: Node
@export var monolog: Area3D
@export var mesh: MeshInstance3D
@export var correct_answer: String = "6"
@export var door_open_sfx: AudioStreamPlayer

# =====================
# STAN
# =====================

var unlocked: bool = false
var solved: bool = false
var player_in_range: bool = false

# =====================
# READY
# =====================

func _ready() -> void:
	# UI zablokowane na start
	ui.visible = false
	panel.visible = false

	# Area zablokowane na start
	area.monitoring = false
	area.monitorable = false

	# widoczność obiektów
	if mesh:
		mesh.visible = false

	# zawsze procesuj (ważne dla ESC)
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	# sygnały Area3D
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

	# przycisk OK
	confirm_button.pressed.connect(_on_confirm_pressed)

	message_label.text = ""

# =====================
# ODBLOKOWANIE Z POPRZEDNIEJ ZAGADKI
# =====================

func unlock_puzzle() -> void:
	unlocked = true
	area.monitoring = true
	area.monitorable = true

	if monolog:
		monolog.monitoring = true
		monolog.monitorable = true

	if mesh:
		mesh.visible = true

	print("Zagadka 3 odblokowana")

# =====================
# PROCESS – OTWIERANIE UI
# =====================

func _process(_delta: float) -> void:
	if unlocked and not solved and player_in_range and not ui.visible:
		if Input.is_action_just_pressed("interact"):
			open_ui()

# =====================
# UI
# =====================

func open_ui() -> void:
	ui.visible = true
	panel.visible = true

	message_label.text = ""
	answer_input.text = ""

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	answer_input.editable = true
	answer_input.grab_focus()

func close_ui() -> void:
	ui.visible = false
	panel.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	answer_input.release_focus()

# =====================
# INPUT – BLOKADY ESC / INVENTORY
# =====================

func _input(event: InputEvent) -> void:
	if not ui.visible:
		return

	# ESC – zamyka panel, NIE pause menu
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return

	# blokada inventory
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		return

# =====================
# LOGIKA ZAGADKI
# =====================

func _on_confirm_pressed() -> void:
	if solved:
		return

	var answer := answer_input.text.strip_edges()

	if answer == "":
		message_label.text = "Wpisz odpowiedź."
		return

	if answer == correct_answer:
		message_label.text = "✔ Poprawna odpowiedź."
		solved = true
		await get_tree().create_timer(0.8).timeout
		close_ui()
		_on_puzzle_solved()
	else:
		message_label.text = "✘ Błędna odpowiedź."

func _on_puzzle_solved() -> void:
	print("Zagadka 3 rozwiązana")
	door_open_sfx.play()
	if cutscene_controller and cutscene_controller.has_method("play_cutscene"):
		cutscene_controller.play_cutscene()

# =====================
# AREA3D
# =====================

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

# =====================
# SYGNAŁ Z POPRZEDNIEJ ZAGADKI
# =====================

func _on_kitchen_papernote_note_solved() -> void:
	unlock_puzzle()
