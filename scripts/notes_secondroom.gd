extends Node3D

# =========================================================
# TEKSTY NOTATKI (USTAWIASZ W INSPECTORZE DLA KAŻDEJ INSTANCJI)
# =========================================================

@export var zadanie2_text : String = \
"[center]Jeśli coś tu ma sens, to na pewno liczby. Zawsze warto zacząć od rzeczy, \
które wydają się oczywiste – równań, zależności i zapisanych warunków."

@export var zadanie3_text : String = \
"[center]Rozwiązanie rzadko jest końcem drogi. Często to tylko wartość pośrednia, \
która prowadzi do kolejnego kroku."

# =========================================================
# REFERENCJE LOKALNE (KAŻDA INSTANCJA MA WŁASNE UI)
# =========================================================

@onready var panel: Control = $CanvasLayer2/InfoPanel
@onready var left_label: RichTextLabel = $CanvasLayer2/InfoPanel/InfoLabelLeft
@onready var right_label: RichTextLabel = $CanvasLayer2/InfoPanel/InfoLabelRight
@onready var area: Area3D = $Area3D

# =========================================================
# STAN
# =========================================================

var player_in_range: bool = false
var can_interact: bool = false   # 🔑 BLOKUJE OTWARCIE PRZY STARCIE

# =========================================================
# READY
# =========================================================

func _ready() -> void:
	# panel NIGDY nie jest widoczny na starcie
	panel.visible = false
	print("READY:", get_path())


	# sygnały Area3D
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

# =========================================================
# UI
# =========================================================

func show_panel() -> void:
	if not panel:
		return

	if left_label:
		left_label.bbcode_enabled = true
		left_label.text = zadanie2_text

	if right_label:
		right_label.bbcode_enabled = true
		right_label.text = zadanie3_text

	panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if panel.has_method("grab_focus"):
		panel.grab_focus()



func hide_panel() -> void:
	if not panel:
		return

	panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# =========================================================
# LOGIKA INTERAKCJI
# =========================================================

func _process(_delta: float) -> void:
	if not player_in_range:
		return
	if not can_interact:
		return
	if panel.visible:
		return

	if Input.is_action_just_pressed("interact"):
		show_panel()

# =========================================================
# AREA3D
# =========================================================

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		can_interact = false

		# 🔒 odblokowujemy interakcję dopiero w NASTĘPNEJ KLATCE
		await get_tree().process_frame
		can_interact = true


func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		can_interact = false

# =========================================================
# BLOKADA INPUTU (ESC + INVENTORY)
# =========================================================

func _input(event: InputEvent) -> void:
	if not panel.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# blokada inventory
		if event.keycode == KEY_I or event.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			return

		# ESC zamyka panel
		if event.is_action_pressed("ui_cancel"):
			hide_panel()
			get_viewport().set_input_as_handled()
