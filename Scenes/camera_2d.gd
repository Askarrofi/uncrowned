extends Camera2D

@export var decay := 0.8
@export var max_offset := Vector2(30, 30)
@export var max_roll := 0.1

var trauma := 0.0
var trauma_power := 2

func _ready():
	randomize()

func _process(delta):
	if trauma > 0:
		trauma = max(trauma - decay * delta, 0.0)
		_apply_shake()
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
		rotation = 0.0

func add_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)

func _apply_shake():
	var amount = pow(trauma, trauma_power)
	
	offset.x = max_offset.x * amount * randf_range(-1.0, 1.0)
	offset.y = max_offset.y * amount * randf_range(-1.0, 1.0)
	rotation = max_roll * amount * randf_range(-1.0, 1.0)
