extends CSGBox3D

@export var min_value: int = 1    # Minimalna wartość liczby
@export var max_value: int = 100  # Maksymalna wartość liczby
@onready var numbers = Global.global_numbers

func _ready():
	numbers.clear()  # Czyścimy tablicę przed generowaniem nowych wartości

	var labels = []  # Lista do przechowania referencji do Label3D

	for i in range(1, 5):  # Dla każdego Label3D
		var label_name = "Label" + str(i)
		if has_node(label_name):
			var label = get_node(label_name)
			labels.append(label)  # Dodajemy Label3D do listy

			# Generowanie losowej liczby
			var random_number = randi_range(min_value, max_value)
			label.text = str(random_number)

			# Zapisujemy liczbę do tablicy globalnej
			numbers.append(random_number)

			# Losowa pozycja:
			var random_x = randf_range(-4.0, 4.0)  # X: od -4 do 4
			var fixed_y = -0.51  # Stała wartość dla Y
			var random_z = randf_range(-4.0, -1.0)  # Z: od -4 do -1
			label.position = Vector3(random_x, fixed_y, random_z)

			# Ustawienie rotacji (X = 90°, Y = 180°)
			label.rotation_degrees = Vector3(90, 180, 0)

	# Przypisujemy rosnącą wielkość (scale) dla każdego Label3D
	var min_scale = 1.0  # Minimalna skala
	var max_scale = 3.0  # Maksymalna skala
	var step = (max_scale - min_scale) / (labels.size() - 1)  # Obliczamy różnicę w skali

	for i in range(labels.size()):
		var scale_value = min_scale + (step * i)  # Rosnąca wielkość dla kolejnych indeksów
		labels[i].scale = Vector3(scale_value, scale_value, 1)  # Przypisujemy skalę
