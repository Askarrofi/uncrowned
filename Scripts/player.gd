extends CharacterBody2D

const SPEED = 500.0
const JUMP_VELOCITY = -500.0
var is_attacking = false
var is_dashing = false
const DASH_SPEED = 1200.0
const DASH_DURASI = 0.25
const LASER_SCENE = preload("res://Scenes/laser.tscn")
@onready var camera = $"../Camera2D"

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking:
		is_dashing = true
		$AnimatedSprite2D.play("dash")
		set_collision_mask_value(2, false)
		await get_tree().create_timer(DASH_DURASI).timeout
		set_collision_mask_value(2, true)
		is_dashing = false
		
	if Input.is_action_just_pressed("up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("ui_down") and not is_on_floor():
		velocity.y = 0

	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction > 0:
		$AnimatedSprite2D.flip_h = false
		$Sword.position.x = 25
	elif direction < 0:
		$AnimatedSprite2D.flip_h = true
		$Sword.position.x = -175
		
		
	if Input.is_action_just_pressed("left_click") and is_on_floor() and not is_attacking:
		is_attacking = true
		$Sword/CollisionShape2D.disabled = false
		$AnimatedSprite2D.play("attack")
		
		await $AnimatedSprite2D.animation_finished
		
		$Sword/CollisionShape2D.disabled = true
		is_attacking = false
		
				
	if Input.is_action_just_pressed("right_click") and is_on_floor() and not is_attacking:
		is_attacking = true
		$Sword/CollisionShape2D.disabled = false
		$AnimatedSprite2D.play("attack2")
		
		await $AnimatedSprite2D.animation_finished
		
		$Sword/CollisionShape2D.disabled = true
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
	
	
	if is_dashing:
		var arah_hadap = -1 if $AnimatedSprite2D.flip_h else 1
		velocity.x = arah_hadap * DASH_SPEED
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _on_sword_body_entered(body: Node2D) -> void:
	print("Hit: ", body.name)
	camera.add_trauma(0.5)
	if body.has_method("mati"): 
		body.mati()
