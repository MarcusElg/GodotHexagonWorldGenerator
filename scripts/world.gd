class_name World extends Node2D

@export_category("World Settings")
@export var hexagon_size: float = 50
@export_range(0, 10) var hexagon_count: int = 3 # Radius of hexagons around center
@export var terrain_types: Array[TerrainType] = []
@export var randomise_seed: bool = true
@export var seed: int = 0
@export var allow_walls: bool = true

@export_group("Colours")
@export var background_colour: Color = Color.GRAY
@export var grid_colour: Color = Color.from_hsv(1, 0, 0, 0.15)

@export_group("Rivers")
@export_range(0, 3) var min_rivers: int = 2
@export_range(0, 3) var max_rivers: int = 2
@export_range(3, 15) var river_width: float = 10
@export_range(2, 50) var river_precision: int = 10

@export_group("Lakes")
@export_range(0, 5) var min_lakes: int = 1
@export_range(0, 5) var max_lakes: int = 2

@export_group("Villages")
@export_range(0, 5) var min_villages: int = 1
@export_range(0, 5) var max_villages: int = 1
@export var generate_fields: bool = true
@export var generate_docks: bool = true

@export_group("Paths")
@export var allow_paths: bool = true
@export var path_texture: Texture2D
@export var path_intersection_texture: Texture2D
@export var bridge_texture: Texture2D
@export_range(1, 10) var path_width: float = 5
@export_range(1, 29) var intersection_width: float = 8
@export_range(2, 50) var path_precision: int = 10

@export_group("Noise")
@export var temperature_noise: FastNoiseLite
@export var humidity_noise: FastNoiseLite
@export_range(1, 98) var noise_scale: float = 10

@export_category("Editor Settings")
@export var screenshot_camera: Camera2D

@export_group("Instances")
@export var hexagon_instance: PackedScene
@export var hexagon_edge_instance: PackedScene
@export var river_instance: PackedScene
@export var background_border_instance: PackedScene
@export var background_border_corner_texture: Texture2D

@export_group("Textures")
@export var walls_texture: Texture2D
@export var open_walls_texture: Texture2D
@export var docks_texture: Texture2D

var hexagons: Dictionary = {} # Key = cube position
var hexagon_edges: Dictionary = {} # Key = median of the two points
var border_hexagons: Array[Hexagon] = []
var rivers: Array[River] = []
var clicked_hexagon_position: Vector3 = Vector3.INF
enum Mode {Debug, Move, Region, Path, Walls}
var mode: Mode = Mode.Move

signal change_mode(mode: Mode)

func generate_map():
	reset_variables()
	remove_children()
	setup_variables()
	generate_hexagons()
	connect_edges()
	generate_rivers()
	generate_lakes()
	generate_villages()
	place_vegetation()
	generate_background()

func setup_variables():
	if randomise_seed: seed = randi()
	
	HexagonUtils._size = hexagon_size
	temperature_noise.seed = seed
	humidity_noise.seed = seed + 1
	temperature_noise.frequency = (100 - noise_scale) * 0.00001
	humidity_noise.frequency = (100 - noise_scale) * 0.00001
	
	screenshot_camera.scale = Vector2.ONE * HexagonUtils.get_height() * (1 + 2 * (hexagon_count)) / screenshot_camera.get_viewport_rect().size.y
	find_child("Clouds").setup()

func reset_variables():
	hexagons = {}
	hexagon_edges = {}
	border_hexagons = []
	rivers = []
	
func remove_children():
	for child: Node2D in find_child("Background").get_children():
		if child.name != "Border":
			child.queue_free()
	
	for child: Node2D in find_child("Hexagons").get_children():
		child.queue_free()
	
	for child: Node2D in find_child("Rivers").get_children():
		child.queue_free()

func generate_hexagons():
	if len(terrain_types) == 0:
		push_error("Terrain types are not configured")
		return
	
	# Generate honeycomb of hexagons
	for q: int in range(-hexagon_count, hexagon_count + 1):
		for r: int in range(-hexagon_count, hexagon_count + 1):
			if abs(-q-r) > hexagon_count: continue
			
			var hexagon_grid_position: Vector3 = Vector3(q, r, -q-r)
			var hexagon_global_position: Vector2 = HexagonUtils.get_world_position(hexagon_grid_position)
			var hexagon: Hexagon = hexagon_instance.instantiate().initialise(hexagon_grid_position, self)
			find_child("Hexagons").add_child(hexagon)
			hexagon.global_position = hexagon_global_position
			
			# Choose terrain type depending on temperature and humidity noise
			var noise_position: Vector2 = hexagon_global_position / Vector2.ONE * HexagonUtils.get_inner_radius()
			var temperature: float = remap(temperature_noise.get_noise_2dv(noise_position), -1, 1, 0, 1) # remap to 0-1
			var humidity: float = remap(humidity_noise.get_noise_2dv(noise_position), -1, 1, 0, 1) # reamp to 0-1
			var terrain_type: TerrainType = terrain_types[0]
			
			for terrain: TerrainType in terrain_types:
				if temperature >= terrain.min_temperature and temperature <= terrain.max_temperature and \
					humidity >= terrain.min_humidity and humidity <= terrain.max_humidity:
						terrain_type = terrain
						break
			
			hexagon.set_terrain_type(terrain_type)
			
			hexagons[hexagon_grid_position] = hexagon
			
			# Save border hexagons
			if abs(q) == hexagon_count or abs(r) == hexagon_count or abs(-q-r) == hexagon_count:
				border_hexagons.append(hexagon)
			
			# Generate edges
			for i: int in range(6):
				var current_corner: Vector3 = hexagon_grid_position + HexagonUtils.get_corner_offset(i)
				var next_corner: Vector3 = hexagon_grid_position + HexagonUtils.get_corner_offset(i + 1)
				var edge: HexagonEdge = hexagon_edge_instance.instantiate().initialise(current_corner, next_corner, self)
				var key: Vector3 = snapped((current_corner + next_corner) / 2, Vector3.ONE * 0.01)

				if not key in hexagon_edges: # Avoid duplicating edge
					hexagon_edges[key] = edge
					find_child("Edges").add_child(edge)
				else:
					edge.queue_free()
					edge = hexagon_edges[key]
				
				hexagon.edges.append(hexagon_edges[key])
				edge.connected_hexagons.append(HexagonEdgeConnection.new(hexagon, i))

func connect_edges():
	for edge_key: Vector3 in hexagon_edges:
		var edge: HexagonEdge = hexagon_edges[edge_key]
		
		# Check all 6 directions for neighbouring edges
		for offset: Vector3 in HexagonUtils.edge_offsets:
			var neighbour_edge_position: Vector3 = snapped(edge_key + offset, Vector3.ONE * 0.01)
			if neighbour_edge_position in hexagon_edges:
				# Determine if it's connected to position1 or position2
				if neighbour_edge_position.distance_to(edge.position1) < neighbour_edge_position.distance_to(edge.position2):
					edge.connected_edges1.append(hexagon_edges[neighbour_edge_position])
				else:
					edge.connected_edges2.append(hexagon_edges[neighbour_edge_position])

func place_vegetation():
	for hexagon: Hexagon in hexagons.values():
		hexagon.place_vegetation(false)

func generate_rivers():
	var river_random: RandomNumberGenerator = RandomNumberGenerator.new()
	river_random.seed = seed + 10

	# Find edges on border where one side has connections inwards
	var border_edges: Array = hexagon_edges.values().filter(func(x): return len(x.connected_edges1) + len(x.connected_edges2) == 3)
	var used_border_positions: Array[Vector3] = []
	var tries = 0

	var river_count = river_random.randi_range(min_rivers, max_rivers)
	while len(rivers) < river_count and len(border_edges) >= 1 and tries < 200:
		tries += 1
		var current_edge: HexagonEdge = border_edges[river_random.randi_range(0, len(border_edges) - 1)]

		# Choose position so that it has inwards connections
		var start_position: Vector3 = current_edge.position1 if len(current_edge.connected_edges1) == 2 else current_edge.position2
		var end_edge: HexagonEdge = border_edges[river_random.randi_range(0, len(border_edges) - 1)]
		var end_position: Vector3 = end_edge.position1 if len(end_edge.connected_edges1) == 2 else end_edge.position2
		var snapped_start_position: Vector3 = snapped(start_position, Vector3.ONE * 0.01)
		var snapped_end_position: Vector3 = snapped(end_position, Vector3.ONE * 0.01)
		
		if snapped_start_position in used_border_positions or snapped_end_position in used_border_positions:
			continue
			
		# Prevent too short rivers
		if start_position.distance_to(end_position) < hexagon_count * 1.5:
			continue
		
		used_border_positions.append(snapped_start_position)
		used_border_positions.append(snapped_end_position)

		var river: River = river_instance.instantiate().initialise(river_width)
		var last_point: Vector3 = start_position
		var river_valid: bool = true
		var shared_segments: int = 0 # Invalid river if it shares more than 2 segment
		var last_segment_shared: bool = false
		var last_choice_random: bool = true # Was the last choose inlogically choosed?
		var edge_type_changed: Array[HexagonEdge] = []
		river.append_point(last_point, river_precision) # Ignore first segment as it's alongst the border
		
		# Generate river with random walk until it hits border
		while not last_point.is_equal_approx(end_position):
			if len(river.grid_points) > hexagon_count * 8:
				river_valid = false
				break
			
			# Allow multiple shared segements if they are after each other
			if current_edge.edge_type == HexagonEdge.EdgeType.River and not last_segment_shared:
				shared_segments += 1
			
			if shared_segments >= 2:
				river_valid = false
				break
			
			last_segment_shared = current_edge.edge_type == HexagonEdge.EdgeType.River

			if current_edge.edge_type != HexagonEdge.EdgeType.River:
				current_edge.edge_type = HexagonEdge.EdgeType.River
				edge_type_changed.append(current_edge)

			# Always go forwards
			var edge_options: Array[HexagonEdge] = current_edge.connected_edges1 if last_point.is_equal_approx(current_edge.position1) else current_edge.connected_edges2
			
			if len(edge_options) == 1 or (shared_segments == 1 and not last_segment_shared and edge_options[1].edge_type == HexagonEdge.EdgeType.River):
				current_edge = edge_options[0]
			elif shared_segments == 1 and not last_segment_shared and edge_options[0].edge_type == HexagonEdge.EdgeType.River:
				current_edge = edge_options[1]
			else:
				# Choose edge that moves closest to end position
				var distance1: float = HexagonUtils.get_world_position((edge_options[0].position1 + edge_options[0].position2) / 2).distance_to(HexagonUtils.get_world_position(end_position))
				var distance2: float = HexagonUtils.get_world_position((edge_options[1].position1 + edge_options[1].position2) / 2).distance_to(HexagonUtils.get_world_position(end_position))
				var primary_choice: HexagonEdge = edge_options[0] if distance1 < distance2 else edge_options[1]
				var secondary_choise: HexagonEdge = edge_options[1] if distance1 < distance2 else edge_options[0]
				
				# Biased random
				edge_options = [primary_choice]
				
				# Prevent loops (two illogical choices in a row)
				if not last_choice_random:
					for i: int in range(4):
						edge_options.append(primary_choice)
						
					edge_options.append(secondary_choise)
						
				current_edge = edge_options[river_random.randi_range(0, len(edge_options) - 1)]
				last_choice_random = current_edge == secondary_choise
			
			last_point = current_edge.position2 if current_edge.position1.is_equal_approx(last_point) else current_edge.position1
			river.append_point(last_point, river_precision)
		
		if len(river.grid_points) < 5: river_valid = false
		
		if river_valid:
			current_edge.edge_type = HexagonEdge.EdgeType.River
			river.append_stright_point(last_point)
			rivers.append(river)
			find_child("Rivers").add_child(river)
		else:
			# Revert changed edge types to river
			for edge: HexagonEdge in edge_type_changed:
				edge.edge_type = HexagonEdge.EdgeType.None

func generate_lakes():
	if len(rivers) == 0: return
	
	var searched_terrain_types: Array[TerrainType] = terrain_types.filter(func (terrain_type): return terrain_type.name == "lake")
	if len(searched_terrain_types) == 0: return
	var lake_terrain_type: TerrainType = searched_terrain_types[0]
	
	var lakes_random: RandomNumberGenerator = RandomNumberGenerator.new()
	lakes_random.seed = seed + 11
	
	# Select a random hexagon next to a river
	for i: int in range(lakes_random.randi_range(min_lakes, max_lakes)):
		var river: River = rivers[lakes_random.randi_range(0, len(rivers) - 1)]
		var river_point_index: int = lakes_random.randi_range(0, len(river.grid_points) - 2)
		var edge_start_point: Vector3 = river.grid_points[river_point_index]
		var edge_end_point: Vector3 = river.grid_points[river_point_index + 1]
		var edge_position: Vector3 = snapped((edge_start_point + edge_end_point) / 2, Vector3.ONE * 0.01)
		
		if not edge_position in hexagon_edges: continue
		var edge: HexagonEdge = hexagon_edges[edge_position]

		var hexagon: HexagonEdgeConnection = edge.connected_hexagons[lakes_random.randi_range(0, len(edge.connected_hexagons) - 1)]
		hexagon.hexagon.set_terrain_type(lake_terrain_type)

func generate_villages():
	# Find village and fields terrain types
	var searched_terrain_types: Array[TerrainType] = terrain_types.filter(func (terrain_type): return terrain_type.name == "village")
	if len(searched_terrain_types) == 0: return
	var village_terrain_type: TerrainType = searched_terrain_types[0]
	
	searched_terrain_types = terrain_types.filter(func (terrain_type): return terrain_type.name == "fields")
	if len(searched_terrain_types) == 0: return
	var fields_terrain_type: TerrainType = searched_terrain_types[0]
	
	# Place in random locations
	var village_random: RandomNumberGenerator = RandomNumberGenerator.new()
	village_random.seed = seed + 12
	for i: int in range(village_random.randi_range(min_villages, max_villages)):
		var tries: int = 0
		
		while tries < 5:
			var hexagon: Hexagon = hexagons.values()[village_random.randi_range(0, len(hexagons.values()) - 1)]
			if hexagon.terrain_type.name == "village": continue
			
			# Check that neighbours isn't another village
			var invalid_position: bool = false
			for neighbour: HexagonEdgeConnection in hexagon.get_neighbours():
				if neighbour.hexagon.terrain_type.name == "village":
					tries += 1
					invalid_position = true
					continue
			
			if invalid_position: continue
			
			hexagon.set_terrain_type(village_terrain_type)
			
			# Set neighbouring tiles to fields
			if generate_fields:
				for neighbour: HexagonEdgeConnection in hexagon.get_neighbours():
					if not neighbour.hexagon.terrain_type.allow_paths: continue
					
					neighbour.hexagon.set_terrain_type(fields_terrain_type)
			
			break

func generate_background():
	var background: Node2D = find_child("Background")
	RenderingServer.set_default_clear_color(background_colour)
	var border: Sprite2D = background.find_child("Border")
	border.scale = Vector2.ONE * HexagonUtils.get_height() * (1 + hexagon_count * 2) / border.texture.get_height()
	border.modulate = background_colour

	# Place background borders
	for hexagon: Hexagon in border_hexagons:
		var background_border: Sprite2D = background_border_instance.instantiate()
		background_border.modulate = background_colour
		
		var border_position: Vector2 = HexagonUtils.get_world_position(hexagon.grid_position)
		background_border.global_position = border_position
		background_border.scale = Vector2.ONE * HexagonUtils.get_width() / background_border.texture.get_width()
		
		var angle: float = snappedf(border_position.angle(), PI / 3)
		background_border.rotate(angle + PI)

		# Handle corner polygons
		var snapped_angle: float = snappedf(border_position.angle() - PI / 6, PI / 3)
		if is_equal_approx(border_position.angle() - PI / 6, snapped_angle):
			background_border.texture = background_border_corner_texture
			if snapped_angle + PI / 6 > angle:
				background_border.rotate(PI / 3)

		background.add_child(background_border)

func _process(_delta):
	if Input.is_action_just_pressed("left_click"):
		left_click()
	
	if Input.is_action_just_pressed("switch_mode"):
		mode = wrap(mode + 1, 1, Mode.size())
		if not allow_paths and mode == Mode.Path:
			mode = wrap(mode + 1, 1, Mode.size())

		if not allow_walls and mode == Mode.Walls:
			mode = wrap(mode + 1, 1, Mode.size())
		
		change_mode.emit(mode)

	if Input.is_action_just_pressed("toggle_debug"):
		if mode == Mode.Debug:
			mode = Mode.Move
		else:
			mode = Mode.Debug
		
		change_mode.emit(mode)

	queue_redraw()

func left_click():
	var mouse_position: Vector2 = get_global_mouse_position()
	var hexagon_position: Vector3 = HexagonUtils.get_grid_position(mouse_position)
	if hexagon_position in hexagons:
		if mode == Mode.Region:			
			toggle_terrain_type(hexagon_position)
			
		# Toggle path
		if mode == Mode.Path and allow_paths:
			toggle_path(hexagon_position, mouse_position)
		
		# Toggle wall
		if mode == Mode.Walls:
			toggle_wall(hexagon_position, mouse_position)

func toggle_terrain_type(hexagon_position: Vector3):
	var hexagon = hexagons[hexagon_position]
	var old_terrain_type: TerrainType = hexagon.terrain_type
	var new_terrain_type: TerrainType = terrain_types[(terrain_types.find(hexagon.terrain_type) + 1) % len(terrain_types)]
	hexagon.set_terrain_type(new_terrain_type)
	hexagon.place_vegetation(true)
	clicked_hexagon_position = hexagon_position
	
	# Toggle paths for lakes
	if not new_terrain_type.allow_paths:
		for i: int in range(6):
			hexagon.set_path(i, false)
	elif not old_terrain_type.allow_paths:
		var neighbours: Array[HexagonEdgeConnection] = hexagon.get_neighbours()
		for neighbour: HexagonEdgeConnection in neighbours:
			neighbour.hexagon.set_path(neighbour.side, false)
	
	# Update paths for villages
	if new_terrain_type.name == "village" or old_terrain_type.name == "village":
		hexagon.place_paths()
	
	queue_redraw()

func toggle_path(hexagon_position: Vector3, mouse_position: Vector2):
	var hexagon: Hexagon = hexagons[hexagon_position]
	if not hexagon.terrain_type.allow_paths: return
	var nearest_index: int = hexagon.get_nearest_edge(mouse_position)
	var nearest_edge: Array[Vector2] = hexagon.get_edge(nearest_index)
	
	var distance: float = mouse_position.distance_to(Geometry2D.get_closest_point_to_segment(mouse_position, nearest_edge[0], nearest_edge[1]))
	if distance > 20: return
	
	hexagon.toggle_path(nearest_index)
	
	# Find neighbour
	if hexagon.get_neighbour_position(nearest_index) in hexagons:
		var neighbour_hexagon: Hexagon = hexagons[hexagon.get_neighbour_position(nearest_index)]
		var nearest_neighbour_index = neighbour_hexagon.get_nearest_edge(mouse_position)
		
		# Prevent toggling paths in lakes
		if not neighbour_hexagon.terrain_type.allow_paths:
			return
		
		neighbour_hexagon.toggle_path(nearest_neighbour_index)
	
	# Update walls
	hexagon.edges[nearest_index].place_edge_object()

func toggle_wall(hexagon_position: Vector3, mouse_position: Vector2):
	var nearest_index: int = hexagons[hexagon_position].get_nearest_edge(mouse_position)
	var start_point: Vector3 = hexagons[hexagon_position].grid_position + HexagonUtils.get_corner_offset(nearest_index)
	var end_point: Vector3 = hexagons[hexagon_position].grid_position + HexagonUtils.get_corner_offset(nearest_index + 1)
	
	var distance: float = mouse_position.distance_to(Geometry2D.get_closest_point_to_segment(mouse_position, HexagonUtils.get_world_position(start_point), HexagonUtils.get_world_position(end_point)))
	if distance > 20: return
	
	var key: Vector3 = snapped((start_point + end_point) / 2, Vector3.ONE * 0.01)

	if key in hexagon_edges:
		var hexagon_edge: HexagonEdge = hexagon_edges[key]
		match hexagon_edge.edge_type:
			HexagonEdge.EdgeType.None:
				hexagon_edge.edge_type = HexagonEdge.EdgeType.Walls
				
				for hexagon_connection: HexagonEdgeConnection in hexagon_edge.connected_hexagons:
					hexagon_connection.hexagon.place_vegetation(false)
			HexagonEdge.EdgeType.Walls:
				hexagon_edge.edge_type = HexagonEdge.EdgeType.None
				
				for hexagon_connection: HexagonEdgeConnection in hexagon_edge.connected_hexagons:
					hexagon_connection.hexagon.place_vegetation(false)

		hexagon_edge.place_edge_object()

func _ready():
	generate_map()

func _draw():
	draw_grid()
	draw_highlighted()
	
	if mode == Mode.Debug: draw_debug()

func draw_highlighted():
	var mouse_position: Vector2 = get_global_mouse_position()
	var highlighted_hexagon: Vector3 = HexagonUtils.get_grid_position(mouse_position, hexagon_size)
	if highlighted_hexagon in hexagons:
		var corners: Array[Vector2] = hexagons[highlighted_hexagon].get_world_points()
		if mode == Mode.Region:
			draw_polygon(corners, [Color.from_hsv(1, 0, 1, 0.5)])
		
		# Draw nearest side
		if mode == Mode.Path:
			var nearest_edge: Array[Vector2] = hexagons[highlighted_hexagon].get_edge(hexagons[highlighted_hexagon].get_nearest_edge(mouse_position))
			var distance: float = mouse_position.distance_to(Geometry2D.get_closest_point_to_segment(mouse_position, nearest_edge[0], nearest_edge[1]))

			if distance < 20:
				draw_line(nearest_edge[0], nearest_edge[1], Color.WHITE, 4)
				
		if mode == Mode.Walls:
			var nearest_index: int = hexagons[highlighted_hexagon].get_nearest_edge(mouse_position)

			var start_point: Vector3 = hexagons[highlighted_hexagon].grid_position + HexagonUtils.get_corner_offset(nearest_index)
			var end_point: Vector3 = hexagons[highlighted_hexagon].grid_position + HexagonUtils.get_corner_offset(nearest_index + 1)
			var distance: float = mouse_position.distance_to(Geometry2D.get_closest_point_to_segment(mouse_position, HexagonUtils.get_world_position(start_point), HexagonUtils.get_world_position(end_point)))

			if distance < 20:
				draw_line(HexagonUtils.get_world_position(start_point), HexagonUtils.get_world_position(end_point), Color.WHITE, 4)

func draw_grid():
	for hexagon: Hexagon in hexagons.values():
		var points: Array[Vector2] = hexagon.get_world_points()
		draw_polyline(points, grid_colour)

func draw_debug():
	var mouse_position: Vector2 = get_global_mouse_position()
	var highlighted_hexagon: Vector3 = HexagonUtils.get_grid_position(mouse_position, hexagon_size)
	if highlighted_hexagon in hexagons:
		var hexagon: Hexagon = hexagons[highlighted_hexagon]
		var hexagon_position: Vector2 = HexagonUtils.get_world_position(hexagon.grid_position)
		var corners: Array[Vector2] = hexagon.get_world_points()
		# Draw current polygon
		draw_polygon(corners, [Color(Color.DARK_BLUE, 0.2)])
		
		# Draw neighbours
		for neighbour_position: Vector3 in hexagon.get_neighbour_positions():
			if neighbour_position in hexagons:
				var neighbour_corners: Array[Vector2] = hexagons[neighbour_position].get_world_points()
				draw_polygon(neighbour_corners, [Color(Color.CYAN, 0.3)])
		
		# Draw nearest side
		var edge_index: int = hexagon.get_nearest_edge(mouse_position)
		var nearest_edge: Array[Vector2] = hexagon.get_edge(edge_index)
		draw_line(nearest_edge[0], nearest_edge[1], Color.WHITE, 4)
		
		# Draw connected edges
		for edge: HexagonEdge in hexagon.edges[edge_index].connected_edges1:
			draw_line(HexagonUtils.get_world_position(edge.position1), HexagonUtils.get_world_position(edge.position2), Color.DIM_GRAY, 3)
		
		for edge: HexagonEdge in hexagon.edges[edge_index].connected_edges2:
			draw_line(HexagonUtils.get_world_position(edge.position1), HexagonUtils.get_world_position(edge.position2), Color.BLACK, 3)
		
		# Draw corners
		for i: int in len(corners):
			var corner: Vector2 = corners[i]
			draw_circle(corner, 3, Color.RED)
			var text_position: Vector2 = hexagon_position + (corner - hexagon_position).normalized() * HexagonUtils.get_inner_radius() * 1.4
			draw_char(ThemeDB.fallback_font, text_position, "%d" % i, 10)

		# Draw terrain type
		draw_string(ThemeDB.fallback_font, hexagon_position + Vector2.LEFT * HexagonUtils.get_inner_radius() / 2, hexagon.terrain_type.name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)

	# Draw rivers
	for river: River in rivers:
		var length: int = len(river.grid_points)
		for i: int in len(river.grid_points):
			var point: Vector3 = river.grid_points[i]
			draw_circle(HexagonUtils.get_world_position(point), 3, Color.WHITE.lerp(Color.BLACK, i / float(length)))
