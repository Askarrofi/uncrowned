extends Node2D

func _ready() -> void:
	$AnimationPlayer.play("cutscene")
	await $AnimationPlayer.animation_finished
	SM.change_scene("res://Scenes/arena.tscn")
