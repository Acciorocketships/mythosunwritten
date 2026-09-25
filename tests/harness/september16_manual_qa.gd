extends "res://tests/harness/september15_reported_qa.gd"
## September 16 noon reports; IDs match the attachment register.
func _spots() -> Array:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/photo-poses.json"))
	var result := []
	for entry: Dictionary in records:
		# P14 has no crosshair hit. Do not invent a matched camera for it.
		if entry.crosshair == null: continue
		result.append([entry.id, entry.source, Vector3(entry.player[0],entry.player[1],entry.player[2]),
			Vector3(entry.crosshair[0],entry.crosshair[1],entry.crosshair[2])])
	return result

func _capture_views(world: Node3D) -> void:
	if not _frozen:
		var samplers := []
		var seen := {}
		for owner: Node in get_tree().get_nodes_in_group("water_volume"):
			if not owner.has_meta("sampler"): continue
			var sampler: WaterSampler = owner.get_meta("sampler")
			if seen.has(sampler.get_instance_id()): continue
			seen[sampler.get_instance_id()] = true
			var data := {}
			for property: Dictionary in sampler.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: data[property.name] = sampler.get(property.name)
			samplers.append(data)
		FileAccess.open(_output_dir.path_join("samplers.bin"),FileAccess.WRITE).store_var(samplers)
	await super._capture_views(world)
