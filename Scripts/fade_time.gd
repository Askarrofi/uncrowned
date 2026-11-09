extends CanvasLayer

var rect: ColorRect
var changing := false
var rewind: Node
const  time_rewind = preload("res://Scenes/time_rewind.tscn")


func _ready() -> void:
	layer = 100   # selalu di atas semua UI
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	
	rewind = time_rewind.instantiate()
	rect.add_child(rewind)
	add_child(rect)

func change_scene(path: String, duration: float = 0.5) -> void:
	if changing:
		return
	changing = true
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # blokir klik saat transisi

	var t_out = create_tween()
	t_out.tween_property(rect, "modulate:a", 1.0, duration)
	await t_out.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade in (layar terang lagi)
	var t_in = create_tween()
	t_in.tween_property(rect, "modulate:a", 0.0, duration)
	await t_in.finished

	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	changing = false
