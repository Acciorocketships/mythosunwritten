class_name VillagePropSlotSpec
extends RefCounted

## One immutable prop candidate in the same village-local Cartesian frame as
## streets. Rejection never searches another position or moves later slots.
enum PathPolicy {
	ALLOW_BASE_SURFACE,
	AVOID_ALL_PATHS,
}

var stable_key: StringName
var asset_id: StringName
var local_anchor: Vector2
var local_facing: Vector2
var path_policy: PathPolicy


static func compile(data: Dictionary,
		assets: Dictionary) -> VillagePropSlotSpec:
	var slot := VillagePropSlotSpec.new()
	slot.stable_key = StringName(data.get("key", ""))
	slot.asset_id = StringName(data.get("asset_id", ""))
	slot.local_anchor = _vector2(data.get("local_anchor", null))
	slot.local_facing = _vector2(data.get("local_facing", Vector2.DOWN))
	slot.path_policy = int(data.get("path_policy",
		PathPolicy.AVOID_ALL_PATHS)) as PathPolicy
	if slot.stable_key.is_empty() or not assets.has(slot.asset_id) \
			or not slot.local_anchor.is_finite() \
			or slot.local_anchor.length() > VillageProgram.MAX_ANCHOR_RADIUS \
			or not slot.local_facing.is_finite() \
			or not is_equal_approx(slot.local_facing.length(), 1.0) \
			or slot.path_policy < PathPolicy.ALLOW_BASE_SURFACE \
			or slot.path_policy > PathPolicy.AVOID_ALL_PATHS:
		push_error("Village prop slot has an invalid canonical candidate")
		return null
	return slot


static func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(INF, INF)
