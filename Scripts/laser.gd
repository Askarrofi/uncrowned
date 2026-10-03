extends Area2D

var speed = 1000.0
var direction = Vector2.ZERO
var target = ""

@export var explode_scene: PackedScene

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _process(delta: float) -> void:
	position += direction * speed * delta

func explode() -> void:
	if explode_scene != null:
		var explosion = explode_scene.instantiate()
		explosion.global_position = self.global_position
		get_tree().current_scene.add_child(explosion)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target):
		explode()
	elif not body.is_in_group("player") and not body.is_in_group("enemy"):
		explode()
