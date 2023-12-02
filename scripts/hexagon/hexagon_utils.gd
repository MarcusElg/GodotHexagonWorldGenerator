# Static class with hexagon related functions
class_name HexagonUtils

static var _size: float

# Neighbours in counter clockwise order
static var neighbour_offsets: Array[Vector3] = [
	Vector3(1, -1, 0), Vector3(0, -1, 1), Vector3(-1, 0, 1),
	Vector3(-1, 1, 0), Vector3(0, 1, -1), Vector3(1, 0, -1),
]

# Corners in counter clockwise order
static var corner_offsets: Array[Vector3] = [
	Vector3(2.0 / 3, -1.0 / 3, -1.0 / 3), Vector3(1.0 / 3, -2.0 / 3, 1.0 / 3),
	Vector3(-1.0 / 3, -1.0 / 3, 2.0 / 3), Vector3(-2.0 / 3, 1.0 / 3, 1.0 / 3),
	Vector3(-1.0 / 3, 2.0 / 3, -1.0 / 3), Vector3(1.0 / 3, 1.0 / 3, -2.0 / 3), 
]

# Offsets from an edge to other edges in counter clockwise order
static var edge_offsets: Array[Vector3] = [
	Vector3(0.5, -0.5, 0), Vector3(0, -0.5, 0.5), Vector3(-0.5, 0, 0.5),
	Vector3(-0.5, 0.5, 0), Vector3(0, 0.5, -0.5), Vector3(0.5, 0, -0.5),
]

## Get dimensions
static func get_width() -> float:
	return 2 * HexagonUtils._size
	
static func get_height() -> float:
	return sqrt(3) * HexagonUtils._size

static func get_inner_radius() -> float:
	return HexagonUtils.get_height() / 2
	
static func get_outer_radius() -> float:
	return HexagonUtils._size
	
static func get_side_length() -> float:
	return HexagonUtils.get_outer_radius()
	
static func get_perimeter() -> float:
	return HexagonUtils.get_side_length() * 6

##

static func get_neighbour_offset(index: int) -> Vector3:
	return HexagonUtils.neighbour_offsets[index % len(HexagonUtils.neighbour_offsets)]

static func get_corner_offset(index: int) -> Vector3:
	return HexagonUtils.corner_offsets[index % len(HexagonUtils.corner_offsets)]

# Round a fractal position, source: https://www.redblobgames.com/grids/hexagons/#rounding
static func round_hexagon(position: Vector3) -> Vector3:
	# Round coordinates
	var q: float = round(position.x)
	var r: float = round(position.y)
	var s: float = round(position.z)

	var q_difference = abs(q - position.x)
	var r_difference = abs(r - position.y)
	var s_difference = abs(s - position.z)

	# Reset component with largest difference between rounded and orginal value
	if q_difference > r_difference and q_difference > s_difference:
		q = -r-s
	elif r_difference > s_difference:
		r = -q-s
	else:
		s = -q-r

	return Vector3(q, r, s)

# Get grid position from world position
static func get_grid_position(world_position: Vector2, round: bool = true) -> Vector3:
	var q: float = (2.0 / 3 * world_position.x) / _size
	var r: float = (-1.0 / 3 * world_position.x + sqrt(3.0) / 3.0 * world_position.y) / _size
	var coordinates: Vector3 = Vector3(q, r, -q-r)
	if round: coordinates = HexagonUtils.round_hexagon(coordinates)
	
	return coordinates
	
# Get world position from grid position
static func get_world_position(position: Vector3) -> Vector2:
	return (Vector2.from_angle(PI / 6) * position.x + Vector2.DOWN * position.y) * HexagonUtils.get_height()
