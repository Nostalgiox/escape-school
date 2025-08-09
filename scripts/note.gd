extends Area3D

signal note_interacted()  # Sygnał do interakcji

@export var prompt_text: String = "Naciśnij E, aby zobaczyć"  # Tekst do wyświetlenia
@onready var label_3d = $CollisionShape3D/MeshInstance3D/Label3D  # Label3D wyświetlający tekst
var player_in_range = false  # Zmienna śledząca, czy gracz wchodzi w obszar

func _ready():
	label_3d.visible = false  # Na początku nie pokazujemy tekstu
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _process(delta):
	if player_in_range:
		var player = get_tree().get_first_node_in_group("player")  # Zakładając, że gracz jest w grupie "player"
		if player:
			label_3d.look_at(player.global_transform.origin, Vector3.UP)  # Obracamy tekst, aby patrzył na gracza
			label_3d.rotation.x = 0  # Resetujemy obrót w osi X
			label_3d.rotation.z = 0  # Resetujemy obrót w osi Z

# Funkcja wywoływana, gdy gracz wchodzi w obszar interakcji
func _on_body_entered(body):
	if body.is_in_group("player"):
		label_3d.visible = true  # Pokazujemy tekst
		player_in_range = true  # Gracz wchodzi w obszar interakcji

# Funkcja wywoływana, gdy gracz wychodzi z obszaru interakcji
func _on_body_exited(body):
	if body.is_in_group("player"):
		label_3d.visible = false  # Ukrywamy tekst
		player_in_range = false  # Gracz wychodzi z obszaru interakcji

# Funkcja wywołująca interakcję po naciśnięciu klawisza
func _unhandled_input(event):
	if player_in_range and event is InputEventKey and event.pressed:
		if Input.is_action_just_pressed("interact"):  # Sprawdzamy, czy "E" zostało naciśnięte
			note_interacted.emit()  # Emitujemy sygnał interakcji (np. aby otworzyć kartkę)
