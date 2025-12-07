extends Node3D
# LampAutoAnim.gd
# - Po wejściu do Area3D i wciśnięciu "interact" odpala animację `anim_up_name`.
# - Po wyjściu z Area3D odpala animację `anim_down_name`.
# - Bez obracania myszy / bez dodatkowego InputMap (zakładam, że "interact" istnieje).

@export var interaction_area: NodePath = NodePath("")        # Area3D który wykrywa gracza
@export var animation_player_path: NodePath = NodePath("")   # AnimationPlayer który ma animacje lamp_up / lamp_down
@export var anim_up_name: String = "lamp_up"                 # nazwa animacji otwierającej/wystawiającej lampę
@export var anim_down_name: String = "lamp_down"             # nazwa animacji chowającej lampę
@export var require_interact_action: String = "interact"     # akcja do wejścia (domyślnie "interact")

# stan
var _area_node: Area3D = null
var _anim_player: AnimationPlayer = null
var _player_in_range: bool = false
var _playing_anim: bool = false

func _ready() -> void:
	# znajdź Area3D
	if interaction_area != NodePath(""):
		var a := get_node_or_null(interaction_area)
		if a and a is Area3D:
			_area_node = a
			if not _area_node.is_connected("body_entered", Callable(self, "_on_area_body_entered")):
				_area_node.connect("body_entered", Callable(self, "_on_area_body_entered"))
			if not _area_node.is_connected("body_exited", Callable(self, "_on_area_body_exited")):
				_area_node.connect("body_exited", Callable(self, "_on_area_body_exited"))
		else:
			push_warning("LampAutoAnim: interaction_area nie jest poprawnym Area3D.")
	else:
		push_warning("LampAutoAnim: interaction_area nie ustawiony.")

	# znajdź AnimationPlayer
	if animation_player_path != NodePath(""):
		var ap := get_node_or_null(animation_player_path)
		if ap and ap is AnimationPlayer:
			_anim_player = ap
			# podłącz reset flagi po zakończeniu animacji
			if not _anim_player.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
				_anim_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
		else:
			push_warning("LampAutoAnim: animation_player_path nie wskazuje AnimationPlayer.")
	else:
		push_warning("LampAutoAnim: animation_player_path nie ustawiony.")

	# niewidoczny stan na start
	_player_in_range = false
	_playing_anim = false


func _process(delta: float) -> void:
	# wejście do trybu przez wciśnięcie akcji (tylko kiedy grac jest w zasięgu i nic nie gra)
	if _player_in_range and not _playing_anim and Input.is_action_just_pressed(require_interact_action):
		_play_up()


func _on_area_body_entered(body: Node) -> void:
	# możesz tu dodatkowo filtrować po grupie "player" lub rodzaju (CharacterBody3D)
	if body is CharacterBody3D or (body != null and body.is_in_group("player")):
		_player_in_range = true
		# (opcjonalnie) pokaż UI prompt tutaj


func _on_area_body_exited(body: Node) -> void:
	if body is CharacterBody3D or (body != null and body.is_in_group("player")):
		_player_in_range = false
		# jeśli wychodzimy, chcemy odpalić animację schowania (nawet jeśli aktualnie nic nie gra)
		_play_down()


# --- funkcje odpalenia animacji ---
func _play_up() -> void:
	if _anim_player == null:
		return
	if not _anim_player.has_animation(anim_up_name):
		push_warning("LampAutoAnim: brak animacji: %s" % anim_up_name)
		return
	_playing_anim = true
	_anim_player.play(anim_up_name)


func _play_down() -> void:
	if _anim_player == null:
		return
	if not _anim_player.has_animation(anim_down_name):
		push_warning("LampAutoAnim: brak animacji: %s" % anim_down_name)
		return
	_playing_anim = true
	_anim_player.play(anim_down_name)


func _on_animation_finished(anim_name: String) -> void:
	# reset flagi gdy dowolna animacja się skończy
	_playing_anim = false
	# opcjonalnie: jeśli skończyła się animacja "lamp_down", możesz przywrócić jakiś stan
	# if anim_name == anim_down_name:
	#     ... coś zrobić ...
