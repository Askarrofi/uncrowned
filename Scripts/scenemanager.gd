extends Node

var scene_history: Array[String] = []

func change_scene(target_scene_path: String) -> void:
	if get_tree().current_scene:
		scene_history.append(get_tree().current_scene.scene_file_path)
	get_tree().change_scene_to_file(target_scene_path)

func go_back() -> void:
	if scene_history.size() > 0:
		var previous_scene = scene_history.pop_back()
		get_tree().change_scene_to_file(previous_scene)
	else:
		print("Tidak ada scene sebelumnya di dalam riwayat.")
