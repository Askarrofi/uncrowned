extends Button


func _ready():
	self.text = "START GAME"
	
	self.add_theme_color_override("font_hover_color", Color.YELLOW)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("e74c3c")
	self.add_theme_stylebox_override("hover", hover_style)
	
	self.pressed.connect(_button_pressed)

func _button_pressed():
	FD.change_scene("res://Scenes/cutscene.tscn")
