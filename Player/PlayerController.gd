extends CharacterBody3D

@export var CameraContainerNode: Node3D

@onready var animator: AnimationPlayer = $"../AnimationPlayer"
@onready var inventory_ui: Control = $InventoryUI
@onready var camera: Camera3D = $CameraContainer/Camera3D

# HUD
@onready var interact_icon: TextureRect = $CameraContainer/CanvasLayer/HUDRoot/TextureRect
@onready var backpack_icon: TextureRect = $CameraContainer/CanvasLayer/HUDRoot/TextureRect2

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

var controls_enabled: bool = true

# ===== INTERACTION STATE =====
var is_in_interaction_area: bool = false
var current_interactable: Node = null

# ============================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if camera:
		camera.fov = Global.fov
	Global.fov_changed.connect(_on_global_fov_changed)

	interact_icon.visible = false

func _on_global_fov_changed(new_fov: float) -> void:
	if camera:
		camera.fov = new_fov

# ============================
# INPUT
# ============================
func _input(event: InputEvent) -> void:

	# ESC / PAUSE / INVENTORY
	if event.is_action_pressed("ui_cancel"):
		var invh = $InventoryHandler
		if invh and invh.IsDetailsOpen():
			invh.CloseItemDetails()
			get_viewport().set_input_as_handled()
			return

		if inventory_ui.visible:
			inventory_ui.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

		if get_tree().paused:
			$PauseMenu.unpause()
		else:
			$PauseMenu.pause()

		get_viewport().set_input_as_handled()
		return

	# BLOKADA KONTROLI
	if not controls_enabled:
		if event.is_action_pressed("inventory"):
			inventory_ui.visible = !inventory_ui.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	# RUCH KAMERY
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x) * Global.mouse_sensitivity)
		CameraContainerNode.rotation.x = clamp(
			CameraContainerNode.rotation.x - event.relative.y * (Global.mouse_sensitivity / 50.0),
			deg_to_rad(-45),
			deg_to_rad(45)
		)

	# INVENTORY
	if event.is_action_pressed("inventory"):
		inventory_ui.visible = !inventory_ui.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# ===== INTERACTION (F) =====
	if event.is_action_pressed("interact"):
		if is_in_interaction_area and current_interactable:
			if current_interactable.has_method("interact"):
				current_interactable.interact(self)

# ============================
# PHYSICS
# ============================
func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		move_and_slide()
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

# ============================
# INTERACTION API (WOŁANE Z Area3D)
# ============================
func enter_interaction_area(area: Area3D) -> void:
	is_in_interaction_area = true
	current_interactable = area
	interact_icon.visible = true

func exit_interaction_area(area: Area3D) -> void:
	if area == current_interactable:
		is_in_interaction_area = false
		current_interactable = null
		interact_icon.visible = false
