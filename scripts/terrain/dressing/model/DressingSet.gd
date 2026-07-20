class_name DressingSet
extends Resource

enum SurfaceMode { GROUND_POINT, GROUND_SUPPORT, WATER_SURFACE }
enum WaterMode { LAND, SHORE, SHALLOW, EMERGENT, FLOATING }

@export var id: StringName
@export var seed_version: int = 1
@export var choices: Array[DressingChoice] = []
## Expected local population in each 24m proposal cell, authored directly per
## biome. Habitat layers then shape where that population is allowed to live.
@export var fill_per_cell: Dictionary = {}
@export var habitat_layers: Array[DressingHabitatLayer] = []
@export var community_channel: StringName
@export var community_scale: float = 0.0
@export_range(0.0, 1.0) var community_strength: float = 0.0

@export var surface_mode: SurfaceMode = SurfaceMode.GROUND_POINT
@export var water_mode: WaterMode = WaterMode.LAND
@export var depth_range: Vector2 = Vector2.ZERO
@export var shore_distance_range: Vector2 = Vector2.ZERO
@export var support_radius: float = 0.0
@export var max_support_height_span: float = 0.0
@export var max_grade: float = 1.0

@export var spacing_group: StringName
@export var spacing_radius: float = 0.0

@export var scale_range: Vector2 = Vector2.ONE
@export var brightness_range: Vector2 = Vector2.ONE
