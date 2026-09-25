class_name GrassSettings
extends Resource

@export var grass_seed_version: int = 1
@export var coverage_by_biome: Dictionary = {}
@export var variant_asset_ids: Array[StringName] = []
@export var scale_range := Vector2(0.94, 1.08)
@export var max_grade: float = 1.0
@export var shore_clearance: float = 0.3
