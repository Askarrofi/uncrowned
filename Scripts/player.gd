extends CharacterBody2D

const SPEED = 500.0
const JUMP_VELOCITY = -500.0
var is_attacking = false
const LASER_SCENE = preload("res://Scenes/laser.tscn")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# Handle jump.
	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("ui_down") and not is_on_floor():
		velocity.y = 0

	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction > 0:
		$AnimatedSprite2D.flip_h = false
	elif direction < 0:
		$AnimatedSprite2D.flip_h = true
		
	if Input.is_action_just_pressed("left_click") and is_on_floor() and not is_attacking:
		is_attacking = true
		$AnimatedSprite2D.play("attack")
		await $AnimatedSprite2D.animation_finished
		is_attacking = false
		
	if Input.is_action_just_pressed("right_click") and is_on_floor() and not is_attacking:
		is_attacking = true
		$AnimatedSprite2D.play("attack2")
		await $AnimatedSprite2D.animation_finished
		is_attacking = false
		
	if Input.is_action_just_pressed("Fire") and is_on_floor() and not is_attacking:
		is_attacking = true
		$AnimatedSprite2D.play("attack2")
		
		var laser = LASER_SCENE.instantiate()
		var dir = -1 if $AnimatedSprite2D.flip_h else 1
		laser.direction = Vector2(dir, 0)
		laser.global_position = self.global_position + Vector2(dir * 70, 50)
		
		get_parent().add_child(laser)
		await $AnimatedSprite2D.animation_finished
		is_attacking = false
		
	if not is_attacking:
		if not is_on_floor():
			$AnimatedSprite2D.play("jump")
		else:
			if direction != 0:
				$AnimatedSprite2D.play("run")
			else:
				$AnimatedSprite2D.play("idle")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _on_duri_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		get_tree().reload_current_scene()
