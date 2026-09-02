class_name VillageAttachedAssetSpec
extends RefCounted

## A stable, contained visual/physical component of one semantic village lot.
## Containment lets the parent lot's occupancy and terrain qualification prove
## the whole composite at once; a component that extends beyond that contract
## must become its own prop slot instead of bypassing layout validation.
var stable_key: StringName
var asset_id: StringName
var local_transform: Transform3D
var measured_aabb: AABB
var theme_asset_ids: Dictionary = {}


static func compile(data: Dictionary, catalog: EnvironmentCatalog,
		parent_aabb: AABB) -> VillageAttachedAssetSpec:
	var spec := VillageAttachedAssetSpec.new()
	spec.stable_key = StringName(data.get("key", ""))
	spec.asset_id = StringName(data.get("id", ""))
	if spec.stable_key.is_empty() or spec.asset_id.is_empty() or catalog == null:
		push_error("Village attachment requires stable key and catalog asset")
		return null
	var descriptor := catalog.descriptor(spec.asset_id)
	if descriptor == null or not (descriptor.tags.has(&"village_prop") \
			or descriptor.tags.has(&"prefab_attachment")) \
			or descriptor.collision_piece_count <= 0:
		push_error("Village attachment must be a collidable village component: %s" \
			% String(spec.asset_id))
		return null
	spec.measured_aabb = descriptor.measured_aabb
	var offset := _vector3(data.get("local_offset", Vector3.ZERO))
	var yaw := float(data.get("local_yaw", 0.0))
	if not offset.is_finite() or not is_finite(yaw):
		push_error("Village attachment transform must be finite: %s" \
			% String(spec.asset_id))
		return null
	spec.local_transform = Transform3D(Basis(Vector3.UP, yaw), offset)
	var authored_variants: Dictionary = data.get("theme_variants", {})
	for theme: StringName in VillageProgram.THEMES:
		var variant_id := StringName(authored_variants.get(theme,
			spec.asset_id))
		var variant_descriptor := catalog.descriptor(variant_id)
		if variant_descriptor == null \
				or not (variant_descriptor.tags.has(&"village_prop") \
					or variant_descriptor.tags.has(&"prefab_attachment")) \
				or variant_descriptor.collision_piece_count <= 0 \
				or not _same_bounds(spec.measured_aabb,
					variant_descriptor.measured_aabb):
			push_error("Village attachment theme variants must preserve collidable bounds: %s/%s" \
				% [String(theme), String(variant_id)])
			return null
		spec.theme_asset_ids[theme] = variant_id
	var component_bounds := spec.local_transform * spec.measured_aabb
	if not parent_aabb.grow(0.02).encloses(component_bounds):
		push_error("Village attachment escapes its parent occupancy: %s" \
			% String(spec.asset_id))
		return null
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


func world_transform(parent_transform: Transform3D) -> Transform3D:
	return parent_transform * local_transform


func local_reach() -> float:
	var bounds := local_transform * measured_aabb
	var reach := 0.0
	for x: float in [bounds.position.x, bounds.end.x]:
		for z: float in [bounds.position.z, bounds.end.z]:
			reach = maxf(reach, Vector2(x, z).length())
	return reach


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(NAN, NAN, NAN)


static func _same_bounds(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) \
		and a.size.is_equal_approx(b.size)
