extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func start_anim(animation: String, speed: float = 1.0):
	anim.speed_scale = speed
	anim.play(animation)
	
func stop_anim():
	anim.stop()

func anim_flip(value: bool = true):
	anim.flip_h = value
