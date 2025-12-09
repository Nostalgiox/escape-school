# notatka.gd - prosty, stabilny panel z dwoma RichTextLabel,
# otwierany po wejściu w Area3D i wciśnięciu F (akcja "interact"),
# z blokadą akcji "inventory" gdy panel jest otwarty.

extends Node3D

# paths do elementów UI (ustaw w Inspectorze, albo zostaw puste
# jeśli Panel/InfoLabelLeft/InfoLabelRight są rodzeństwem / dzieckiem sceny)
@export var panel_path   : NodePath = NodePath("")
@export var left_label_path  : NodePath = NodePath("")  # InfoLabelLeft
@export var right_label_path : NodePath = NodePath("")  # InfoLabelRight

# treści (edytuj w Inspectorze jeśli chcesz)
@export var zadanie2_text : String = "[center][b]Tutaj bedzie 2 zadanie"
@export var zadanie3_text : String = "[center][b]Tutaj bedzie 3 zadanie"

# referencje
var panel : Control = null
var left_label : RichTextLabel = null
var right_label : RichTextLabel = null

# Area3D / gracz
var player_in_range: bool = false
@onready var area: Area3D = $Area3D


func _ready() -> void:
	# pobierz kontrolki wg ścieżek lub fallback - get_node_or_null
	if panel_path != NodePath(""):
		panel = get_node_or_null(panel_path) as Control
	else:
		panel = get_node_or_null("Panel") as Control

	if left_label_path != NodePath(""):
		left_label = get_node_or_null(left_label_path) as RichTextLabel
	else:
		left_label = get_node_or_null("InfoLabelLeft") as RichTextLabel

	if right_label_path != NodePath(""):
		right_label = get_node_or_null(right_label_path) as RichTextLabel
	else:
		right_label = get_node_or_null("InfoLabelRight") as RichTextLabel

	# ukryj panel na start
	if panel:
		panel.visible = false

	# podłącz Area3D (jeśli istnieje)
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)


# Bezpieczne ustawienie RichTextLabel (próbujemy różnych API)
func _set_label_text(node: Node, text: String) -> void:
	if not node:
		return
	if node.has_method("clear"):
		node.call("clear")
	# preferuj bbcode jeśli dostępne
	if node.has_method("append_bbcode"):
		node.call("append_bbcode", text)
		return
	if node.has_method("set_bbcode"):
		node.call("set_bbcode", text)
		return
	if node.has_method("set_bbcode_text"):
		node.call("set_bbcode_text", text)
		return
	# fallback plain text
	if node.has_method("set_text"):
		node.call("set_text", text)
		return
	if node.has_method("append_text"):
		node.call("append_text", text)
		return

	push_warning("notatka.gd: nie udało się ustawić tekstu na node: %s" % str(node))


func show_panel() -> void:
	if not panel:
		push_error("notatka.gd: brak panel_path (Panel). Podłącz panel w Inspectorze.")
		return

	# ustaw teksty zawsze przy otwarciu
	_set_label_text(left_label, zadanie2_text)
	_set_label_text(right_label, zadanie3_text)

	panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# (opcjonalnie) nadaj focus, żeby gui_input działało na kontrolce
	if panel.has_method("grab_focus"):
		panel.grab_focus()


func hide_panel() -> void:
	if not panel:
		return
	panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Otwieranie panelu: gracz w Area3D + F (akcja "interact")
func _process(_delta: float) -> void:
	if player_in_range and panel and not panel.visible:
		if Input.is_action_just_pressed("interact"):
			show_panel()


# Wejście / wyjście gracza do/z Area3D
func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false


# blokujemy akcję inventory gdy panel otwarty; raw 'I' również
func _input(event: InputEvent) -> void:
	if not panel or not panel.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# raw 'I'
		if event.keycode == KEY_I:
			var vp := get_viewport()
			if vp and vp.has_method("set_input_as_handled"):
				vp.set_input_as_handled()
			return

		# akcja "inventory"
		if event.is_action_pressed("inventory", false):
			var vp2 := get_viewport()
			if vp2 and vp2.has_method("set_input_as_handled"):
				vp2.set_input_as_handled()
			return

		# Esc zamyka panel
		if event.is_action_pressed("ui_cancel", false):
			hide_panel()
			var vp3 := get_viewport()
			if vp3 and vp3.has_method("set_input_as_handled"):
				vp3.set_input_as_handled()
			return
