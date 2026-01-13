extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("enter_interaction_area"):
			body.enter_interaction_area(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("exit_interaction_area"):
			body.exit_interaction_area(self)
