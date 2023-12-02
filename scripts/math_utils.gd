class_name MathUtils

static func quadratic_bezier(start_point: Vector2, control_point: Vector2, end_point: Vector2, t: float) -> Vector2:
	t = clampf(t, 0, 1)
	return (1 - t) ** 2 * start_point + 2 * t * (1 - t) * control_point + t ** 2 * end_point

static func quadratic_bezier_points(start_point: Vector2, control_point: Vector2, end_point: Vector2, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(count):
		var t = float(i) / (count - 1) if i < count - 1 else 1
		points.append(quadratic_bezier(start_point, control_point, end_point, t))
		
	return points
