extends Node3D
# Proceduralny model cyfry "7" w stylu grubego markera / kredy.

@export var total_height: float = 1.0
@export var stroke_thickness: float = 0.18
@export var depth: float = 0.12
@export var material_albedo: Color = Color(0.9, 0.9, 0.9)

var _top_mesh_instance: MeshInstance3D
var _diag_mesh_instance: MeshInstance3D

func _ready() -> void:
	_build_model()


func _build_model() -> void:
	# usuń stare
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()

	var H: float = max(0.01, total_height)
	var stroke: float = max(0.01, stroke_thickness)
	var D: float = max(0.01, depth)

	# szerokość cyfry (proporcjonalna do wysokości)
	var W: float = H * 0.6

	# ---------- 1) Górny pasek ----------
	var top_bar_width: float = W
	var top_bar_height: float = stroke

	var top_box := BoxMesh.new()
	top_box.size = Vector3(top_bar_width, top_bar_height, D)

	_top_mesh_instance = MeshInstance3D.new()
	_top_mesh_instance.mesh = top_box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = material_albedo
	mat.roughness = 0.8
	_top_mesh_instance.material_override = mat

	_top_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_top_mesh_instance)

	var top_y: float = H * 0.5 - top_bar_height * 0.5
	_top_mesh_instance.position = Vector3(0.0, top_y, 0.0)

	# ---------- 2) Skośna noga ----------
	var top_right_x: float = W * 0.5
	var top_right_y: float = top_y - (top_bar_height * 0.5)

	var bottom_left_x: float = -W * 0.5 + stroke * 0.25
	var bottom_left_y: float = -H * 0.5

	var dx: float = top_right_x - bottom_left_x
	var dy: float = top_right_y - bottom_left_y
	var diag_length: float = sqrt(dx * dx + dy * dy)

	var diag_box := BoxMesh.new()
	diag_box.size = Vector3(diag_length, stroke, D)

	_diag_mesh_instance = MeshInstance3D.new()
	_diag_mesh_instance.mesh = diag_box
	_diag_mesh_instance.material_override = mat.duplicate()
	_diag_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_diag_mesh_instance)

	var mid_x: float = (top_right_x + bottom_left_x) * 0.5
	var mid_y: float = (top_right_y + bottom_left_y) * 0.5
	_diag_mesh_instance.position = Vector3(mid_x, mid_y, 0.0)

	var angle: float = atan2(dy, dx)
	_diag_mesh_instance.rotation = Vector3(0, 0, angle)

	_adjust_origin_to_center()


func _adjust_origin_to_center() -> void:
	var min_v: Vector3 = Vector3(INF, INF, INF)
	var max_v: Vector3 = Vector3(-INF, -INF, -INF)

	for m in get_children():
		if m is MeshInstance3D and m.mesh != null:
			var aabb: AABB = m.mesh.get_aabb()
			var tr: Transform3D = m.transform

			var pts: Array[Vector3] = [
				Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
				Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
				Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
				Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
				Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
			]

			for p in pts:
				# POPRAWNE PRZEKSZTAŁCENIE punktu przez transform:
				var wc: Vector3 = tr.basis * p + tr.origin
				min_v = min_v.min(wc)
				max_v = max_v.max(wc)

	if min_v.x == INF:
		return

	var center: Vector3 = (min_v + max_v) * 0.5

	for m in get_children():
		if m is MeshInstance3D:
			m.position -= center
