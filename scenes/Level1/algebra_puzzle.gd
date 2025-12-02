extends Node3D

@export var player : CharacterBody3D
@export var locker_label : Label3D
@export var locker_puzzle : LockPanel 
@export var shelf_area : Area3D

@onready var interact_area : Area3D = $InteractArea

@export var anim_player : AnimationPlayer

var player_in_area = false
var _puzzle_solved = false

func _ready() -> void:
	locker_label.visible = false
	locker_puzzle.visible = false

	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)
	shelf_area.body_entered.connect(_on_shelf_area_body_entered)
	shelf_area.body_exited.connect(_on_shelf_area_body_exited)

	
	locker_puzzle.unlocked.connect(_on_puzzle_unlocked)

func _process(delta: float) -> void:
	# Toggle panel przyciskiem "interact"
	if not _puzzle_solved and player_in_area and Input.is_action_just_pressed("interact"):
		toggle_puzzle()
	# Jeśli panel zagadki jest otwarty, ignoruj ESC
	if locker_puzzle.visible:
		# nic nie robimy, nie wywołujemy pause ani nic
		pass
	else:
		# Tutaj możesz dodać logikę, jeśli chcesz, aby ESC działało normalnie
		if Input.is_action_just_pressed("ui_cancel"):
			pass
			# np. wywołanie pause menu
			# get_tree().paused = not get_tree().paused



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
	if _puzzle_solved:
		return
	if locker_puzzle.visible:
		print("Zamykam panel zagadki")
		locker_puzzle.close_panel()
	else:
		print("Otwieram panel zagadki")
		locker_puzzle.open_panel()

func _on_puzzle_unlocked() -> void:
	print("Zagadkę rozwiązano!")
	_puzzle_solved = true
	locker_label.visible = false
	player_in_area = false

	if is_instance_valid(shelf_area):
		shelf_area.set_deferred("monitoring", false)
		shelf_area.set_deferred("monitorable", false)
	if is_instance_valid(interact_area):
		interact_area.set_deferred("monitoring", false)
		interact_area.set_deferred("monitorable", false)
	
	if locker_puzzle.visible:
		locker_puzzle.close_panel()
	
	call_deferred("_play_unlock_animation")

func _play_unlock_animation() -> void:
	if anim_player and anim_player.has_animation("locker_puzzle_solved"):
		anim_player.play("locker_puzzle_solved")
	else:
		push_error("AnimationPlayer or animation 'locker_puzzle_solved' not found.")
