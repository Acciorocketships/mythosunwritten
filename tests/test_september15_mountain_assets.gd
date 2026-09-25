extends GutTest

const NAMES := ["pillar_slender", "pillar_split", "pillar_crown", "buttress_tall", "buttress_wide", "shelf_long", "shelf_end", "shelf_corner"]

func test_original_mountain_kit_has_complete_catalogue_and_matching_collision() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for suffix: String in NAMES:
		var descriptor := catalog.descriptor(StringName("mythos.mountain." + suffix))
		assert_not_null(descriptor, suffix)
		if descriptor == null: continue
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		assert_eq(visual.pieces.size(), 1, "Merged runtime mesh: " + suffix)
		assert_eq(visual.collisions.size(), 1, "One physical owner: " + suffix)
		if visual.pieces.size() != 1 or visual.collisions.size() != 1: continue
		var piece := visual.pieces[0]
		assert_true(piece.material_override is ShaderMaterial, "Authored limestone/moss material")
		assert_true(visual.collisions[0].shape is ConcavePolygonShape3D, "Complete native triangle collision")
		var physical: PackedVector3Array = visual.collisions[0].shape.get_faces()
		var rendered := piece.mesh.get_faces()
		assert_eq(physical.size(), rendered.size(), "Every visual triangle has collision: " + suffix)
		var max_error := 0.0
		for i in mini(physical.size(), rendered.size()): max_error=maxf(max_error, physical[i].distance_to(rendered[i]))
		print("MOUNTAIN_IMPORT_ERROR ", suffix, " ", max_error)
		assert_lt(max_error, .0001, "Mesh compression stays below 0.1 mm, including shelves: " + suffix)
		assert_lt(rendered.size() / 3, 15000, "Native mesh budget")
		var finite := true
		for point: Vector3 in physical: finite = finite and point.is_finite()
		assert_true(finite, "Finite collision")
		# Survey native geometry from above and all four compass directions. These
		# independently ray-test render and physics arrays; no box substitutes.
		var bounds := descriptor.measured_aabb
		for direction: Vector3 in [Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var centre := bounds.get_center()
			if direction.y == 0: centre.y = bounds.position.y + bounds.size.y * .22
			var start := centre - direction * 150.0
			var a := _nearest(rendered, start, direction)
			var b := _nearest(physical, start, direction)
			assert_lt(a, INF, "Real face under survey ray: " + suffix + str(direction))
			assert_almost_eq(a, b, .001, "Oblique ray amplification stays below 1 mm")

func _nearest(faces: PackedVector3Array, origin: Vector3, direction: Vector3) -> float:
	var distance := INF
	for i in range(0, faces.size(), 3):
		var point = Geometry3D.ray_intersects_triangle(origin, direction, faces[i], faces[i+1], faces[i+2])
		if point != null: distance = minf(distance, origin.distance_to(point))
	return distance

func test_catalogue_contains_current_authored_glb_geometry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for suffix: String in NAMES:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert_eq(document.append_from_file("res://assets/MythosMountains/"+suffix+".glb", state), OK)
		var root := document.generate_scene(state)
		var count := 0
		var bounds := AABB()
		var first := true
		for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			count += node.mesh.get_faces().size()
			bounds = node.mesh.get_aabb() if first else bounds.merge(node.mesh.get_aabb())
			first = false
		var descriptor := catalog.descriptor(StringName("mythos.mountain."+suffix))
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		assert_eq(visual.pieces[0].mesh.get_faces().size(), count, "Fresh source triangle count: "+suffix)
		assert_lt(descriptor.measured_aabb.position.distance_to(bounds.position), .001, "Fresh source minimum: "+suffix)
		assert_lt(descriptor.measured_aabb.end.distance_to(bounds.end), .001, "Fresh source maximum: "+suffix)
		root.free()
