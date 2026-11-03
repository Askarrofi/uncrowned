extends Node2D

@export_file("*.tscn") var next_scene: String = "res://Scenes/arena.tscn"

func _ready() -> void:
	$AnimationPlayer.play("cutscene2")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(next_scene)
