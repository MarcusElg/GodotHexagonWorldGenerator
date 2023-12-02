extends Button

@export var panel: Control
var options_shown: bool = true

func toggle():
	options_shown = not options_shown
	text = ">" if options_shown else "<"
	
	if options_shown:
		panel.visible = true
	else:
		panel.visible = false
	
	get_parent().resized.emit()
