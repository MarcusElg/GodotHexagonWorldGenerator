class_name Clouds extends Sprite2D

@export var cloud_textures: Array[Texture2D] = []
@export var generate_clouds: bool = true
@export_range(0, 100) var cloud_count: int = 20
@export_range(0.01, 1) var min_cloud_scale: float = 0.07
@export_range(0.01, 1) var max_cloud_scale: float = 0.1
@export_range(0, 100) var cloud_speed: float = 50
@export_range(0.1, 10) var min_spawn_wait: float = 1
@export_range(0.1, 10) var max_spawn_wait: float = 3
@export var world: World

var world_height: float
var time_until_spawn: float = 0

func _ready():
	await get_tree().process_frame # Wait for world to execute
	setup()

func setup():
	world_height = HexagonUtils.get_height() * (1 + 2 * world.hexagon_count)
	scale = Vector2.ONE * world_height / texture.get_height()
	remove_clouds()
	if generate_clouds: create_initial_clouds()

func remove_clouds():
	for child: Cloud in get_children():
		child.free() # Remove instantly

func create_initial_clouds():
	var current_x: float = world_height / 2
	
	# Spawn clouds
	while get_child_count() < cloud_count and current_x > -world_height / 2:
		# Avoid placing cloud to near previous ones
		var tries: int = 0
		var location_found: bool = false
		
		while tries < 10:
			var cloud_position: Vector2 = Vector2(current_x, randf_range(-world_height / 2, world_height / 2))
			if not _check_cloud_overlap(cloud_position):
				_create_cloud(cloud_position)
				current_x -= cloud_speed * randf_range(min_spawn_wait, max_spawn_wait)
				location_found = true
				break
			
			tries += 1
		
		if not location_found: current_x -= 10

func _process(delta):
	if not generate_clouds: return
	
	# Spawn clouds
	if get_child_count() < cloud_count and time_until_spawn <= 0:
		# Avoid placing cloud to near previous ones
		var tries: int = 0
		
		while tries < 10:
			var cloud_position: Vector2 = Vector2(-world_height / 2, randf_range(-world_height / 2, world_height / 2))

			if not _check_cloud_overlap(cloud_position):
				_create_cloud(cloud_position)
				time_until_spawn = randf_range(min_spawn_wait, max_spawn_wait)
				break
			
			tries += 1
	
	time_until_spawn -= delta

func _check_cloud_overlap(cloud_position: Vector2) -> bool:
	for child: Cloud in get_children():
		# Clouds shouldn't overlap
		if child.global_position.distance_to(cloud_position) < cloud_textures[0].get_height() * max_cloud_scale * 2:
			return true
	
	return false

func _create_cloud(cloud_position: Vector2):
	var cloud: Cloud = Cloud.new(self)
	cloud.texture = cloud_textures.pick_random()
	add_child(cloud)
	cloud.global_scale = Vector2.ONE * randf_range(min_cloud_scale, max_cloud_scale)
	cloud.global_position = cloud_position
