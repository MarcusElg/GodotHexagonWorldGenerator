# A reperensation of a vegation type, and how to initialise it
class_name VegetationType extends Resource

@export var scene_instance: PackedScene
@export_range(1.0 / 32, 4) var base_scale: float = 1
@export_range(0.5, 2) var min_scale: float = 0.8
@export_range(0.5, 2) var max_scale: float = 1.2
@export var randomly_rotate: bool = true
