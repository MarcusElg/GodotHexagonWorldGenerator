extends Camera2D


@export var movement_speed: float = 100
@export var zoom_speed: float = 0.2
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3

var last_mouse_position: Vector2

func _ready():
	last_mouse_position = get_global_mouse_position()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		var previous_mouse_position: Vector2 = get_local_mouse_position()
		
		# Zoom
		var zoom_adjustment: float = Input.get_axis("zoom_out", "zoom_in")
		zoom += Vector2.ONE * zoom_adjustment * zoom_speed
		zoom = zoom.clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
		
		# Zoom towards position
		if zoom_adjustment != 0:
			position = position + previous_mouse_position - get_local_mouse_position()
			reset_smoothing()

func _process(delta):
	# Move
	if Input.is_action_pressed("pan"):
		position += -(get_global_mouse_position() - last_mouse_position) * movement_speed * zoom.x * delta
	
	last_mouse_position = get_global_mouse_position()
