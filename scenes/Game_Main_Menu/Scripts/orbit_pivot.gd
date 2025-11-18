extends Node3D

@export var speed_deg : float = 0.5
@export var radius : float = 100.0
@export var height : float = 30.0

@onready var cam : Camera3D = $Camera3D

func _ready() -> void:
    cam.transform.origin = Vector3(radius, height, 0.0)

func _process(delta: float) -> void:
    rotate_y(deg_to_rad(speed_deg) * delta)
    cam.look_at(global_transform.origin, Vector3.UP)
