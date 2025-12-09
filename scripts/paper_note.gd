# paper_note.gd – panel-kartka z treścią zadania,
# otwierany po wejściu w Area3D i wciśnięciu F (akcja "interact").

extends Node3D

@export var panel_path: NodePath = ^"PaperUI/Panel"
@export var task_label_path: NodePath = ^"PaperUI/Panel/MarginContainer/TaskLabel"

# Treść zadania na kartce (BBCode, możesz zmienić w Inspectorze)
@export var task_text: String = \
"[center][b]ZADANIE[/b][/center]\n\n" + \
"Suma dwóch liczb wynosi [b]14[/b].\n" + \
"Druga liczba jest o [b]4[/b] większa od pierwszej.\n\n" + \
"Oblicz te liczby oraz ich iloczyn.\n" + \
"Iloczyn wpisz jako kod w komputerze."

var panel: Control
var task_label: RichTextLabel

var player_in_range: bool = false
var player_ref: Node3D = null
var prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var prev_player_process_mode: int = Node.PROCESS_MODE_INHERIT

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $PaperUI


func _ready() -> void:
	# pobierz panel i label
	panel = get_node(panel_path) as Control
	task_label = get_node(task_label_path) as RichTextLabel

	# przygotuj UI
	ui.visible = false
	panel.visible = true  # panel może być widoczny, ważne że CanvasLayer jest ukryty
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

	if task_label:
		task_label.bbcode_enabled = true
		task_label.text = ""  # ustawimy przy otwarciu

	# podłącz Area3D
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)


func show_panel() -> void:
	if not panel or not task_label:
		push_error("paper_note.gd: brak panelu lub TaskLabel – sprawdź ścieżki w Inspectorze.")
		return

	# ustaw tekst zadania (BBCode jest interpretowany, bo bbcode_enabled = true)
	task_label.text = task_text

	ui.visible = true

	# myszka widoczna
	prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# zamrażamy tylko gracza
	if player_ref:
		prev_player_process_mode = player_ref.process_mode
		player_ref.process_mode = Node.PROCESS_MODE_DISABLED

	# focus na panelu
	if panel.has_method("grab_focus"):
		panel.grab_focus()


func hide_panel() -> void:
	ui.visible = false

	# przywróć tryb myszy
	Input.set_mouse_mode(prev_mouse_mode)

	# odmroź gracza
	if player_ref:
		player_ref.process_mode = prev_player_process_mode


func _process(_delta: float) -> void:
	# otwieranie kartki: gracz w zasięgu + F (interact) + panel zamknięty
	if player_in_range and not ui.visible and Input.is_action_just_pressed("interact"):
		show_panel()

	# zamykanie kartki: ESC (ui_cancel)
	if ui.visible and Input.is_action_just_pressed("ui_cancel"):
		hide_panel()


func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body as Node3D


func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		# nie zamykamy panelu automatycznie; tylko ESC
