extends Node

# =====================
# REFERENCJE
# =====================

@export var player: Node
@export var door_camera: Camera3D

@export var door_anim_player: AnimationPlayer
@export var door_open_animation: String = "Door_Open"

@export var monolog_ui: Node
@export var monolog_lines: Array[String] = [
	"Co to za hałas?",
	"Wygląda na to, że drzwi się otworzyły."
]
@export var monolog_duration: float = 2.5

@export var cutscene_time: float = 3.5

# =====================
# STAN
# =====================

var _previous_camera: Camera3D = null

# =====================
# CUTSCENKA
# =====================

func play_cutscene() -> void:
	print("▶ Start cutscenki")

	_disable_player()

	# 🔹 zapamiętaj aktualną kamerę
	_previous_camera = get_viewport().get_camera_3d()

	# 🔹 przełącz na kamerę drzwi
	if door_camera:
		door_camera.current = true

	# 🔹 animacja drzwi
	if door_anim_player and door_anim_player.has_animation(door_open_animation):
		door_anim_player.play(door_open_animation)

	# 🔹 dialog
	if monolog_ui and monolog_ui.has_method("start_monolog"):
		monolog_ui.start_monolog(monolog_lines, monolog_duration)

	# 🔹 czekamy na koniec cutscenki
	await get_tree().create_timer(cutscene_time).timeout

	_end_cutscene()


func _end_cutscene() -> void:
	print("⏹ Koniec cutscenki")

	# 🔹 przywróć poprzednią kamerę
	if _previous_camera:
		_previous_camera.current = true
		_previous_camera = null

	_enable_player()


# =====================
# BLOKADA GRACZA
# =====================

func _disable_player():
	if not player:
		return

	if player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", false)
	else:
		player.process_mode = Node.PROCESS_MODE_DISABLED


func _enable_player():
	if not player:
		return

	if player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", true)
	else:
		player.process_mode = Node.PROCESS_MODE_INHERIT
