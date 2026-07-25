class_name GrassPayload
extends RefCounted

const FLOATS_PER_INSTANCE := 20

var tile := Vector2i.ZERO
var batches: Dictionary = {}
var instance_count := 0

func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(batches.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out

func validate() -> bool:
	if batches.size() > 1:
		return false
	var total := 0
	for asset_id: StringName in asset_ids():
		var batch: Dictionary = batches[asset_id]
		var count := int(batch.get("count", -1))
		var buffer: PackedFloat32Array = batch.get("buffer", PackedFloat32Array())
		var bounds: AABB = batch.get("aabb", AABB())
		var max_height := float(batch.get("max_height", -1.0))
		if count < 0 or buffer.size() != count * FLOATS_PER_INSTANCE \
				or not bounds.position.is_finite() or not bounds.size.is_finite() \
				or not is_finite(max_height) or max_height < 0.0:
			return false
		total += count
	return total == instance_count
