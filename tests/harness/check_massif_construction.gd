extends SceneTree

## Independent offline inspection. Generation never consumes these verdicts.
func _init() -> void:
	var failures := 0
	var count := 0
	var cluster_mean := 0.0
	var cluster_samples := 0
	var started := Time.get_ticks_msec()
	for profile_id: StringName in [&"compact", &"standard", &"large", &"grand"]:
		var profile := WarrenVillageScaleProfile.for_id(profile_id)
		for seed_value in range(1, 2501):
			var massif := WarrenMassifBuilder.build(seed_value, {}, profile)
			var errors := PackedStringArray()
			if massif == null:
				errors.append(WarrenMassifBuilder.last_failure)
			else:
				if not massif.validate_construction(): errors.append(massif.last_rejection)
				if massif.core_top_bands < profile.minimum_core_bands:
					errors.append("core below profile minimum")
				if massif.core_top_bands > WarrenMassif.BUILDABLE_LAYER_BANDS:
					errors.append("core above construction vocabulary")
				if massif.terrace_levels().size() < 5:
					errors.append("fewer than five terraces")
				if massif.widest_plateau_cells() > maxi(16, massif.columns.size() / 6):
					errors.append("oversized terrace")
				for column: Vector2i in massif.columns:
					for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
						Vector2i.UP, Vector2i.DOWN]:
						if absi(massif.layer_at(column) - massif.layer_at(column + direction)) > 4:
							errors.append("riser above two storeys")
							break
				if seed_value <= 12 and profile_id in [&"compact", &"standard"]:
					var unseen := massif.columns.duplicate()
					var clusters := 0
					while not unseen.is_empty():
						var queue: Array[Vector2i] = [unseen.keys()[0]]
						var layer := massif.layer_at(queue[0])
						unseen.erase(queue[0])
						var cursor := 0
						while cursor < queue.size():
							var cell := queue[cursor]
							cursor += 1
							for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
								if unseen.has(cell + d) and massif.layer_at(cell + d) == layer:
									unseen.erase(cell + d)
									queue.append(cell + d)
						clusters += 1
					cluster_mean += float(massif.columns.size()) / clusters
					cluster_samples += 1
			count += 1
			if not errors.is_empty():
				failures += 1
				if failures <= 20: print("MASSIF_FAILURE ", seed_value, "/", profile_id, " ", errors)
	cluster_mean /= maxi(1, cluster_samples)
	if cluster_mean < 3.3:
		failures += 1
		print("MASSIF_FAILURE cluster mean below 3.3")
	print("MASSIF_CONSTRUCTION count=", count, " failures=", failures,
		" cluster_mean=", cluster_mean, " elapsed_ms=", Time.get_ticks_msec() - started)
	quit(0 if failures == 0 else 1)
