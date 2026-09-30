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
## Clustered population (colony_radius > 0): fill_per_cell is then spent as
## colonies of about colony_members members, instead of independent anchors:
## a main member at one jittered centre per proposal cell and the others
## nestled round it (DressingCompiler.nestle_distance), never beyond
## colony_radius of the centre.
@export var colony_radius: float = 0.0
@export var colony_members: float = 0.0
@export var community_channel: StringName
@export var community_scale: float = 0.0
@export_range(0.0, 1.0) var community_strength: float = 0.0

@export var surface_mode: SurfaceMode = SurfaceMode.GROUND_POINT
@export var water_mode: WaterMode = WaterMode.LAND
@export var depth_range: Vector2 = Vector2.ZERO
@export var shore_distance_range: Vector2 = Vector2.ZERO
## Qualify the actual near-ground visual footprint even without physics collision.
@export var visual_ground_support: bool = false
@export var support_radius: float = 0.0
@export var max_support_height_span: float = 0.0
@export var max_grade: float = 1.0
## Optional positive relief above the supported anchor. This distinguishes
## lower cliff feet from open flats and the high side of a drop.
@export var relief_radius: float = 0.0
@export var relief_range: Vector2 = Vector2.ZERO
## Extra distance beyond path/feature footprints. Zero still rejects anchors
## inside a reservation; this is authored per population, never inferred from tags.
@export var feature_clearance: float = 0.0
## Embedded rock: sink every point of the visible base outline this fraction
## of the scaled visual height below the ground, and raise a ground skirt
## (RockSkirt) that meets it. Zero rests the asset on its anchor.
@export var embed_fraction: float = 0.0

@export var spacing_group: StringName
@export var spacing_radius: float = 0.0

@export var scale_range: Vector2 = Vector2.ONE
@export var brightness_range: Vector2 = Vector2.ONE
