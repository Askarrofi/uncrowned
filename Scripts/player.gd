extends CharacterBody2D

# === TAMBAHAN SISTEM HP & STAMINA (Sinyal) ===
signal hp_changed(current_hp, max_hp)
signal player_died
signal sta_changed(current_sta, max_sta)
# ===================================================

const SPEED = 500.0
const JUMP_VELOCITY = -500.0
var is_attacking = false
var is_dashing = false

# === TAMBAHAN SISTEM STAMINA (State & Biaya) ===
var is_blocking = false
var stamina_regen_timer: float = 0.0
const DASH_STAMINA_COST = 30.0    # Biaya stamina untuk 1x dash
const BLOCK_DRAIN_RATE = 20.0     # Stamina berkurang per detik saat nahan block
const STAMINA_REGEN_RATE = 50.0   # Kecepatan regen stamina per detik
const STAMINA_REGEN_DELAY = 1.0   # Jeda 1 detik sebelum mulai regen
# =================================================

const DASH_SPEED = 1200.0
const DASH_DURASI = 0.25
const LASER_SCENE = preload("res://Scenes/laser.tscn")
@onready var camera = $"../Camera2D"

# === TAMBAHAN SISTEM HP & STAMINA (Variabel) ===
@export var max_hp: int = 100
var current_hp: int
@onready var health_bar: TextureProgressBar = $CanvasLayer/HealthBar

@export var max_sta: int = 100
# Menggunakan float agar pengurangan tahan block & regen jadi sangat mulus (smooth)
var current_sta: float 
@onready var stamina_bar: TextureProgressBar = $CanvasLayer/StaminaBar
# ===========================================

func _ready():
	hp_changed.connect(health_bar.update_health)
	# Pastikan script StaminaBar memiliki fungsi update_stamina(current, max)
	sta_changed.connect(stamina_bar.update_stamina) 
	
	current_hp = max_hp
	current_sta = float(max_sta)
	
	hp_changed.emit(current_hp, max_hp) 
	sta_changed.emit(current_sta, max_sta)

func _physics_process(delta: float) -> void:
	# === SISTEM REGENERASI STAMINA ===
	# Hanya regen jika tidak sedang dash dan tidak sedang block
	if not is_dashing and not is_blocking:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		elif current_sta < max_sta:
			current_sta += STAMINA_REGEN_RATE * delta
			current_sta = clamp(current_sta, 0.0, float(max_sta))
			sta_changed.emit(current_sta, max_sta)
	# ==================================

	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# === MODIFIKASI DASH (Hanya bisa dash jika stamina cukup) ===
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and not is_blocking:
		if current_sta >= DASH_STAMINA_COST:
			use_stamina(DASH_STAMINA_COST) # Kurangi stamina
			is_dashing = true
			$AnimatedSprite2D.play("dash")
			set_collision_mask_value(2, false)
			await get_tree().create_timer(DASH_DURASI).timeout
			set_collision_mask_value(2, true)
			is_dashing = false
	# ==============================================================
		
	if Input.is_action_just_pressed("up") and is_on_floor() and not is_blocking:
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
		
	if Input.is_action_just_pressed("left_click") and is_on_floor() and not is_attacking and not is_blocking:
		is_attacking = true
		$Sword/CollisionShape2D.disabled = false
		$AnimatedSprite2D.play("attack")
		await $AnimatedSprite2D.animation_finished
		$Sword/CollisionShape2D.disabled = true
		is_attacking = false
		
	# === LOGIKA BLOCK HOLD (Menggantikan right_click attack2 lama) ===
	if Input.is_action_pressed("right_click") and is_on_floor() and not is_attacking and not is_dashing:
		if current_sta > 0:
			is_blocking = true
			velocity.x = 0 # Menghentikan player saat nahan block
			$AnimatedSprite2D.play("attack2") # Pastikan kamu punya animasi bernama "block"
			use_stamina(BLOCK_DRAIN_RATE * delta) # Kurangi stamina pelan-pelan
		else:
			is_blocking = false # Jika stamina habis, paksa berhenti block
	else:
		is_blocking = false
	# =================================================================
		
	if Input.is_action_just_pressed("Fire") and is_on_floor() and not is_attacking and not is_blocking:
		is_attacking = true
		$AnimatedSprite2D.play("attack2")
		
		var laser = LASER_SCENE.instantiate()
		var dir = -1 if $AnimatedSprite2D.flip_h else 1
		laser.direction = Vector2(dir, 0)
		laser.global_position = self.global_position + Vector2(dir * 70, 50)
		
		get_parent().add_child(laser)
		await $AnimatedSprite2D.animation_finished
		is_attacking = false
		
	# Mencegah animasi lain menimpa animasi block
	if not is_attacking and not is_blocking:
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
		if direction and not is_blocking: # Tidak bisa jalan saat nge-block
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _on_sword_body_entered(body: Node2D) -> void:
	print("Hit: ", body.name)
	camera.add_trauma(0.5)
	if body.has_method("mati"): 
		body.mati()

func take_damage(amount: int):
	# === LOGIKA REDUKSI DAMAGE SAAT BLOCK ===
	if is_blocking:
		# Jika sedang nge-block, damage diabaikan atau bisa dikurangi (contoh di bawah damage diabaikan)
		# Atau ubah jadi: amount = amount / 2 (damage setengah)
		print("Serangan diblok!")
		return 
	# ========================================

	current_hp -= amount
	current_hp = clamp(current_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	
	$AnimatedSprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color.WHITE
	
	if current_hp <= 0:
		die()
		
# === MELENGKAPI FUNGSI STAMINA ===
func use_stamina(amount: float):
	current_sta -= amount
	current_sta = clamp(current_sta, 0.0, float(max_sta))
	
	# Update UI Bar
	sta_changed.emit(current_sta, max_sta)
	
	# Reset timer ke 1 detik agar tidak langsung regen saat sedang dipakai
	stamina_regen_timer = STAMINA_REGEN_DELAY 
# =================================

func heal(amount: int):
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func die():
	player_died.emit()
	print("Player telah mati!")
	queue_free()
