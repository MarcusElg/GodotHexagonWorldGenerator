extends CanvasLayer

@export var mode_textures: Array[Texture2D] = []

@export var world: World
@export var clouds: Clouds
@export var options: Control
@export var mode_texture: TextureRect

var ui_open = true

func _ready():
	setup_options()
	mode_texture.texture = mode_textures[World.Mode.Move]

func setup_options():
	# Set in-game options to match editor options
	options.find_child("Hexagon Count").find_child("Value").value = world.hexagon_count
	options.find_child("River Count").find_child("Min").value = world.min_rivers
	options.find_child("River Count").find_child("Max").value = world.max_rivers
	options.find_child("Lake Count").find_child("Min").value = world.min_lakes
	options.find_child("Lake Count").find_child("Max").value = world.max_lakes
	options.find_child("Village Count").find_child("Min").value = world.min_villages
	options.find_child("Village Count").find_child("Max").value = world.max_villages
	options.find_child("Generate Fields").find_child("Value").button_pressed = world.generate_fields
	options.find_child("Generate Docks").find_child("Value").button_pressed = world.generate_docks
	options.find_child("Biome Scale").find_child("Value").value = world.noise_scale
	
	options.find_child("Generate Clouds").find_child("Value").button_pressed = clouds.generate_clouds
	options.find_child("Cloud Speed").find_child("Value").value = clouds.cloud_speed
	options.find_child("Cloud Wait Time").find_child("Min").value = clouds.min_spawn_wait * 10
	options.find_child("Cloud Wait Time").find_child("Max").value = clouds.max_spawn_wait * 10

func regenerate():
	# Set editor options to match in-game options
	world.hexagon_count = options.find_child("Hexagon Count").find_child("Value").value
	world.min_rivers = options.find_child("River Count").find_child("Min").value
	world.max_rivers = options.find_child("River Count").find_child("Max").value
	world.min_lakes = options.find_child("Lake Count").find_child("Min").value
	world.max_lakes = options.find_child("Lake Count").find_child("Max").value
	world.min_villages = options.find_child("Village Count").find_child("Min").value
	world.max_villages = options.find_child("Village Count").find_child("Max").value
	world.generate_fields = options.find_child("Generate Fields").find_child("Value").button_pressed
	world.generate_docks = options.find_child("Generate Docks").find_child("Value").button_pressed
	world.noise_scale = options.find_child("Biome Scale").find_child("Value").value 
	
	clouds.generate_clouds = options.find_child("Generate Clouds").find_child("Value").button_pressed
	clouds.cloud_speed = options.find_child("Cloud Speed").find_child("Value").value
	clouds.min_spawn_wait = options.find_child("Cloud Wait Time").find_child("Min").value / 10
	clouds.max_spawn_wait = options.find_child("Cloud Wait Time").find_child("Max").value / 10
	
	# Regenerate world
	world.generate_map()

func toggle_cloud_settings_editability(clouds_enabled: bool):
	options.find_child("Cloud Speed").find_child("Value").editable = clouds_enabled
	options.find_child("Cloud Wait Time").find_child("Min").editable = clouds_enabled
	options.find_child("Cloud Wait Time").find_child("Max").editable = clouds_enabled

func change_mode(mode: World.Mode):
	mode_texture.texture = mode_textures[mode]
