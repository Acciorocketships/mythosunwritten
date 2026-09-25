class_name VillagePropSpec
extends RefCounted

## Resource-free footprint and terrain contract for a standalone village prop.
## Props use the same occupancy/clearance transaction as structures but do not
## pretend to own a doorway, interior, or foundation.
var asset_id: StringName
var measured_aabb: AABB
var solid_local_rect: Rect2
var ground_contact_local_rect: Rect2
var lot_local_rect: Rect2
var facing_local: Vector2
var max_ground_relief: float
var theme_asset_ids: Dictionary = {}


static func compile(data: Dictionary,
		catalog: EnvironmentCatalog) -> VillagePropSpec:
	var spec := VillagePropSpec.new()
	spec.asset_id = StringName(data.get("id", ""))
	if spec.asset_id.is_empty() or catalog == null:
		push_error("Village prop requires a stable catalog asset ID")
		return null
	var descriptor := catalog.descriptor(spec.asset_id)
	if descriptor == null or not descriptor.tags.has(&"village_prop") \
			or descriptor.collision_piece_count <= 0:
		push_error("Village prop must be collidable and tagged village_prop: %s" \
			% String(spec.asset_id))
		return null
	spec.measured_aabb = descriptor.measured_aabb
	spec.solid_local_rect = Rect2(Vector2(spec.measured_aabb.position.x,
		spec.measured_aabb.position.z), Vector2(spec.measured_aabb.size.x,
		spec.measured_aabb.size.z))
	spec.ground_contact_local_rect = _rect2(data.get("ground_contact_rect", null))
	if not _valid_rect(spec.ground_contact_local_rect) \
			or not spec.solid_local_rect.grow(0.01).encloses(
				spec.ground_contact_local_rect):
		push_error("Village prop requires a reviewed ground contact: %s" \
			% String(spec.asset_id))
		return null
	var padding := float(data.get("lot_padding", 0.4))
	spec.max_ground_relief = float(data.get("max_ground_relief", 0.25))
	if not is_finite(padding) or padding < 0.0 \
			or not is_finite(spec.max_ground_relief) \
			or spec.max_ground_relief < 0.0:
		push_error("Village prop padding/relief must be finite and non-negative")
		return null
	spec.lot_local_rect = spec.solid_local_rect.grow(padding)
	spec.facing_local = _vector2(data.get("facing_local", Vector2.DOWN))
	if not spec.facing_local.is_finite() \
			or not is_equal_approx(spec.facing_local.length(), 1.0):
		push_error("Village prop facing must be a finite unit vector")
		return null
	var variants: Dictionary = data.get("theme_variants", {})
	for theme: StringName in VillageProgram.THEMES:
		var runtime_id := StringName(variants.get(theme, spec.asset_id))
		var runtime_descriptor := catalog.descriptor(runtime_id)
		if runtime_descriptor == null \
				or not runtime_descriptor.tags.has(&"village_prop") \
				or runtime_descriptor.collision_piece_count <= 0 \
				or not _same_bounds(spec.measured_aabb,
					runtime_descriptor.measured_aabb):
			push_error("Village prop theme variants must preserve collidable bounds: %s/%s" \
				% [String(theme), String(runtime_id)])
			return null
		spec.theme_asset_ids[theme] = runtime_id
	return spec


func asset_for_theme(theme: StringName) -> StringName:
	assert(theme_asset_ids.has(theme))
	return theme_asset_ids[theme]


func runtime_asset_ids() -> Array[StringName]:
	var unique: Dictionary = {}
	for runtime_id: StringName in theme_asset_ids.values():
		unique[runtime_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


func placement_for(anchor: Vector2, desired_facing: Vector2,
		ground_y: float) -> Transform3D:
	assert(desired_facing.is_normalized())
	var yaw := facing_local.angle() - desired_facing.angle()
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(anchor.x,
		ground_y - measured_aabb.position.y, anchor.y))


func world_solid(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, solid_local_rect)


func world_contact(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, ground_contact_local_rect)


func world_lot(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, lot_local_rect)


func local_reach() -> float:
	var reach := 0.0
	for point: Vector2 in [lot_local_rect.position,
			Vector2(lot_local_rect.end.x, lot_local_rect.position.y),
			lot_local_rect.end,
			Vector2(lot_local_rect.position.x, lot_local_rect.end.y)]:
		reach = maxf(reach, point.length())
	return reach


static func _world_rect(transform: Transform3D, rect: Rect2) -> Dictionary:
	var local_centre := rect.get_center()
	var point := transform * Vector3(local_centre.x, 0.0, local_centre.y)
	var local_x := transform.basis * Vector3.RIGHT
	return {
		"centre": Vector2(point.x, point.z),
		"half_extents": rect.size * 0.5,
		"angle": Vector2(local_x.x, local_x.z).angle(),
	}


static func _rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Array and value.size() == 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]),
			float(value[3]))
	return Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))


static func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(NAN, NAN)


static func _valid_rect(value: Rect2) -> bool:
	return value.position.is_finite() and value.size.is_finite() \
		and value.size.x > 0.0 and value.size.y > 0.0


static func _same_bounds(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) \
		and a.size.is_equal_approx(b.size)
