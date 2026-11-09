extends Node2D

func _ready() -> void:
	$AnimationPlayer.play("cutscene2")
	await $AnimationPlayer.animation_finished
	SM.change_scene("res://Scenes/arena.tscn")
