extends AnimatedSprite2D

var _anim_done := false
var _audio_done := false

func _ready():
	play("default")
	$Splash.finished.connect(_on_splash_finished)
	$Splash.play()

func _on_animation_finished():
	_anim_done = true
	hide()
	_try_free()

func _on_splash_finished():
	_audio_done = true
	_try_free()

func _try_free():
	if _anim_done and _audio_done:
		queue_free()
