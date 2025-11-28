extends Node3D

@export var lamps: Array[Node3D] = []      # dodaj lampy w Inspectorze
@export var min_delay: float = 0.1         # minimalny czas między miganiem
@export var max_delay: float = 0.7         # maksymalny czas między miganiem

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for lamp in lamps:
		if lamp:
			_start_lamp_cycle(lamp)


func _start_lamp_cycle(lamp: Node3D) -> void:
	call_deferred("_lamp_cycle", lamp)


func _lamp_cycle(lamp: Node3D) -> void:
	while is_instance_valid(lamp):
		var state := rng.randi_range(0, 1) == 1
		_set_lamp(lamp, state)

		var wait := rng.randf_range(min_delay, max_delay)
		await get_tree().create_timer(wait).timeout


func _set_lamp(lamp: Node3D, on: bool) -> void:
	# Light3D
	if lamp is Light3D:
		lamp.visible = on
		return

	# MeshInstance3D (żarówka)
	if lamp is MeshInstance3D:
		lamp.visible = on
		return

	# jeśli lampy mają dzieci z Light3D/żarówką
	for c in lamp.get_children():
		if c is Light3D or c is MeshInstance3D:
			c.visible = on
