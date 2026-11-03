extends ColorRect

func _process(_delta: float) -> void:
	var cam := get_parent() as Camera2D
	var s := get_viewport_rect().size / cam.zoom
	size = s
	position = -s / 2.0
