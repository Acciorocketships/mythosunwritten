class_name VillageFrame
extends RefCounted

## Canonical inputs to village layout. This contains no rolls or placements;
## the same accepted route signature always feeds the same later record build.
const _DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT,
]
const _BITS := {
	Vector2i.RIGHT: 1, Vector2i.LEFT: 2,
	Vector2i.DOWN: 4, Vector2i.UP: 8,
}

var settlement_id: StringName
var cell: Vector2i
var centre: Vector2
var incident_directions: Array[Vector2i] = []
var dominant_axis: Vector2i
var connection_signature: StringName
var region: HeightfieldRegion
var water: WaterFieldContext
var path_ground: FeatureGroundField

static func build(node: Dictionary, context: FeatureContext,
		p_region: HeightfieldRegion,
		p_water: WaterFieldContext, canonical_mask: int = -1) -> VillageFrame:
	assert(not node.is_empty() and context != null)
	var projected_mask := int(context.connection_masks.get(node.cell, 0))
	var frame := from_mask(node, projected_mask if canonical_mask < 0 \
		else canonical_mask, p_region, p_water)
	frame.path_ground = context.ground_field()
	return frame

static func from_mask(node: Dictionary, mask: int,
		p_region: HeightfieldRegion,
		p_water: WaterFieldContext) -> VillageFrame:
	assert(not node.is_empty())
	assert(p_region != null and p_water != null)
	var frame := VillageFrame.new()
	frame.settlement_id = node.id
	frame.cell = node.cell
	frame.centre = Vector2(frame.cell) * TerrainSurfaceField.TILE
	frame.region = p_region
	frame.water = p_water
	for direction: Vector2i in _DIRECTIONS:
		if (mask & int(_BITS[direction])) != 0:
			frame.incident_directions.append(direction)
	var horizontal := int((mask & 1) != 0) + int((mask & 2) != 0)
	var vertical := int((mask & 4) != 0) + int((mask & 8) != 0)
	frame.dominant_axis = Vector2i.RIGHT if horizontal >= vertical \
		else Vector2i.DOWN
	frame.connection_signature = StringName("%s:%02x" % [
		String(frame.settlement_id), mask])
	return frame

func is_dormant() -> bool:
	return incident_directions.is_empty()
