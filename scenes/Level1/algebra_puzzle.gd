extends Node3D

@export var player : CharacterBody3D
@export var locker_label : Label3D
@export var locker_puzzle : Panel 
@export var shelf_area : Area3D

@onready var interact_area : Area3D = $InteractArea

var player_in_area = false

func _ready() -> void:
	locker_label.visible = false
	locker_puzzle.visible = false
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)
	shelf_area.body_entered.connect(_on_shelf_area_body_entered)
	shelf_area.body_exited.connect(_on_shelf_area_body_exited)

func _process(delta: float) -> void:
	# Toggle panel przyciskiem "interact"
	if player_in_area and Input.is_action_just_pressed("interact"):
		toggle_puzzle()
	# Jeśli panel zagadki jest otwarty, ignoruj ESC
	if locker_puzzle.visible:
		# nic nie robimy, nie wywołujemy pause ani nic
		pass
	else:
		# Tutaj możesz dodać logikę, jeśli chcesz, aby ESC działało normalnie
		if Input.is_action_just_pressed("ui_cancel"):
			# np. wywołanie pause menu
			get_tree().paused = not get_tree().paused



func _on_interact_area_body_exited(body: Node3D) -> void:
	pass # Replace with function body.

func _on_interact_area_body_entered(body: Node3D) -> void:
	if body == player:
		print("Gracz wszedł do obszaru interakcji z zagadką algebraiczną")

func _on_shelf_area_body_exited(body: Node3D) -> void:
	if body == player:
		player_in_area = false
		print("Gracz wyszedł z obszaru półki")
		locker_label.visible = false


func _on_shelf_area_body_entered(body: Node3D) -> void:
	if body == player:
		player_in_area = true
		print("Gracz wszedł z obszaru półki")
		locker_label.visible = true

func toggle_puzzle() -> void:
	if locker_puzzle.visible:
		# Jeśli panel jest widoczny, zamykamy
		print("Zamykam panel zagadki")
		locker_puzzle.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Jeśli panel jest zamknięty, otwieramy
		print("Otwieram panel zagadki")
		locker_puzzle.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
