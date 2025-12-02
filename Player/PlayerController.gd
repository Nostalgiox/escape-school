extends CharacterBody3D

@export var CameraContainerNode : Node3D
@onready var animator : AnimationPlayer = $"../AnimationPlayer"
@onready var inventory_ui : Control = $InventoryUI
@onready var raycast = $CameraContainer/Camera3D/interact_raycast
@onready var camera : Camera3D = $CameraContainer/Camera3D

var can_open_door = false

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# nowa zmienna sterująca
var controls_enabled: bool = true

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	# jeśli wyłączamy kontrolę to sensownie pokazać kursor (ale LockPanel też to ustawia)
	if not controls_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# przywracamy capture tylko jeśli inventory nie jest otwarte
		if not inventory_ui.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		camera.fov = Global.fov
	Global.fov_changed.connect(_on_global_fov_changed)

func _on_global_fov_changed(new_fov: float) -> void:
	if camera:
		camera.fov = new_fov

func _input(event: InputEvent) -> void:
	# pozwól obsługiwać ESC i inventory nawet jeśli controls wyłączone,
	# bo gracz może chcieć wyjść z pauzy/inventory — jeśli chcesz zablokować też te, usuń ten warunek.
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

	# jeśli kontrola wyłączona, ignoruj ruch kamery i gameplay input
	if not controls_enabled:
		# ale pozwól dalej na otwieranie inventory przez action (opcjonalnie)
		if event.is_action_pressed("inventory"):
			if get_tree().paused:
				return
			inventory_ui.visible = !inventory_ui.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
			if not inventory_ui.visible:
				var invh2 = $InventoryHandler
				if invh2:
					invh2.CloseItemDetails()
			get_viewport().set_input_as_handled()
		return

	if (event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		rotate_y(deg_to_rad(-event.relative.x) * Global.mouse_sensitivity)
		CameraContainerNode.rotation.x = clamp(CameraContainerNode.rotation.x - event.relative.y * (Global.mouse_sensitivity / 50), deg_to_rad(-45), deg_to_rad(45))

	if (event.is_action_pressed("inventory")):
		if get_tree().paused:
			return
		inventory_ui.visible = !inventory_ui.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
		if not inventory_ui.visible:
			var invh = $InventoryHandler
			if invh:
				invh.CloseItemDetails()
		get_viewport().set_input_as_handled()
		return

func _physics_process(delta: float) -> void:
	# jeśli kontrola wyłączona, nie wykonujemy ruchu
	if not controls_enabled:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE):
		move_and_slide()
		return

	# Handle jump.
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

func open_door():
	animator.play("open_door1")
	can_open_door = !can_open_door

func close_door():
	animator.play("close_door1")
	can_open_door = !can_open_door

func _on_trigger_zone_body_entered(body: Node3D) -> void:
	pass
