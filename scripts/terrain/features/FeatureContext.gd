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

func clearance_at(world_xz: Vector2) -> float:
	return _ground.clearance_at(world_xz)

## Exact projected-footprint query for objects whose visual body is larger
## than their anchor. Keeping this on the shared ground field means every
## dressing family gets the same reservation semantics without knowing which
## feature (road, village, or a future authored structure) owns the space.
func overlaps_clearance(shape: FeatureGroundShape, margin: float = 0.0) -> bool:
	return _ground.overlaps_clearance(shape, margin)

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
	return FeatureContext.new(_coverage,
		_ground.extended(surface_shapes, clearance_shapes), combined_payload,
		connection_masks, node_cells, bridge_cells)
