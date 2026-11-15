extends CharacterBody2D
class_name BossEnemy

# === PRESERVED DARI ENEMY ASLI ===
var posisi_awal: Vector2
@export var time_rewind_scene: PackedScene
@onready var camera = $"../Camera2D"
# =================================

# === SINYAL ===
signal hp_changed(current_hp, max_hp)
signal sta_changed(current_sta, max_sta)
signal enemy_died

# === ITERASI REWIND ===
# static = nilainya bertahan walau scene di-reload (selama game belum ditutup)
static var rewind_count: int = 0
const MAX_SCALING_REWINDS = 10 # Batas iterasi yang menaikkan stat (biar tidak absurd)

## Panggil dari script lain kalau rewind dipicu di tempat lain:  BossEnemy.register_rewind()
static func register_rewind() -> void:
	rewind_count += 1

# === STAT DASAR (nilai di Inspector = stat pada iterasi ke-0) ===
@export var health_bar: TextureProgressBar
@export var max_hp: int = 100
@export var max_sta: int = 100
@export var sword_damage: int = 25
@export var laser_damage: int = 15 # Hanya berlaku jika scene laser punya variabel "damage"
## Peluang (0-1) boss bereaksi terhadap serangan player
@export_range(0.0, 1.0) var reaction_chance: float = 0.5

@export_group("Scaling per Rewind")
## +25% HP per iterasi (iterasi ke-4 = HP 2x lipat)
@export var hp_scale_per_rewind: float = 0.25
## +15% damage per iterasi
@export var damage_scale_per_rewind: float = 0.15
## +20% stamina (dan kecepatan regen) per iterasi
@export var stamina_scale_per_rewind: float = 0.20
## Otomatis tambah iterasi saat player mati (sinyal player_died)
@export var count_on_player_death: bool = true
## Reset iterasi ke 0 setelah boss dikalahkan
@export var reset_on_defeat: bool = true

var current_hp: int
var current_sta: float

# Nilai akhir setelah scaling
var rewind_level: int = 0
var sword_damage_now: int
var laser_damage_now: int
var reaction_now: float
var regen_rate: float

# === KONSTANTA ===
const SPEED = 300.0
const JUMP_VELOCITY = -500.0
const DASH_SPEED = 1200.0
const DASH_DURASI = 0.25
const LUNGE_SPEED = 250.0 # Maju sedikit saat menebas

const DASH_STAMINA_COST = 30.0
const BLOCK_DRAIN_RATE = 20.0
const STAMINA_REGEN_RATE = 50.0
const STAMINA_REGEN_DELAY = 1.0
const BLOCK_MIN_STAMINA = 20.0

const LASER_SCENE = preload("res://Scenes/laser.tscn")

# === STATE ===
var is_attacking = false
var is_dashing = false
var is_blocking = false
var is_dead = false
var stamina_regen_timer: float = 0.0

# === VARIABEL AI ===
var player: CharacterBody2D
var ai_timer: float = 0.0
var reaction_timer: float = 0.0
var jump_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var punish_timer: float = 0.0          # Jendela waktu membalas setelah player selesai menyerang
var prev_player_attacking = false
var block_timer: float = 0.0
var dash_dir: int = 1
var sword_has_hit = false
var is_recovering = false
var rewind_counted = false

var attack_range: float = 80.0
var sight_range: float = 1000.0
var retreat_range: float = 250.0


func _ready() -> void:
	_apply_rewind_scaling()

	if health_bar != null:
		hp_changed.connect(health_bar.update_health)

	current_hp = max_hp
	current_sta = float(max_sta)

	$AnimatedSprite2D.flip_h = true
	$AnimatedSprite2D.play("idle")
	posisi_awal = global_position

	player = get_parent().get_node_or_null("Player")
	_connect_player_signal()

	if has_node("Sword"):
		if has_node("Sword/CollisionShape2D"):
			$Sword/CollisionShape2D.set_deferred("disabled", true)
		if not $Sword.body_entered.is_connected(_on_sword_body_entered):
			$Sword.body_entered.connect(_on_sword_body_entered)

	hp_changed.emit(current_hp, max_hp)
	sta_changed.emit(current_sta, max_sta)

	print("Boss iterasi rewind ke-%d | HP %d | DMG %d | STA %d" % [rewind_level, max_hp, sword_damage_now, max_sta])


# === SCALING PER ITERASI REWIND ===
func _apply_rewind_scaling() -> void:
	rewind_level = mini(rewind_count, MAX_SCALING_REWINDS)
	var n := float(rewind_level)

	max_hp = int(round(max_hp * (1.0 + hp_scale_per_rewind * n)))
	max_sta = int(round(max_sta * (1.0 + stamina_scale_per_rewind * n)))
	sword_damage_now = int(round(sword_damage * (1.0 + damage_scale_per_rewind * n)))
	laser_damage_now = int(round(laser_damage * (1.0 + damage_scale_per_rewind * n)))
	regen_rate = STAMINA_REGEN_RATE * (1.0 + stamina_scale_per_rewind * n)
	reaction_now = minf(reaction_chance + 0.06 * n, 0.95)


func _connect_player_signal() -> void:
	if not count_on_player_death or player == null:
		return
	if player.has_signal("player_died") and not player.is_connected("player_died", _on_player_died):
		player.connect("player_died", _on_player_died)


func _on_player_died() -> void:
	if is_dead or rewind_counted:
		return
	rewind_counted = true
	rewind_count += 1


# === FASE BOSS (makin parah saat HP menipis) ===
func _phase() -> int:
	var ratio := float(current_hp) / float(max_hp)
	if ratio <= 0.3:
		return 3
	if ratio <= 0.6:
		return 2
	return 1


func _speed() -> float:
	match _phase():
		2: return SPEED * 1.15
		3: return SPEED * 1.3
	return SPEED


# Pengali jeda berpikir: makin kecil = makin agresif
func _think_scale() -> float:
	var s: float = 1.0 - 0.04 * rewind_level
	match _phase():
		2: s *= 0.8
		3: s *= 0.6
	return maxf(s, 0.35)


# Jumlah tebasan maksimum dalam 1 kombo
func _max_combo() -> int:
	var c := 1
	if rewind_level >= 3:
		c += 1
	if rewind_level >= 7:
		c += 1
	if _phase() >= 2:
		c += 1
	return mini(c, 4)


func _physics_process(delta: float) -> void:
	# 1. GRAVITASI
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	# 2. REGEN STAMINA & TIMER
	_regen_stamina(delta)
	ai_timer = maxf(ai_timer - delta, 0.0)
	reaction_timer = maxf(reaction_timer - delta, 0.0)
	jump_cooldown = maxf(jump_cooldown - delta, 0.0)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	punish_timer = maxf(punish_timer - delta, 0.0)

	# 3. KEPUTUSAN AI
	var direction := 0
	_validate_player()

	if player != null:
		_track_player_attack()

		var distance := global_position.distance_to(player.global_position)

		if distance < sight_range:
			var dx: float = player.global_position.x - global_position.x
			var dy: float = player.global_position.y - global_position.y
			var adx: float = abs(dx)
			var ady: float = abs(dy)
			var dir_to_player: int = int(sign(dx)) if adx > 12.0 else 0

			if not is_attacking and not is_dashing and dir_to_player != 0:
				_face(dir_to_player)

			var can_act := not is_attacking and not is_dashing and not is_blocking

			if can_act:
				var in_melee := adx <= attack_range and ady < 150.0

				# Hindari laser yang datang & bereaksi pada tebasan player
				_dodge_incoming_laser()
				if not is_blocking and not is_dashing and not is_attacking:
					_react_to_player(adx, ady)

				if not is_blocking and not is_attacking and not is_dashing:
					var player_blocking := _player_is_blocking()

					if punish_timer > 0.0 and not player_blocking and adx < 260.0 and ady < 150.0:
						# Player baru selesai menyerang -> langsung balas
						if in_melee:
							punish_timer = 0.0
							ai_timer = 0.7 * _think_scale()
							_ai_melee_attack()
						else:
							direction = dir_to_player
					elif in_melee:
						direction = 0
						if ai_timer <= 0.0:
							_ai_decide_close_combat(player_blocking)
					else:
						direction = dir_to_player

						# Stamina rendah -> mundur sampai pulih (hysteresis)
						if current_sta < 15.0:
							is_recovering = true
						elif current_sta >= 50.0:
							is_recovering = false
						if is_recovering and distance < retreat_range:
							direction = -dir_to_player

						# Loncat: player di atas, atau terhalang tembok
						if is_on_floor() and jump_cooldown <= 0.0:
							if dy < -120.0 and adx < 250.0:
								_ai_jump()
							elif is_on_wall() and direction != 0:
								_ai_jump()

						if ai_timer <= 0.0:
							_ai_decide_ranged_combat(adx, ady)

	# 4. EKSEKUSI PERGERAKAN
	if is_dashing:
		velocity.x = dash_dir * DASH_SPEED
	elif is_blocking:
		velocity.x = 0
		use_stamina(BLOCK_DRAIN_RATE * delta)
		block_timer -= delta
		if block_timer <= 0.0 or current_sta <= 0.0:
			is_blocking = false
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0, _speed() * 6.0 * delta)
	else:
		if direction != 0:
			velocity.x = direction * _speed()
		else:
			velocity.x = move_toward(velocity.x, 0, _speed())

	# 5. ANIMASI
	_update_animation(direction)

	move_and_slide()


# === HELPER ===
func _validate_player() -> void:
	if player != null and not is_instance_valid(player):
		player = null
	if player == null:
		player = get_parent().get_node_or_null("Player")
		if player != null:
			rewind_counted = false
			_connect_player_signal()


func _player_valid() -> bool:
	return player != null and is_instance_valid(player)


func _regen_stamina(delta: float) -> void:
	if not is_dashing and not is_blocking:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		elif current_sta < max_sta:
			current_sta += regen_rate * delta
			current_sta = clamp(current_sta, 0.0, float(max_sta))
			sta_changed.emit(current_sta, max_sta)


func _face(dir: int) -> void:
	if dir > 0:
		$AnimatedSprite2D.flip_h = false
		if has_node("Sword"): $Sword.position.x = 25
	elif dir < 0:
		$AnimatedSprite2D.flip_h = true
		if has_node("Sword"): $Sword.position.x = -175


func _face_player() -> void:
	if _player_valid():
		var d := int(sign(player.global_position.x - global_position.x))
		if d != 0:
			_face(d)


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
	return _player_valid() and player.get("is_attacking") == true


func _player_is_blocking() -> bool:
	return _player_valid() and player.get("is_blocking") == true


func _player_in_melee() -> bool:
	if not _player_valid():
		return false
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = abs(player.global_position.y - global_position.y)
	return dx <= attack_range * 1.3 and dy < 150.0


# Deteksi player selesai menyerang (tebasan/laser meleset) -> buka jendela balasan
func _track_player_attack() -> void:
	var now := _player_is_attacking()
	if prev_player_attacking and not now:
		punish_timer = 0.6
	prev_player_attacking = now


# === FUNGSI KEPUTUSAN AI ===
# Cari laser yang mengarah ke boss lalu loncat tepat waktu
func _dodge_incoming_laser() -> void:
	if dodge_cooldown > 0.0 or not is_on_floor() or is_blocking:
		return
	for n in get_parent().get_children():
		if n == self or n == player or not (n is Node2D):
			continue
		if n.scene_file_path != LASER_SCENE.resource_path:
			continue
		var d = n.get("direction")
		if typeof(d) != TYPE_VECTOR2:
			continue
		var rel: float = global_position.x - n.global_position.x
		if d.x * rel <= 0.0:
			continue # laser menjauh (milik boss sendiri)
		if abs(rel) > 350.0 or abs(n.global_position.y - global_position.y) > 140.0:
			continue
		dodge_cooldown = 0.6
		if randf() < minf(reaction_now + 0.25, 0.95):
			_ai_jump()
		return


func _react_to_player(adx: float, ady: float) -> void:
	if reaction_timer > 0.0 or not _player_is_attacking():
		return
	if adx > attack_range * 1.6 or ady > 150.0:
		return # Jauh: ditangani _dodge_incoming_laser
	reaction_timer = 0.7

	if randf() > reaction_now:
		return

	if randf() < 0.6 and current_sta >= BLOCK_MIN_STAMINA:
		_ai_block(0.7)
	elif current_sta >= DASH_STAMINA_COST:
		_ai_dash(-_facing()) # Mundur menghindari tebasan
	elif current_sta >= BLOCK_MIN_STAMINA:
		_ai_block(0.7)


func _ai_decide_close_combat(player_blocking: bool) -> void:
	var t := _think_scale()

	if player_blocking:
		# Jangan buang tenaga memukul lawan yang sedang block; tunggu stamina-nya habis
		var p_sta = player.get("current_sta")
		if p_sta != null and p_sta < 25.0:
			ai_timer = 0.5 * t
			_ai_melee_attack()
		else:
			ai_timer = 0.3 * t
		return

	var aksi := randi() % 100
	ai_timer = 0.9 * t

	if aksi < 60:
		_ai_melee_attack()
	elif aksi < 72 and current_sta >= BLOCK_MIN_STAMINA:
		_ai_block(0.8)
	elif aksi < 85 and current_sta >= DASH_STAMINA_COST:
		_ai_dash(-_facing())
	else:
		ai_timer = 0.3 * t


func _ai_decide_ranged_combat(adx: float, ady: float) -> void:
	var t := _think_scale()
	ai_timer = 1.2 * t
	var aksi := randi() % 100
	var dash_chance := 10 + (_phase() - 1) * 10 # 10% / 20% / 30%

	# Laser hanya ditembak kalau player sejajar (laser lurus horizontal)
	if ady < 110.0 and adx > attack_range * 2.5 and aksi < 40:
		_ai_shoot_laser()
	elif adx > 380.0 and current_sta >= 60.0 and aksi < 40 + dash_chance:
		_ai_dash(_facing())
	elif aksi < 40 + dash_chance + 10:
		_ai_jump()
	else:
		ai_timer = 0.4 * t


# === AKSI AI ===
func _ai_jump() -> void:
	if not is_on_floor() or is_blocking:
		return
	velocity.y = JUMP_VELOCITY
	jump_cooldown = 1.0


func _ai_melee_attack() -> void:
	if not is_on_floor() or is_attacking or is_blocking or is_dashing:
		return
	is_attacking = true
	var swings := randi_range(1, _max_combo())
	for i in swings:
		if is_dead:
			break
		if i > 0:
			# Kombo lanjutan hanya jika player masih dalam jangkauan
			if not _player_in_melee():
				break
			_face_player()
		await _swing_once()
	is_attacking = false


func _swing_once() -> void:
	sword_has_hit = false
	if _player_valid() and abs(player.global_position.x - global_position.x) > 45.0:
		velocity.x = _facing() * LUNGE_SPEED
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", false)
	$AnimatedSprite2D.play("attack")
	await $AnimatedSprite2D.animation_finished
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", true)


func _ai_shoot_laser() -> void:
	if not is_on_floor() or is_attacking or is_blocking or is_dashing:
		return
	is_attacking = true
	var shots := 1 + (1 if _phase() >= 2 else 0) + (1 if _phase() >= 3 else 0)

	for i in shots:
		if is_dead:
			break
		_face_player()
		$AnimatedSprite2D.play("attack2")

		var laser = LASER_SCENE.instantiate()
		var dir = _facing()
		laser.direction = Vector2(dir, 0)
		if "damage" in laser:
			laser.damage = laser_damage_now
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
	$AnimatedSprite2D.play("attack2")


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
	if is_dead or body == self or sword_has_hit:
		return
	if body.has_method("take_damage"):
		sword_has_hit = true
		if camera != null and camera.has_method("add_trauma"):
			camera.add_trauma(0.5)
		body.take_damage(sword_damage_now)


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
		# Serangan diblok -> sering langsung membalas (riposte)
		if randf() < minf(reaction_now + 0.2, 0.9):
			is_blocking = false
			ai_timer = 0.0
			punish_timer = 0.5
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

	is_attacking = false
	is_dashing = false
	is_blocking = false
	if has_node("Sword/CollisionShape2D"):
		$Sword/CollisionShape2D.set_deferred("disabled", true)

	if reset_on_defeat:
		rewind_count = 0

	hide()
	$CollisionShape2D.set_deferred("disabled", true)

	await get_tree().create_timer(1.0).timeout
	FT.change_scene("res://Scenes/cutscene2.tscn", 3)
