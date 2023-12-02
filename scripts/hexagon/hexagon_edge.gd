# An undirectional edge between two hexagons
class_name HexagonEdge extends Node2D

var position1: Vector3 # Position in cube coordinates
var position2: Vector3 # Position in cube coordinates
var connected_hexagons: Array[HexagonEdgeConnection] = []
var connected_edges1: Array[HexagonEdge] = [] # Edges connected to position1
var connected_edges2: Array[HexagonEdge] = [] # Edges connected to position2

var world: World

enum EdgeType {None, Walls, River}
var edge_type: EdgeType = EdgeType.None

func initialise(position1: Vector3, position2: Vector3, world: World) -> HexagonEdge:
	self.position1 = position1
	self.position2 = position2
	self.world = world
	
	global_position = (HexagonUtils.get_world_position(position1) + HexagonUtils.get_world_position(position2)) / 2
	
	return self

func place_edge_object():
	_remove_edge_object()
	_place_edge_object()

func _remove_edge_object():
	if get_child_count() > 0:
		get_child(0).queue_free()

func _place_edge_object():
	if edge_type == EdgeType.Walls:
		var wall: Sprite2D = Sprite2D.new()
		
		if connected_hexagons[0].hexagon.path_connections & (1 << connected_hexagons[0].side):
			wall.texture = world.open_walls_texture
		else:
			wall.texture = world.walls_texture
		
		wall.scale = Vector2.ONE * HexagonUtils.get_side_length() / wall.texture.get_width() * 4.0 / 3
		wall.look_at((HexagonUtils.get_world_position(position2) - HexagonUtils.get_world_position(position1)).normalized())
		
		add_child(wall)
