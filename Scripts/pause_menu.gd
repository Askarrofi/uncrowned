extends CanvasLayer

@onready var resume_button = $CenterContainer/VBoxContainer/ResumeButton
@onready var mainmenu_button = $CenterContainer/VBoxContainer/MainMenu

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(resume)
	mainmenu_button.pressed.connect(mainmenu)

func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	var paused = not get_tree().paused
	get_tree().paused = paused
	visible = paused

func resume():
	get_tree().paused = false
	visible = false

func mainmenu():
	get_tree().paused = false
	FD.change_scene("res://Scenes/mainmenu.tscn")
