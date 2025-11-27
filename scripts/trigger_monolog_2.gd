extends Area3D

@export var monolog_lines : Array[String] = [
	"Ale tutaj jakoś dziwnie...",
	"Czuję sie nieswojo",
	"Czy któs tu był wcześniej?"
]

@export var monolog_duration : float = 2.5
@export var monolog_ui: Control


var has_been_triggered = false

func _on_body_entered(body: Node) -> void:
	if has_been_triggered:
		return
	if body.is_in_group("player"):
		has_been_triggered = true
		monolog_ui.start_monolog(monolog_lines, monolog_duration)
