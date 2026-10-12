extends CharacterBody2D

var posisi_awal: Vector2
@export var time_rewind_scene: PackedScene

func _ready() -> void:
	posisi_awal = global_position
	
func time_rewind() -> void:
	if time_rewind_scene != null:
		var time_rewind = time_rewind_scene.instantiate()
		get_tree().current_scene.add_child(time_rewind)

func mati() -> void:
	hide() 
	$CollisionShape2D.set_deferred("disabled", true) 
	time_rewind()
	
	await get_tree().create_timer(1.0).timeout
	
	global_position
	show()
	$CollisionShape2D.set_deferred("disabled", false)
