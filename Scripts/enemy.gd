extends CharacterBody2D

# === PRESERVED DARI ENEMY ASLI ===
var posisi_awal: Vector2
@export var time_rewind_scene: PackedScene
@onready var camera = $"../Camera2D"
# =================================

# === SINYAL ===
signal hp_changed(current_hp, max_hp)
signal sta_changed(current_sta, max_sta)
signal enemy_died

# === STAT ===
@export var max_hp: int = 100
@export var max_sta: int = 100
@export var sword_damage: int = 15
## Peluang (0-1) musuh bereaksi terhadap serangan player (block / loncat menghindar)
@export_range(0.0, 1.0) var reaction_chance: float = 0.5
var current_hp: int
var current_sta: float

# === KONSTANTA (disamakan dengan player, kecuali SPEED) ===
const SPEED = 300.0 # Lebih lambat dari player (500), tapi tidak sepelan sebelumnya
const JUMP_VELOCITY = -500.0
const DASH_SPEED = 1200.0
const DASH_DURASI = 0.25

const DASH_STAMINA_COST = 30.0
const BLOCK_DRAIN_RATE = 20.0
const STAMINA_REGEN_RATE = 50.0
const STAMINA_REGEN_DELAY = 1.0
const BLOCK_MIN_STAMINA = 20.0

const LASER_SCENE = preload("res://Scenes/laser.tscn")

# === STATE (sama seperti player) ===
var is_attacking = false
var is_dashing = false
var is_blocking = false
var is_dead = false
var stamina_regen_timer: float = 0.0

# === VARIABEL AI ===
var player: CharacterBody2D
var ai_timer: float = 0.0        # Jeda antar keputusan serangan
var reaction_timer: float = 0.0  # Jeda antar reaksi terhadap serangan player
var jump_cooldown: float = 0.0   # Jeda antar loncatan
var block_timer: float = 0.0     # Sisa durasi block
var dash_dir: int = 1            # Arah dash (bisa maju atau mundur)
var sword_has_hit = false        # 1 tebasan = 1x damage
var is_recovering = false        # Mundur menunggu stamina pulih

var attack_range: float = 80.0   # Jarak tebasan pedang
var sight_range: float = 500.0   # Jarak pandang musuh melihat player
var retreat_range: float = 250.0 # Jarak mundur saat stamina rendah


func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	posisi_awal = global_position
	current_hp = max_hp
	current_sta = float(max_sta)

	# Mencari node Player otomatis di dalam scene untuk dijadikan target
	player = get_parent().get_node_or_null("Player")

	if has_node("Sword"):
		if has_node("Sword/CollisionShape2D"):
			$Sword/CollisionShape2D.set_deferred("disabled", true)
		# Sambungkan sinyal pedang lewat kode (aman jika sudah tersambung dari editor)
		if not $Sword.body_entered.is_connected(_on_sword_body_entered):
			$Sword.body_entered.connect(_on_sword_body_entered)

	hp_changed.emit(current_hp, max_hp)
	sta_changed.emit(current_sta, max_sta)


func _physics_process(delta: float) -> void:
	# 1. GRAVITASI
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Saat mati: diam saja sampai respawn
	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	# 2. REGEN STAMINA & TIMER
	_regen_stamina(delta)
	ai_timer = max(ai_timer - delta, 0.0)
	reaction_timer = max(reaction_timer - delta, 0.0)
	jump_cooldown = max(jump_cooldown - delta, 0.0)

	# 3. KEPUTUSAN AI (pengganti Input player)
	var direction := 0
	_validate_player()

	if player != null:
		var distance = global_position.distance_to(player.global_position)

		if distance < sight_range:
			var dx = player.global_position.x - global_position.x
			var dy = player.global_position.y - global_position.y
			# Deadzone: kalau player tepat di atas/bawah, jangan bolak-balik arah tiap frame
			var dir_to_player = int(sign(dx)) if abs(dx) > 12.0 else 0

			# Hadapkan badan & pedang ke player (tidak saat menebas / dash)
			if not is_attacking and not is_dashing and dir_to_player != 0:
				_face(dir_to_player)

			var can_act = not is_attacking and not is_dashing and not is_blocking

			if can_act:
				var in_melee = abs(dx) <= attack_range and abs(dy) < 150.0

				# Reaksi terhadap serangan player (block / loncat)
				_react_to_player(abs(dx), in_melee)

				if not is_blocking and not is_attacking and not is_dashing:
					if in_melee:
						direction = 0
						if ai_timer <= 0:
							_ai_decide_close_combat()
					else:
						direction = dir_to_player

						# Stamina rendah -> mundur sampai stamina pulih (hysteresis: tidak maju-mundur)
						if current_sta < 15.0:
							is_recovering = true
						elif current_sta >= 50.0:
							is_recovering = false
						if is_recovering and distance < retreat_range:
							direction = -dir_to_player

						# Loncat: player di atas, atau terhalang tembok
						if is_on_floor() and jump_cooldown <= 0:
							if dy < -120.0 and abs(dx) < 250.0:
								_ai_jump()
							elif is_on_wall() and direction != 0:
								_ai_jump()

						if ai_timer <= 0:
							_ai_decide_ranged_combat(abs(dx))

	# 4. EKSEKUSI PERGERAKAN
	if is_dashing:
		velocity.x = dash_dir * DASH_SPEED
	elif is_blocking:
		velocity.x = 0 # Tidak bisa jalan saat block
		use_stamina(BLOCK_DRAIN_RATE * delta)
		block_timer -= delta
		if block_timer <= 0 or current_sta <= 0:
			is_blocking = false
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# 5. ANIMASI (tidak menimpa attack / block / dash)
	_update_animation(direction)

	move_and_slide()


# === HELPER ===
func _validate_player() -> void:
	# Player bisa di-queue_free saat mati; jangan akses referensi yang sudah hilang
	if player != null and not is_instance_valid(player):
		player = null
	if player == null:
		player = get_parent().get_node_or_null("Player")


func _regen_stamina(delta: float) -> void:
	if not is_dashing and not is_blocking:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		elif current_sta < max_sta:
			current_sta += STAMINA_REGEN_RATE * delta
			current_sta = clamp(current_sta, 0.0, float(max_sta))
			sta_changed.emit(current_sta, max_sta)


func _face(dir: int) -> void:
	if dir > 0:
		$AnimatedSprite2D.flip_h = false
		if has_node("Sword"): $Sword.position.x = 25
	elif dir < 0:
		$AnimatedSprite2D.flip_h = true
		if has_node("Sword"): $Sword.position.x = -175


func _facing() -> int:
	return -1 if $AnimatedSprite2D.flip_h else 1


func _update_animation(direction: int) -> void:
	if is_attacking or is_blocking or is_dashing:
		return
	if not is_on_floor():
		$AnimatedSprite2D.play("jump")
	elif direction != 0:
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")


func _player_is_attacking() -> bool:
	return player != null and player.get("is_attacking") == true


# === FUNGSI KEPUTUSAN AI ===
func _react_to_player(horizontal_distance: float, in_melee: bool) -> void:
	if reaction_timer > 0 or not _player_is_attacking():
		return
	reaction_timer = 0.8 # Jangan bereaksi tiap frame

	if randf() > reaction_chance:
		return

	if horizontal_distance <= attack_range * 1.5:
		# Player menebas dari dekat -> block
		if current_sta >= BLOCK_MIN_STAMINA:
			_ai_block(0.7)
	elif horizontal_distance < sight_range and is_on_floor():
		# Player menembak laser dari jauh -> loncat menghindar
		_ai_jump()


func _ai_decide_close_combat() -> void:
	var aksi = randi() % 100
	ai_timer = 1.0 # Butuh 1 detik sebelum bisa memutuskan lagi

	if aksi < 50: # 50% menebas
		_ai_melee_attack()
	elif aksi < 75 and current_sta >= BLOCK_MIN_STAMINA: # 25% block
		_ai_block(1.0)
	elif current_sta >= DASH_STAMINA_COST: # sisanya dash mundur menjaga jarak
		_ai_dash(-_facing())


func _ai_decide_ranged_combat(horizontal_distance: float) -> void:
	var aksi = randi() % 100
	ai_timer = 1.5

	if aksi < 40 and horizontal_distance > attack_range * 2.0: # 40% tembak laser
		_ai_shoot_laser()
	elif aksi < 50 and horizontal_distance > 250.0 and current_sta >= 60.0: # 10% dash maju (hanya dari jauh)
		_ai_dash(_facing())
	elif aksi < 60: # 10% loncat
		_ai_jump()
	else:
		ai_timer = 0.5


# === AKSI AI (kemampuan sama seperti player) ===
func _ai_jump() -> void:
	if not is_on_floor() or is_blocking:
		return
	velocity.y = JUMP_VELOCITY
	jump_cooldown = 1.0


func _ai_melee_attack() -> void:
	if not is_on_floor() or is_attacking or is_blocking or is_dashing:
		return
	is_attacking = true
	sword_has_hit = false
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", false)
	$AnimatedSprite2D.play("attack")
	await $AnimatedSprite2D.animation_finished
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", true)
	is_attacking = false


func _ai_shoot_laser() -> void:
	if not is_on_floor() or is_attacking or is_blocking or is_dashing:
		return
	is_attacking = true
	$AnimatedSprite2D.play("attack2")

	var laser = LASER_SCENE.instantiate()
	var dir = _facing()
	laser.direction = Vector2(dir, 0)
	laser.global_position = self.global_position + Vector2(dir * 70, 50)
	get_parent().add_child(laser)

	await $AnimatedSprite2D.animation_finished
	is_attacking = false


func _ai_block(duration: float) -> void:
	if not is_on_floor() or is_attacking or is_dashing or current_sta <= 0:
		return
	is_blocking = true
	block_timer = duration
	velocity.x = 0
	$AnimatedSprite2D.play("attack2") # Animasi block (sama seperti player)


func _ai_dash(dir: int) -> void:
	if is_dashing or is_attacking or is_blocking or current_sta < DASH_STAMINA_COST:
		return
	use_stamina(DASH_STAMINA_COST)
	dash_dir = dir
	is_dashing = true
	$AnimatedSprite2D.play("dash")
	# Tembus HANYA player saat dash (lantai & tembok tetap solid)
	var dash_target = player
	if dash_target != null and is_instance_valid(dash_target):
		add_collision_exception_with(dash_target)
	await get_tree().create_timer(DASH_DURASI).timeout
	if dash_target != null and is_instance_valid(dash_target):
		remove_collision_exception_with(dash_target)
	is_dashing = false


# === DAMAGE KE PLAYER ===
func _on_sword_body_entered(body: Node2D) -> void:
	print("Hit: ", body.name)
	camera.add_trauma(0.5)
	if body.has_method("take_damage"): 
		body.take_damage(10)


# === SISTEM PENGURANGAN STAT ===
func use_stamina(amount: float) -> void:
	current_sta -= amount
	current_sta = clamp(current_sta, 0.0, float(max_sta))
	sta_changed.emit(current_sta, max_sta)
	stamina_regen_timer = STAMINA_REGEN_DELAY


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if is_blocking:
		print("Seranganmu diblok oleh musuh!")
		return

	current_hp -= amount
	current_hp = clamp(current_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)

	$AnimatedSprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color.WHITE

	if current_hp <= 0:
		mati()


# === FUNGSI MATI ASLI MUSUH ===
func time_rewind() -> void:
	if time_rewind_scene != null:
		var time_rewind = time_rewind_scene.instantiate()
		get_tree().current_scene.add_child(time_rewind)


func mati() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit()

	# Hentikan semua aksi yang sedang berjalan
	is_attacking = false
	is_dashing = false
	is_blocking = false
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", true)

	hide()
	$CollisionShape2D.set_deferred("disabled", true)

	await get_tree().create_timer(1.0).timeout
	FT.change_scene("res://Scenes/cutscene2.tscn", 3)
	
	
	# Respawn
	#global_position = posisi_awal
	#velocity = Vector2.ZERO
	#current_hp = max_hp
	#current_sta = float(max_sta)
	#ai_timer = 1.0
	#hp_changed.emit(current_hp, max_hp)
	#sta_changed.emit(current_sta, max_sta)
	#show()
	#$CollisionShape2D.set_deferred("disabled", false)
	#is_dead = false
