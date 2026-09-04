class_name VillageRecord
extends RefCounted

## Sealed canonical village output. Projection may select from this record but
## never mutates or partially rebuilds it at chunk boundaries.
var stable_id: StringName
var centre: Vector2
var bounds: Rect2
var payload: EnvironmentInstancePayload
var surface_shapes: Array[FeatureGroundShape] = []
var clearance_shapes: Array[FeatureGroundShape] = []
var occupancy: Array[VillageOccupancyVolume] = []
var tier: StringName
var theme: StringName
## The route-aligned orientation remains useful to gameplay and review tools;
## complete topology lives in the typed urban transaction below.
var street_axis := Vector2.ZERO
## Canonical structural audit and topology. This is the same sealed object
## whose entries and occupancy were materialized into the record, so tools do
## not maintain a parallel legacy description of the village.
var urban_fabric: VillageUrbanFabricPlan
var outskirts: VillageOutskirtsPlan
var prop_results: Dictionary = {}

func _init(p_stable_id: StringName, p_centre: Vector2, p_bounds: Rect2,
		p_payload: EnvironmentInstancePayload,
		p_surface_shapes: Array[FeatureGroundShape],
		p_clearance_shapes: Array[FeatureGroundShape],
		p_occupancy: Array[VillageOccupancyVolume]) -> void:
	assert(not p_stable_id.is_empty() and p_payload != null)
	stable_id = p_stable_id
	centre = p_centre
	bounds = p_bounds
	payload = p_payload
	surface_shapes.assign(p_surface_shapes)
	clearance_shapes.assign(p_clearance_shapes)
	occupancy.assign(p_occupancy)
	surface_shapes.sort_custom(_shape_less)
	clearance_shapes.sort_custom(_shape_less)
	occupancy.sort_custom(func(a: VillageOccupancyVolume,
			b: VillageOccupancyVolume) -> bool:
		return String(a.stable_id) < String(b.stable_id))

func validate(program: VillageProgram) -> bool:
	if program == null or not payload.validate() or not bounds.has_area():
		return false
	var permitted := program.record_bound(centre).grow(0.001)
	if not permitted.encloses(bounds):
		return false
	for shape: FeatureGroundShape in surface_shapes + clearance_shapes:
		if shape.stable_id.is_empty():
			return false
	if not street_axis.is_normalized():
		return false
	if urban_fabric == null or not urban_fabric.validate(program, tier):
		return false
	if urban_fabric.accepted and urban_fabric.requires_outskirts():
		if outskirts == null \
				or not outskirts.validate(program.outskirts_program, tier):
			return false
	elif outskirts != null:
		# A sectional diagnostic owns its complete bounded composition. Production
		# volumetric towns opt in above and receive only the sealed ground-house
		# grammar; detached tents and incidental props remain suppressed.
		return false
	if not urban_fabric.accepted and not is_empty():
		# A rejected structural solve cannot leave a tent or prop masquerading as
		# a village. Rejection is represented by one genuinely empty record.
		return false
	for key: Variant in prop_results:
		if StringName(key).is_empty() \
				or StringName(prop_results[key]).is_empty():
			return false
	return true

func is_empty() -> bool:
	return payload.instance_count == 0 and payload.collision_boxes.is_empty() \
		and payload.surface_meshes.is_empty() \
		and surface_shapes.is_empty() \
		and clearance_shapes.is_empty() and occupancy.is_empty()

static func _shape_less(a: FeatureGroundShape,
		b: FeatureGroundShape) -> bool:
	return String(a.stable_id) < String(b.stable_id)
