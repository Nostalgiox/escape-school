extends Label

func _process(_delta):
	text = "Aktualne FPS: %d" % Engine.get_frames_per_second()
