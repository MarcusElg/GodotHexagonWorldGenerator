extends FileDialog

@export var screenshot_camera: Camera2D
@export var ui: CanvasLayer

func open_dialog():
	popup_centered(Vector2(500, 500))

func export_image(path: String):
	# Disable ui and switch camera
	var game_camera = ui.get_viewport().get_camera_2d()
	ui.visible = false
	screenshot_camera.make_current()
	await get_tree().process_frame
	await get_tree().process_frame

	# Take and save image
	var image: Image = screenshot_camera.get_viewport().get_texture().get_image()
	image.save_png(path)
	
	# Enable ui and switch back
	ui.visible = true
	game_camera.make_current()
