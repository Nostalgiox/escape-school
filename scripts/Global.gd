extends Node

signal fov_changed(new_fow: float)

var player_position: Vector3 = Vector3.ZERO  # Przechowuje pozycję gracza między scenami

var global_numbers = []  # Globalna tablica na liczby

var previous_scene_path: String = ""

var should_fade_in_on_load = false

var mouse_sensitivity: float = 0.1

var fov: float = 75.0

var shadow_quality: int = 2  # 0 - Niskie, 1 - Średnie, 2 - Wysokie

var texture_quality: int = 2  # 0 - Niskie, 1 - Średnie, 2 - Wysokie

func set_fov(value: float) -> void:
    var v := clampf(value, 50.0, 110.0) # Przykładowy zakres FOV
    if is_equal_approx(fov, v):
        return
    fov = v
    fov_changed.emit(fov)
