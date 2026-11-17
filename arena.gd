extends Node2D


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
