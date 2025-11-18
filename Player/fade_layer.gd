extends CanvasLayer

@onready var color_rect : ColorRect = $ColorRect
@onready var progress_bar : ProgressBar = $ColorRect/ProgressBar
@onready var anim_player : AnimationPlayer = $"AnimationPlayer"

var loading = false
var _loading_target_scene : String = ""


func _ready():
	visible = false # start invisible
	if progress_bar:
		progress_bar.visible = false
	print_debug("[FadeLayer] ready - visible = false")

	if not anim_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		anim_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	if Global.should_fade_in_on_load:
		print_debug("[FadeLayer] should_fade_in_on_load = true, fading in")
		fade_in()
		Global.should_fade_in_on_load = false
	else:
		print_debug("[FadeLayer] should_fade_in_on_load = false, not fading in")


# --- FADE OUT & LOAD ---
func fade_out_with_loading(target_scene: String):
	print_debug("[FadeLayer] fade_out_with_loading() START")
	visible = true
	progress_bar.visible = false
	anim_player.play("fade_out")
	
	_loading_target_scene = target_scene


# --- FADE IN ---
func fade_in():
	print_debug("[FadeLayer] fade_in() START")
	visible = true
	anim_player.play("fade_in")


# --- ANIMATION FINISHED SIGNAL ---
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fade_in":
		print_debug("[FadeLayer] fade_in() END - Visibility false")
		visible = false
	elif anim_name == "fade_out":
		if _loading_target_scene != "":
			print_debug("[FadeLayer] fade_out() END - Showing loading screen")
			_show_loading_screen(_loading_target_scene)
			_loading_target_scene = ""


# --- SHOW LOADING SCREEN ---
func _show_loading_screen(target_scene: String) -> void:
	print_debug("[FadeLayer] _show_loading_screen() START")
	progress_bar.visible = true
	await get_tree().process_frame # pozwala UI odświeżyć widoczność
	loading = true
	progress_bar.value = 0
	
	await _loading(target_scene)


# --- SIMULATE LOADING (THREAD LOAD) ---
func _loading(target_scene: String) -> void:
	var loader = ResourceLoader.load_threaded_request(target_scene)
	var progress = []

	while true:
		var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
		if progress.size() > 0:
			progress_bar.value = progress[0] * 100
		
		await get_tree().process_frame
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			print_debug("[FadeLayer] Loading complete: " + target_scene)
			var new_scene = ResourceLoader.load_threaded_get(target_scene)
			progress_bar.visible = false
			loading = false
			Global.should_fade_in_on_load = true
			get_tree().change_scene_to_packed(new_scene)
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			print_debug("[FadeLayer] Loading FAILED: " + target_scene)
			break
