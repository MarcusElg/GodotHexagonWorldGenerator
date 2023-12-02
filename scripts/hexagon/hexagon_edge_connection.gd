# A connection between a hexagon edge and a hexagon
class_name HexagonEdgeConnection

var hexagon: Hexagon
var side: int

func _init(hexagon: Hexagon, side: int):
	self.hexagon = hexagon
	self.side = side
