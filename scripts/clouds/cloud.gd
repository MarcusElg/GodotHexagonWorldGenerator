class_name Cloud extends Sprite2D

var clouds: Clouds

func _init(clouds: Clouds):
	self.clouds = clouds

func _physics_process(_delta):
	# Move cloud
	global_position += Vector2.RIGHT * clouds.cloud_speed * _delta
	
	# Remove cloud
	if global_position.x > clouds.world_height / 2:
		queue_free()
