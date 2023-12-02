# A hexagon in cube coordinates
class_name Hexagon extends Node2D

var grid_position: Vector3 # q, r, s
var edges: Array[HexagonEdge] = [] # Edges in counter clockwise order
var terrain_type: TerrainType = null
var path_connections: int # Bit mask for neighbours to connect path with in counter clockwise order

var world: World

func initialise(grid_position: Vector3, world: World) -> Hexagon:
	self.grid_position = grid_position
	self.world = world
	return self

func get_neighbour_positions() -> Array[Vector3]:
	var neighbours: Array[Vector3] = []
	neighbours.assign(HexagonUtils.neighbour_offsets.map(func(x): return grid_position + x))
	return neighbours
	
func get_neighbour_position(index: int) -> Vector3:
	return grid_position + HexagonUtils.get_neighbour_offset(index)

# Get list of neighbour hexagon edge connections
func get_neighbours() -> Array[HexagonEdgeConnection]:
	var neighbours: Array[HexagonEdgeConnection] = []
	
	for edge: HexagonEdge in edges:
		if len(edge.connected_hexagons) < 2: continue
		
		if edge.connected_hexagons[0].hexagon == self:
			neighbours.append(edge.connected_hexagons[1])
		else:
			neighbours.append(edge.connected_hexagons[0])
	
	neighbours.sort_custom(func(x, y): return x.side < y.side)
	
	return neighbours

# Get global points in counter clockwise order
func get_world_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var world_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	
	var angle = 0
	while angle < 2 * PI - 0.0001:
		points.append(Vector2(world_position.x + HexagonUtils.get_outer_radius() * cos(2 * PI - angle),
		world_position.y + HexagonUtils.get_outer_radius() * sin(2 * PI - angle)))
		
		angle += PI / 3.0
	
	return points

# Get center position of edge
func get_edge_center_position(edge: int) -> Vector2:
	var world_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	var angle: float = 2 * PI - PI / 3.0 * (edge + 0.5)
	
	return Vector2(world_position.x + HexagonUtils.get_inner_radius() * cos(angle),
		world_position.y + HexagonUtils.get_inner_radius() * sin(angle))

# Returns index of nearest edge
func get_nearest_edge(point: Vector2) -> int:
	var world_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	var angle: float = (point - world_position).normalized().angle()
	if angle < 0: angle += 2 * PI

	return 5 - floori(angle / (PI / 3))

# Get start and end position of edge
func get_edge(index: int) -> Array[Vector2]:
	var corners: Array[Vector2] = get_world_points()
	
	return [corners[index], corners[(index + 1) % 6]]

# Get bounding box in world coordinates
func get_bounding_box() -> Rect2:
	var world_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	var width: float = HexagonUtils.get_width()
	var height: float = HexagonUtils.get_height()
	
	return Rect2(world_position.x - width / 2, world_position.y - height / 2, width, height)

# Toggle path
func toggle_path(index: int):
	path_connections ^= (1 << index)
	place_paths()
	place_vegetation(false)
	
# Set/remove path
func set_path(index: int, set: bool = true):
	if set:
		path_connections |= (1 << index)
	else:
		path_connections &= ~(1 << index)
	
	place_paths()
	place_vegetation(false)

## Terrain
func set_terrain_type(terrain_type: TerrainType):
	# Set new terrain type
	self.terrain_type = terrain_type
	
	var background_mask = find_child("background mask")
	var background = find_child("background")
	background.texture = terrain_type.background_texture
	
	# Scale background mask and background to match hexagon size
	background_mask.scale = Vector2.ONE * HexagonUtils.get_width() / background_mask.texture.get_width()
	background.scale = Vector2.ONE * background_mask.texture.get_width() / background.texture.get_width()

func place_vegetation(update_neighbours: bool):
	_remove_vegetation()
	_place_vegetation(update_neighbours)
	
	if world.generate_docks && terrain_type.name == "village":
		_place_docks()

func _remove_vegetation():
	for child: Node2D in find_child("vegetation").get_children():
		child.queue_free()
	
	for child: Node2D in find_child("docks").get_children():
		child.queue_free()

func _place_vegetation(update_neighbours: bool):
	# Update neighbour vegetation
	var neighbours: Array[HexagonEdgeConnection] = get_neighbours()
	if update_neighbours:
		for neighbour: HexagonEdgeConnection in neighbours:
			neighbour.hexagon.place_vegetation(false)

	if len(terrain_type.vegetation) == 0: return

	var center_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	var world_points: Array[Vector2] = get_world_points()
	var bounds: Rect2 = get_bounding_box()
	var attempts: int = 0
	var count: int = 0

	# Check with neighbours have same terrain type
	var neighbour_terrain_mask: int = 0b000000
	for neighbour: HexagonEdgeConnection in neighbours:
		if neighbour.hexagon.terrain_type == terrain_type and neighbour.hexagon.edges[neighbour.side].edge_type == HexagonEdge.EdgeType.None:
			neighbour_terrain_mask |= 1 << (neighbour.side + 3) % 6 # Current side is mirrored compared to neighbour's side

	# Generated triangles for neighbours with same terrain type
	var triangles: Array[Array] = []
	for i: int in range(6):
		if neighbour_terrain_mask & (1 << i):
			var point1: Vector2 = world_points[i]
			var point2: Vector2 = world_points[(i + 1) % 6]
			var point3: Vector2 = (bounds.position + bounds.end) / 2
			
			triangles.append([point1, point2, point3])

	# Place objects
	while attempts < 2 * terrain_type.max_vegetation_count and count < terrain_type.max_vegetation_count:
		attempts += 1
		var vegetation_position: Vector2 = bounds.position + Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
		var vegetation_type: VegetationType = terrain_type.vegetation.pick_random()
		var vegetation_object: Sprite2D = vegetation_type.scene_instance.instantiate()

		# Check that it's within inner circle
		var max_radius: float = HexagonUtils.get_inner_radius() - vegetation_object.texture.get_width() / 2.0 * vegetation_type.base_scale * vegetation_type.max_scale
		if center_position.distance_to(vegetation_position) >= max_radius:
			var found_valid_location: bool = false

			# Check if it's within a triangle to a neighbouring tile of same type
			for triangle: Array in triangles:
				if Geometry2D.point_is_inside_triangle(vegetation_position, triangle[0], triangle[1], triangle[2]):
					found_valid_location = true
					break

			if not found_valid_location:
				vegetation_object.queue_free()
				continue

		# Check that it doesn't collide with paths
		var found_valid_location: bool = true
		for i: int in range(6):
			if path_connections & (1 << i):
				var distance_to_path = vegetation_position.distance_to(Geometry2D.get_closest_point_to_segment(vegetation_position, HexagonUtils.get_world_position(grid_position), get_edge_center_position(i)))
				if distance_to_path <= (world.path_width + vegetation_object.texture.get_width() * vegetation_type.base_scale * vegetation_type.max_scale) / 2:
					found_valid_location = false
					break

		if not found_valid_location:
				vegetation_object.queue_free()
				continue

		# Place an object
		find_child("vegetation").add_child(vegetation_object)
		vegetation_object.global_position = vegetation_position
		vegetation_object.scale = Vector2.ONE * vegetation_type.base_scale
		_randomise_vegetation_transforms(vegetation_object, vegetation_type)

		count += 1

# Randomises the scale and rotation of a randomisation object
func _randomise_vegetation_transforms(vegetation_object: Node2D, vegetation_type: VegetationType):
	if vegetation_type.randomly_rotate:
		vegetation_object.rotate(randf_range(0, 2 * PI))
		
	vegetation_object.scale *= Vector2.ONE * randf_range(vegetation_type.min_scale, vegetation_type.max_scale)

func _place_docks():
	var world_position = HexagonUtils.get_world_position(grid_position)
	
	for neighbour: HexagonEdgeConnection in get_neighbours():
		if neighbour.hexagon.terrain_type.name == "lake":
			# Avoid placing dock next to river
			if neighbour.hexagon.edges[neighbour.side].edge_type == HexagonEdge.EdgeType.River:
				continue
			
			# Create dock object
			var neighbour_world_position = HexagonUtils.get_world_position(neighbour.hexagon.grid_position)
			
			var docks = Sprite2D.new()
			find_child("docks").add_child(docks)
			
			docks.texture = world.docks_texture
			docks.global_position = world_position + (neighbour_world_position - world_position).normalized() * (HexagonUtils.get_inner_radius() + HexagonUtils.get_side_length() / 2)
			docks.scale = Vector2.ONE * HexagonUtils.get_side_length() / docks.texture.get_width()
			docks.look_at(neighbour_world_position + (neighbour_world_position - world_position).normalized() * HexagonUtils.get_outer_radius())

func place_paths():
	_remove_paths()
	_place_path_objects()

func _remove_paths():
	var paths_parent: Node2D = find_child("paths")
	for child in paths_parent.get_children():
		child.queue_free()

func _place_path_objects():
	var connections: Array[int] = []
	# Don't place paths on top of village marketsplaces
	var marketplace_radius: float = 0.6 if terrain_type.name == "village" else 0

	for i: int in range(6):
		if path_connections & (1 << i):
			connections.append(i)
	
	if len(connections) == 0: return
	
	match(len(connections)):
		1:
			_place_single_path(connections, marketplace_radius)
		2:
			_place_double_path(connections, marketplace_radius)
		_:
			_place_multiple_paths(connections, marketplace_radius)

	_place_bridges(connections)

# Place a path to only one connection
func _place_single_path(connections: Array[int], marketplace_radius: float):
	var start_position: Vector2 = HexagonUtils.get_world_position(grid_position)
	var end_position: Vector2 = get_edge_center_position(connections[0])
	if marketplace_radius > 0: start_position = start_position.lerp(end_position, marketplace_radius)

	_create_path([start_position, end_position])

# Place paths to two connections
func _place_double_path(connections: Array[int], marketplace_radius: float):
	if marketplace_radius == 0:
		var center_point: Vector2 = HexagonUtils.get_world_position(grid_position)

		var start_point: Vector2 = get_edge_center_position(connections[0])
		var end_point: Vector2 = get_edge_center_position(connections[1])
		var curve_start_point: Vector2 = center_point.lerp(get_edge_center_position(connections[0]), 0.4)
		var curve_end_point:Vector2 = center_point.lerp(get_edge_center_position(connections[1]), 0.4)
		
		var points: Array[Vector2] = [start_point]
		points.append_array(MathUtils.quadratic_bezier_points(curve_start_point, center_point, curve_end_point, world.path_precision))
		points.append(end_point)
				
		_create_path(points)
	else:
		_place_multiple_paths(connections, marketplace_radius)

# Place paths to more than 2 connections
func _place_multiple_paths(connections: Array[int], marketplace_radius: float):
	if marketplace_radius == 0:
		# Straight segments
		for i: int in range(len(connections)):
			var start_position: Vector2 = HexagonUtils.get_world_position(grid_position)
			var end_position: Vector2 = get_edge_center_position(connections[i])
			_create_path([start_position, end_position])
		
		# Center
		var intersection: Sprite2D = Sprite2D.new()
		intersection.texture = world.path_intersection_texture
		find_child("paths").add_child(intersection)
		intersection.scale = Vector2.ONE * world.intersection_width / intersection.texture.get_width()
	else:
		for connection: int in connections:
			_place_single_path([connection], marketplace_radius)

func _place_bridges(connections: Array[int]):
	for connection: int in connections:
		var edge: HexagonEdge = edges[connection]
		
		# Prevent bridges to lakes
		var neighbour_position = get_neighbour_position(connection)
		if neighbour_position in world.hexagons and not world.hexagons[neighbour_position].terrain_type.allow_paths:
			continue
		
		if edge.edge_type == HexagonEdge.EdgeType.River:
			if len(edge.connected_hexagons) > 1:
				var neighbour_hexagon = edge.connected_hexagons[1] if edge.connected_hexagons[0] == self else edge.connected_hexagons[0]
				if not neighbour_hexagon.hexagon.terrain_type.allow_paths: continue
			
			var start_position = get_edge_center_position(connection)
			var bridge_half_width = world.river_width / 2 * 1.5
			var end_position = start_position + (HexagonUtils.get_world_position(grid_position) - start_position).normalized() * bridge_half_width
			_create_path([start_position, end_position], true)

func _create_path(points: Array[Vector2], bridge: bool = false):
	var line: Line2D = Line2D.new()
	
	for point: Vector2 in points:
		line.add_point(point - position)
	
	line.width = world.path_width * (1.5 if bridge else 1)
	line.texture = world.bridge_texture if bridge else world.path_texture
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	if bridge:
		line.z_index = 6
	
	find_child("paths").add_child(line)
