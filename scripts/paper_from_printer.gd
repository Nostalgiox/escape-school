extends Node3D

# =========================
# KONFIGURACJA
# =========================

@export var task_text: String = \
"[center][b]WYDRUK SERWISOWY[/b][/center]\n\n" + \
"Wartość wejściowa: [b]45[/b]\n\n" + \
"Oblicz [b]60%[/b] tej wartości.\n\n" + \
"Uzyskany wynik będzie potrzebny do odblokowania kolejnego etapu."

# =========================
# STAN
# =========================

var unlocked: bool = false        # czy kartka może być użyta
var player_in_range: bool = false
var ui_open: bool = false

# =========================
# REFERENCJE
# =========================

@onready var area: Area3D = $Area3D
@onready var ui: CanvasLayer = $PaperUI
@onready var panel: Panel = $PaperUI/Panel
@onready var label: RichTextLabel = $PaperUI/Panel/RichTextLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var printing_audio: AudioStreamPlayer = $Printing
@onready var monolog_trigger: Area3D = $Secondroom_monologue1



# =========================
# READY
# =========================

func _ready() -> void:
	ui.visible = false
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

	label.bbcode_enabled = true
	label.text = ""

	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

# =========================
# SYGNAŁ Z KOMPUTERA
# =========================
# TEN SYGNAŁ PODŁĄCZASZ W EDYTORZE:
# Computer -> computer_unlocked -> PaperFromPrinter

func _on_computer_unlocked() -> void:
	print("PaperFromPrinter: computer_unlocked")
	if anim_player:
		anim_player.play("printing")
	if printing_audio:
		printing_audio.play()
	if monolog_trigger:
		monolog_trigger.monitoring = true
	unlocked = true

# =========================
# LOGIKA INTERAKCJI
# =========================

func _process(_delta: float) -> void:
	if not unlocked:
		return

	if player_in_range and not ui_open and Input.is_action_just_pressed("interact"):
		open_ui()

# =========================
# UI
# =========================

func open_ui() -> void:
	ui.visible = true
	ui_open = true
	label.text = task_text

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_ui() -> void:
	ui.visible = false
	ui_open = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# =========================
# INPUT (ESC)
# =========================

func _input(event: InputEvent) -> void:
	if not ui_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()


# =========================
# AREA3D
# =========================

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
