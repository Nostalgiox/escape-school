extends Area3D

signal note_interacted()  # Sygnał dla gracza, aby zareagował na interakcję

@export var prompt_text: String = "Naciśnij E, aby zobaczyć" 
@onready var label_3d = $Label3D  
var player_inside = false  # Zmienna śledząca, czy gracz wchodzi w obszar

func _ready():
	# Ustawiamy tekst w label 3D
	label_3d.text = prompt_text
	label_3d.visible = false  # Na początku nie pokazujemy tekstu

	# Podłączamy sygnały do wejścia/wyjścia gracza z obszaru
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _process(delta):
	
	# Ustawiamy orientację tekstu tak, aby zawsze patrzył na gracza
	if player_inside:
		var player = get_tree().get_first_node_in_group("player") 
		if player:
			label_3d.look_at(player.global_transform.origin, Vector3.UP)
			label_3d.rotate_y(deg_to_rad(180))
			label_3d.rotation.x = 0 
			label_3d.rotation.z = 0 

# Sygnał, gdy gracz wchodzi w obszar
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Gracz wszedł w obszar interakcji")
		label_3d.visible = true  # Pokazujemy tekst
		player_inside = true  # Gracz wchodzi w obszar

# Sygnał, gdy gracz wychodzi z obszaru
func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Gracz wyszedł z obszaru interakcji")
		label_3d.visible = false  # Ukrywamy tekst
		player_inside = false  # Gracz wychodzi z obszaru

# Zdarzenie, gdy gracz kliknie przycisk
func _unhandled_input(event):
	# Sprawdzamy, czy gracz jest w obszarze i czy zdarzenie to naciśnięcie klawisza
	if player_inside:
		# Jeśli to jest naciśnięcie klawisza przypisanego do akcji "interact"
		if event is InputEventKey and event.pressed:
			if Input.is_action_just_pressed("interact"):  # Sprawdzamy, czy "interact" zostało naciśnięte (czyli klawisz 'E')
				note_interacted.emit()  # Emitujemy sygnał interakcji (np. aby otworzyć kartkę)
