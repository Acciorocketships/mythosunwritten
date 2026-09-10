extends GutTest

func test_deep_door_returns_keep_the_complete_native_window_in_the_remaining_bay() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/fantasy_village_door_returns.json"))
	var checked := 0
	for entry: Dictionary in manifest.assets:
		if not String(entry.id).begins_with("sfv.fabric.wall.wood.window.010"): continue
		var stock_id := "sfv.fabric.wall.wood.window.010" + (".mirror_x" if entry.has("mirror_axis") else "")
		var source := _faces(catalog, stock_id)
		var actual := _faces(catalog, String(entry.id)+".course_open")
		var depths: Array = entry.facade_return_depths
		var left := -1.5 + float(depths[0])
		var right := 1.5 - float(depths[1])
		var miter_mask := int(entry.get("facade_miter_ends",0))
		var front := catalog.descriptor(StringName(stock_id)).measured_aabb.end.z
		var missing := 0
		var witnesses := 0
		# Interior source vertices cover the actual aperture, leadwork and timber
		# frame. End-joint and course-cap vertices belong to other interfaces.
		for v: Vector3 in source:
			if absf(v.x)>1.25 or v.y<0.4 or v.y>2.6: continue
			var expected := Vector3(lerpf(left,right,(v.x+1.5)/3.0),v.y,v.z)
			# Rear vertices outside a declared corner joint are owned by the
			# perpendicular wall. The window front and all exposed frame remain.
			if (miter_mask & 1 and -expected.x-expected.z>1.5-front+0.0001) \
					or (miter_mask & 2 and expected.x-expected.z>1.5-front+0.0001): continue
			var found := false
			for a: Vector3 in actual:
				if a.distance_to(expected)<0.0004: found=true;break
			if not found: missing+=1
			witnesses+=1
		assert_gt(witnesses,50,"The test must inspect the native window's geometry")
		assert_eq(missing,0,"%s must retain the entire window instead of slicing its frame" % entry.id)
		var contained := true
		for v: Vector3 in actual:
			contained = contained and v.x>=left-0.0004 and v.x<=right+0.0004
		assert_true(contained,"The window cannot take space back from the doorway return")
		checked+=1
	assert_eq(checked,16,"Both window hands and all declared return profiles participate")

func _faces(catalog: EnvironmentCatalog, id: String) -> PackedVector3Array:
	var visual: EnvironmentVisual = load(catalog.descriptor(StringName(id)).visual_path)
	var result := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		result.append_array(piece.local_transform * piece.mesh.get_faces())
	return result
