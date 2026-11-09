extends Node2D

func _ready():
	await get_tree().create_timer(3.0).timeout
	SM.change_scene("res://Scenes/mainmenu.tscn")
