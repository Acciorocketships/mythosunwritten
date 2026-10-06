class_name FeatureContext
extends RefCounted

## Immutable worker-side projection of all canonical features affecting one
## block. Consumers see fields and payloads, never feature-specific generators.
var _coverage: Rect2
var _ground: FeatureGroundField
var _payload: EnvironmentInstancePayload
var connection_masks: Dictionary
var node_cells: Dictionary
var bridge_cells: Dictionary
var terrain_grades: Array[TerrainGradePatch] = []
var garden_support_regions: Array[Dictionary] = []

func graded_region(natural: HeightfieldRegion) -> HeightfieldRegion:
	return natural.with_terrain_grades(terrain_grades)

func _init(p_coverage: Rect2, ground: FeatureGroundField,
		p_payload: EnvironmentInstancePayload, masks: Dictionary = {},
		nodes: Dictionary = {}, bridges: Dictionary = {}) -> void:
	assert(ground != null and p_payload != null)
	_coverage = p_coverage
	_ground = ground
	_payload = p_payload
	connection_masks = masks.duplicate()
	node_cells = nodes.duplicate()
	bridge_cells = bridges.duplicate()

func surface_at(world_xz: Vector2) -> int:
	return _ground.surface_at(world_xz)

func surface_at_cell(world_xz: Vector2, cell: Vector2i) -> int:
	return _ground.surface_at_cell(world_xz, cell)

func has_modified_surface() -> bool:
	return _ground.has_modified_surface()

func clearance_at(world_xz: Vector2, include_envelopes: bool = true) -> float:
	return _ground.clearance_at(world_xz, include_envelopes)

## Exact projected-footprint query for objects whose visual body is larger
## than their anchor. Keeping this on the shared ground field means every
## dressing family gets the same reservation semantics without knowing which
## feature (road, village, or a future authored structure) owns the space.
func overlaps_clearance(shape: FeatureGroundShape, margin: float = 0.0,
		include_envelopes: bool = true) -> bool:
	return _ground.overlaps_clearance(shape, margin, include_envelopes)

func ground_field() -> FeatureGroundField:
	return _ground

func placements() -> EnvironmentInstancePayload:
	return _payload

func coverage() -> Rect2:
	return _coverage

func extended(surface_shapes: Array[FeatureGroundShape],
		clearance_shapes: Array[FeatureGroundShape],
		additional_payload: EnvironmentInstancePayload,
		ownership: Rect2) -> FeatureContext:
	assert(additional_payload != null)
	var combined_payload := _payload.duplicate_payload()
	combined_payload.append_from(additional_payload, ownership)
	var result := FeatureContext.new(_coverage,
		_ground.extended(surface_shapes, clearance_shapes), combined_payload,
		connection_masks, node_cells, bridge_cells)
	result.garden_support_regions = garden_support_regions.duplicate()
	result.terrain_grades.assign(terrain_grades)
	return result

func garden_grass_supports() -> Array[Dictionary]:
	var by_id := {}
	for region: Dictionary in garden_support_regions: by_id[region.id] = region
	for mesh: Dictionary in _payload.surface_meshes:
		for region: Dictionary in mesh.get("garden_grass_regions",[]): by_id[region.id] = region
	var supports: Array[Dictionary] = []
	supports.assign(by_id.values())
	return supports
