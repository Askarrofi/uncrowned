extends CharacterBody2D

var posisi_awal: Vector2


func _ready() -> void:
	posisi_awal = global_position

func mati() -> void:
	hide() 
	
	$CollisionShape2D.set_deferred("disabled", true) 
	
	await get_tree().create_timer(3.0).timeout
	
	global_position
	show()
	$CollisionShape2D.set_deferred("disabled", false)
