extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model: Node3D = load("res://characters/models/mage.tscn").instantiate()
	root.add_child(model)
	var skeleton: Skeleton3D = model.get_node("Rig_Medium/Skeleton3D")
	var lib := load("res://characters/animations/CharacterAnimationLibrary.tres") as AnimationLibrary
	var result := {}
	for clip in ["Walking_A", "Running_A", "Walking_Backwards", "Running_Strafe_Left", "Running_Strafe_Right"]:
		var a := lib.get_animation(clip)
		var samples := []
		skeleton.reset_bone_poses()
		for i in range(120):
			var t := float(i) / 120.0 * a.length
			for track in range(a.get_track_count()):
				var path := a.track_get_path(track)
				if path.get_subname_count() == 0: continue
				var idx := skeleton.find_bone(path.get_subname(0))
				if idx < 0: continue
				match a.track_get_type(track):
					Animation.TYPE_POSITION_3D: skeleton.set_bone_pose_position(idx, a.position_track_interpolate(track, t))
					Animation.TYPE_ROTATION_3D: skeleton.set_bone_pose_rotation(idx, a.rotation_track_interpolate(track, t))
					Animation.TYPE_SCALE_3D: skeleton.set_bone_pose_scale(idx, a.scale_track_interpolate(track, t))
			skeleton.force_update_all_bone_transforms()
			var feet := {}
			for b in range(skeleton.get_bone_count()):
				var nm := skeleton.get_bone_name(b)
				if "foot" in nm or "toe" in nm:
					var pos := skeleton.get_bone_global_pose(b).origin
					feet[nm] = [pos.x, pos.y, pos.z]
			samples.append(feet)
		result[clip] = {"length": a.length, "loop": a.loop_mode, "samples": samples}
	var file := FileAccess.open("res://docs/qa/2026-09-10-tactical/source-gaits.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	var report := {}
	var run := _signal(result.Running_A.samples)
	for name: String in result:
		var values := _signal(result[name].samples)
		var offset := 20 if name == "Walking_A" else (90 if name == "Walking_Backwards" else 0)
		var best := 0
		for candidate in 120:
			if _error(run, values, candidate) < _error(run, values, best): best = candidate
		report[name] = {"source_duration_seconds":result[name].length,
			"original_loop_mode":result[name].loop,"best_measured_offset_cycles":float(best)/120,
			"chosen_offset_cycles":float(offset)/120,"before_squared_error":_error(run,values,0),
			"after_squared_error":_error(run,values,offset)}
	var summary := FileAccess.open("res://docs/qa/2026-09-10-tactical/phase-analysis.json", FileAccess.WRITE)
	summary.store_string(JSON.stringify(report, "  ") + "\n")
	print(JSON.stringify(report))
	model.free()
	quit()

func _signal(samples: Array) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	var norm := 0.0
	for sample: Dictionary in samples:
		var value := float(sample["foot.l"][1]) - float(sample["foot.r"][1])
		values.append(value)
		norm += value * value
	for i in values.size(): values[i] /= sqrt(norm)
	return values

func _error(a: PackedFloat64Array, b: PackedFloat64Array, offset: int) -> float:
	var result := 0.0
	for i in a.size():
		var difference := a[i] - b[(i+offset) % b.size()]
		result += difference * difference
	return result
