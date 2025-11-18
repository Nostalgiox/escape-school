extends Node3D

# ustaw w Inspectorze
@export var animation_player_path: NodePath = NodePath("")   # przeciągnij AnimationPlayer tutaj
@export var area_path: NodePath = NodePath("")              # przeciągnij Area3D tutaj

@export var open_animation: String = "open_entry_door"
@export var close_animation: String = "close_entry_door"

@export var interact_action: String = "interact"    # nazwa akcji w Input Map (np. "interact")
@export var auto_close_after: float = 0.0           # 0 = bez automatycznego zamykania

var _is_anim_playing: bool = false

# referencje ustawione w _ready()
var animator: AnimationPlayer = null
var area_node: Area3D = null

# stan
var player_in_area: bool = false
var is_open: bool = false
var _auto_close_timer: SceneTreeTimer = null


func _ready() -> void:
	# pobierz animator z path (Inspector)
	if animation_player_path != NodePath(""):
		animator = get_node_or_null(animation_player_path) as AnimationPlayer
	if animator == null:
		# fallback: spróbuj znaleźć dziecko AnimationPlayer
		if has_node("AnimationPlayer"):
			animator = get_node("AnimationPlayer") as AnimationPlayer

	if animator == null:
		push_warning("EntryDoor: AnimationPlayer nie znaleziony. Ustaw animation_player_path w Inspectorze.")
	else:
		print("EntryDoor: found AnimationPlayer at: ", animator.get_path())

	# pobierz area z path (Inspector)
	if area_path != NodePath(""):
		area_node = get_node_or_null(area_path) as Area3D
	if area_node == null:
		# fallback: spróbuj znaleźć child o typie Area3D
		for c in get_children():
			if c is Area3D:
				area_node = c as Area3D
				break

	if area_node == null:
		push_warning("EntryDoor: Area3D not found. Ustaw area_path w Inspectorze lub dodaj Area3D jako child.")
	else:
		area_node.monitoring = true
		area_node.monitorable = true
		var cb_enter := Callable(self, "_on_area_body_entered")
		var cb_exit := Callable(self, "_on_area_body_exited")
		if not area_node.is_connected("body_entered", cb_enter):
			area_node.connect("body_entered", cb_enter)
		if not area_node.is_connected("body_exited", cb_exit):
			area_node.connect("body_exited", cb_exit)
		print("EntryDoor: connected to Area3D signals.")


func _process(delta: float) -> void:
	# sprawdzamy input w _process - proste i niezawodne
	if player_in_area:
		if Input.is_action_just_pressed(interact_action):
			_toggle_door()


# Area signals
func _on_area_body_entered(body: Node) -> void:
	if not body:
		return
	# rozpoznaj gracza: grupa "player" lub CharacterBody3D
	if (body.is_in_group("player")) or (body.get_class() == "CharacterBody3D"):
		player_in_area = true
		print("EntryDoor: player entered area.")


func _on_area_body_exited(body: Node) -> void:
	if not body:
		return
	if (body.is_in_group("player")) or (body.get_class() == "CharacterBody3D"):
		player_in_area = false
		print("EntryDoor: player left area.")


# toggle open/close
func _toggle_door() -> void:
	# jeśli animator nie ustawiony -> nic nie robimy
	if animator == null:
		push_warning("EntryDoor: animator == null; nie można odtworzyć animacji.")
		return

	# jeśli już trwa odtwarzanie animacji, ignorujemy spam
	if _is_anim_playing:
		# opcjonalny debug
		# print("EntryDoor: animation playing, input ignored.")
		return

	# anuluj istniejący timer auto close (nie chcemy konfliktów)
	if _auto_close_timer:
		_auto_close_timer = null

	# wybieramy którą animację odtworzyć
	if is_open:
		# zamykanie
		if animator.has_animation(close_animation):
			_is_anim_playing = true
			animator.play(close_animation)
			is_open = false
			print("EntryDoor: playing close animation:", close_animation)

			# pobierz długość animacji (fallback do 0.5s jeśli brak)
			var len: float = 0.5
			var a = animator.get_animation(close_animation)
			if a:
				len = a.length
			# czekamy aż animacja się skończy i odblokujemy input
			var t = get_tree().create_timer(len)
			await t.timeout
			_is_anim_playing = false
		else:
			push_warning("EntryDoor: brak animacji zamykania: " + str(close_animation))
	else:
		# otwieranie
		if animator.has_animation(open_animation):
			_is_anim_playing = true
			animator.play(open_animation)
			is_open = true
			print("EntryDoor: playing open animation:", open_animation)

			# pobierz długość animacji
			var len: float = 0.5
			var a = animator.get_animation(open_animation)
			if a:
				len = a.length
			# czekamy aż animacja się skończy i odblokujemy input
			var t = get_tree().create_timer(len)
			await t.timeout
			_is_anim_playing = false

			# opcjonalne automatyczne zamknięcie (uruchamiamy timer po zakończeniu otwarcia)
			if auto_close_after > 0.0:
				_auto_close_timer = get_tree().create_timer(auto_close_after)
				_auto_close_timer.timeout.connect(Callable(self, "_on_auto_close_timeout"))
		else:
			push_warning("EntryDoor: brak animacji otwierania: " + str(open_animation))


func _on_auto_close_timeout() -> void:
	_auto_close_timer = null
	call_deferred("_close_door_deferred")


func _close_door_deferred() -> void:
	if animator and animator.has_animation(close_animation):
		animator.play(close_animation)
		is_open = false
		print("EntryDoor: auto-closing (played):", close_animation)
