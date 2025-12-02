extends Area3D

@export var anim_player_path: NodePath = "../../../../AnimationPlayer"
@export var open_anim_name: String = "secondroom_entry_door_open"
@export var close_anim_name: String = "secondroom_entry_door_close"

@export var door_sound_path: NodePath = NodePath("") 
# ← ścieżka do AudioStreamPlayer3D lub AudioStreamPlayer

@onready var anim_player: AnimationPlayer = get_node_or_null(anim_player_path)
@onready var door_sound_node: Node = null

var player_in_area: bool = false
var door_open: bool = false   # false – zamknięte, true – otwarte

func _ready() -> void:
	# podłącz zdarzenia
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
	else:
		push_warning("DoorArea: nie znaleziono AnimationPlayer pod ścieżką %s" % anim_player_path)

	# poprawna inicjalizacja door_sound_node
	if door_sound_path != NodePath(""):
		door_sound_node = get_node_or_null(door_sound_path)
		if door_sound_node == null:
			push_warning("DoorArea: nie znaleziono node dźwięku pod %s" % str(door_sound_path))
	else:
		door_sound_node = null

	print("DoorArea ready. anim_player =", anim_player, "sound =", door_sound_node)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_area = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_area = false


func _process(delta: float) -> void:
	if not player_in_area:
		return

	# kliknięcie E + brak animacji w trakcie
	if Input.is_action_just_pressed("interact") and anim_player and not anim_player.is_playing():
		if door_open:
			# Zamknij drzwi
			if anim_player.has_animation(close_anim_name):
				anim_player.play(close_anim_name)
				_play_door_sound()
				door_open = false
			else:
				print("DoorArea: brak animacji:", close_anim_name)
		else:
			# Otwórz drzwi
			if anim_player.has_animation(open_anim_name):
				anim_player.play(open_anim_name)
				_play_door_sound()
				door_open = true
			else:
				print("DoorArea: brak animacji:", open_anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	# opcjonalna logika
	pass


func _play_door_sound() -> void:
	if door_sound_node == null:
		return

	# Jeśli jest AudioStreamPlayer3D
	if door_sound_node is AudioStreamPlayer3D:
		var p := door_sound_node as AudioStreamPlayer3D
		if p.stream:
			p.stop()
			p.play()
			print("DoorArea: odtwarzam dźwięk (3D)")
		else:
			print("DoorArea: AudioStreamPlayer3D bez streamu")

		return

	# Jeśli jest AudioStreamPlayer (2D/GUI)
	if door_sound_node is AudioStreamPlayer:
		var p2 := door_sound_node as AudioStreamPlayer
		if p2.stream:
			p2.stop()
			p2.play()
			print("DoorArea: odtwarzam dźwięk (2D)")
		else:
			print("DoorArea: AudioStreamPlayer bez streamu")

		return

	# Fallback na inne node’y z metodą play()
	if door_sound_node.has_method("play"):
		door_sound_node.call("play")
		print("DoorArea: odtwarzam dźwięk (fallback)")
	else:
		print("DoorArea: node dźwięku nie obsługuje play()")
