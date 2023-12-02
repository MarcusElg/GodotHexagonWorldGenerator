# A representation for a type of terrain
class_name TerrainType extends Resource

@export var name: StringName
@export var background_texture: CompressedTexture2D
@export var allow_paths: bool = true

@export_group("Generation Parameters")
@export_range(0, 1) var min_temperature: float = 0
@export_range(0, 1) var max_temperature: float = 1
@export_range(0, 1) var min_humidity: float = 0
@export_range(0, 1) var max_humidity: float = 1

@export_group("Vegetation")
@export var vegetation: Array[VegetationType] = []
@export_range(1, 100) var max_vegetation_count: int = 5
