class_name River extends Line2D

var grid_points: Array[Vector3] = [] # Points in cube coordinates

func initialise(width: int) -> River:
	self.width = width
	return self

func append_point(point: Vector3, precision: int):
	grid_points.append(point)

	if len(grid_points) < 2:
		add_point(HexagonUtils.get_world_position(point))
	
	if len(grid_points) < 3: return

	# Sample points from bezier curve
	var start_point: Vector3 = (grid_points[-3] + grid_points[-2]) / 2
	var control_point: Vector3 = grid_points[-2]
	var end_point: Vector3 = (grid_points[-1] + grid_points[-2]) / 2
	var curve_points: Array[Vector2] = MathUtils.quadratic_bezier_points(HexagonUtils.get_world_position(start_point), 
	HexagonUtils.get_world_position(control_point), HexagonUtils.get_world_position(end_point), precision)
	
	for i in range(1, len(curve_points)):
		add_point(curve_points[i])

# Append a point directly, avoiding curvature
func append_stright_point(point: Vector3):
	grid_points.append(point)
	add_point(HexagonUtils.get_world_position(point))
