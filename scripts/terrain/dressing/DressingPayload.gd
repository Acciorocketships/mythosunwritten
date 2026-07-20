class_name DressingPayload
extends RefCounted

## Worker-safe, render-resource-free output grouped by stable asset ID.
var batches: Dictionary = {}
var instance_count: int = 0

func add(asset_id: StringName, transform: Transform3D, color: Color) -> void:
	if not batches.has(asset_id):
		batches[asset_id] = {"transforms": [], "colors": []}
	batches[asset_id].transforms.append(transform)
	batches[asset_id].colors.append(color)
	instance_count += 1

func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(batches.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
