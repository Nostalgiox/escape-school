extends Area3D

@export var animation_player: AnimationPlayer
@export var credits_label: Label

var triggered := false

func _process(delta):
	if credits_label.visible:
		credits_label.position.y -= 20 * delta


func _on_body_entered(body):
	print("COŚ WSZŁO:", body.name)

	if triggered:
		return

	if not body.is_in_group("player"):
		return

	print("TO JEST GRACZ")

	triggered = true
	animation_player.play("fade_in")
	await animation_player.animation_finished
	show_credits()


func show_credits():
	credits_label.visible = true

	var viewport = get_viewport().get_visible_rect().size
	credits_label.position = Vector2(
		(viewport.x - credits_label.size.x) / 2,
		viewport.y + credits_label.size.y
	)
