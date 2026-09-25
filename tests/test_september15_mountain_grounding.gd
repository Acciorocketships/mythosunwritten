extends GutTest

const Study = preload("res://tests/harness/september15_mountain_study.gd")

func test_every_placed_formation_buries_its_actual_native_foot_in_the_ground() -> void:
	var study := Study.new()
	study._catalogue = true
	study._composition()
	assert_gt(study._forms.size(), 10, "Survey the whole assembled valley")
	for form: Dictionary in study._forms:
		var source: Dictionary = study._cache[study._mountain_source+form.name+".glb"]
		var bounds: AABB = source.bounds
		var highest_exposed := -INF
		var samples := 0
		for piece: Dictionary in source.pieces:
			for local: Vector3 in piece.faces:
				if local.y > bounds.position.y+.25: continue
				var point: Vector3 = form.transform*local
				highest_exposed = maxf(highest_exposed, point.y-study._height(point.x,point.z))
				samples += 1
		assert_gt(samples, 30, "Actual complete bottom vertices: "+str(form.transform.origin))
		assert_lt(highest_exposed, .01, "No exposed/floating base: "+form.name+str(form.transform.origin))
		print("MOUNTAIN_BASE ",form.name," ",form.transform.origin," samples=",samples," highest=",highest_exposed)
	study.free()
