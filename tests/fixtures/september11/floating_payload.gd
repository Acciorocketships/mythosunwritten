extends RefCounted

static func read(before: bool) -> Dictionary:
	var name := "baseline" if before else "candidate"
	return FileAccess.open("res://docs/qa/2026-09-11-manual/05-floating/%s-payload.bin" % name, FileAccess.READ).get_var()

static func payload(data: Dictionary, before: bool) -> EnvironmentInstancePayload:
	var result := EnvironmentInstancePayload.new()
	result.collision_boxes.assign(data.collision_boxes)
	result.surface_meshes.assign(data.surface_meshes)
	for asset: StringName in data.batches:
		var batch: Dictionary = data.batches[asset]
		for index in batch.transforms.size():
			var id := String(batch.ids[index])
			# The baseline layout was frozen after the rejected compact-knee trial.
			# The original room-support recipes emitted no geometry at these IDs.
			if before and id.contains("spatial.feature.room_overhang.") and id.contains("/knee."):
				continue
			result.add(asset, batch.transforms[index], batch.colors[index], batch.ids[index], batch.collision_enabled[index])
	return result
