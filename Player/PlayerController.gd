extends CharacterBody3D

@export var CameraContainerNode : Node3D
# @export var VerticalRotationSpeed : float = 0.01
# @export var HorizontalRotationSpeed : float = 0.5
@onready var animator : AnimationPlayer = $"../AnimationPlayer"
@onready var inventory_ui : Control = $InventoryUI
@onready var raycast = $CameraContainer/Camera3D/interact_raycast

var can_open_door = false

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_cancel")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE) else Input.MOUSE_MODE_VISIBLE
	
	if (event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		rotate_y(deg_to_rad(-event.relative.x) * Global.mouse_sensitivity)
		CameraContainerNode.rotation.x = clamp(CameraContainerNode.rotation.x - event.relative.y * (Global.mouse_sensitivity / 50), deg_to_rad(-45), deg_to_rad(45))
	if(event.is_action_pressed("open")):
		if(!can_open_door):
			open_door()
		else:
			close_door()
	if (event.is_action_pressed("inventory")):
		inventory_ui.visible = !inventory_ui.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		$PauseMenu.pause()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE):
		move_and_slide()
		return
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func open_door():
	animator.play("open_door1")
	can_open_door = !can_open_door

func close_door():
	animator.play("close_door1")
	can_open_door = !can_open_door


func _on_trigger_zone_body_entered(body: Node3D) -> void:
	pass # Replace with function body.
