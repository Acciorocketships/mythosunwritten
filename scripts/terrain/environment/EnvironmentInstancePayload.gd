class_name EnvironmentInstancePayload
extends RefCounted

## Worker-safe, render-resource-free instances grouped by stable asset ID.
## A batch is either entirely anonymous or carries one stable ID per transform.
var batches: Dictionary = {}
var instance_count := 0

func add(asset_id: StringName, transform: Transform3D, color: Color,
		stable_id: StringName = &"") -> void:
	if not batches.has(asset_id):
		batches[asset_id] = {"transforms": [], "colors": [], "ids": []}
	var batch: Dictionary = batches[asset_id]
	var identified := not stable_id.is_empty()
	assert(batch.transforms.is_empty() or identified == not batch.ids.is_empty(),
		"One environment batch cannot mix identified and anonymous instances")
	batch.transforms.append(transform)
	batch.colors.append(color)
	if identified:
		batch.ids.append(stable_id)
	instance_count += 1

func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(batches.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

func validate() -> bool:
	var total := 0
	for asset_id: StringName in asset_ids():
		var batch: Dictionary = batches[asset_id]
		if batch.transforms.size() != batch.colors.size():
			return false
		if not batch.ids.is_empty() and batch.ids.size() != batch.transforms.size():
			return false
		total += batch.transforms.size()
	return total == instance_count
