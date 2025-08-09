extends SubViewport

@export var min_size: int = 0.2  # Minimalny rozmiar czcionki (3D)
@export var max_size: int = 1.0  # Maksymalny rozmiar czcionki (3D)

func _ready():
	self.render_target_update_mode = SubViewport.UPDATE_ONCE  # Aktualizacja tylko raz

	for i in range(1, 5):  # 4 cyfry
		var label_path = "Label" + str(i)  # Nowe nazwy Label3D
		if has_node(label_path):  # Sprawdź, czy Label3D istnieje
			var label = get_node(label_path)
			label.text = str(randi() % 10)  # Losowa cyfra 0-9
			label.scale = Vector3(randi_range(min_size, max_size), randi_range(min_size, max_size), 1)  # Skalowanie 3D
			label.position = Vector3(randi_range(-1, 1), randi_range(-1, 1), 0)  # Losowa pozycja na ścianie
		else:
			print("Błąd: Nie znaleziono", label_path)
