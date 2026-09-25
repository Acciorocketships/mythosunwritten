extends GutTest

const TERRACES = preload("res://scripts/terrain/field/CliffTerraces.gd")

func test_native_terrain_caps_keep_exact_tops_without_exposed_undersides() -> void:
	TERRACES.prepare()
	for suffix: String in TERRACES.SIZES+TERRACES.LAYER_SIZES:
		var definition: Dictionary = TERRACES._definitions[StringName("kaykit.terrace.%s" % suffix)]
		var bounds: AABB = definition.bounds
		var native: PackedVector3Array = definition.faces
		var physical: PackedVector3Array = definition.collision_faces
		var native_tops := PackedVector3Array()
		var physical_tops := PackedVector3Array()
		var exposed_undersides := 0
		var maximum_vertical_drift := 0.0
		for i in range(0, native.size(), 3):
			if absf(native[i].y - bounds.end.y) < .001 and absf(native[i + 1].y - bounds.end.y) < .001 and absf(native[i + 2].y - bounds.end.y) < .001:
				native_tops.append_array(native.slice(i, i + 3))
		for i in range(0, physical.size(), 3):
			var a := physical[i]
			var b := physical[i + 1]
			var c := physical[i + 2]
			var normal := (c - a).cross(b - a).normalized()
			if normal.y < -.01 and maxf(a.y, maxf(b.y, c.y)) > bounds.position.y + .001:
				exposed_undersides += 1
			if absf(a.y - bounds.end.y) < .001 and absf(b.y - bounds.end.y) < .001 and absf(c.y - bounds.end.y) < .001:
				physical_tops.append_array(physical.slice(i, i + 3))
			elif absf(normal.y) < .99:
				maximum_vertical_drift = maxf(maximum_vertical_drift, absf(normal.y))
		assert_gt(native_tops.size(), 0, suffix)
		assert_eq(physical_tops, native_tops, "The authored flat top retains every actual triangle: " + suffix)
		assert_eq(exposed_undersides, 0, "Only the buried column base may face downward: " + suffix)
		assert_lt(maximum_vertical_drift, .0001, "Sides use ordinary vertical terrain collision: " + suffix)
		assert_lt(physical.size(), native.size(), "The terrain profile reduces decorative collision cost: " + suffix)

func test_terrain_collision_preserves_closed_edges_and_native_rock_faces() -> void:
	TERRACES.prepare()
	for suffix: String in TERRACES.SIZES+TERRACES.LAYER_SIZES:
		var definition: Dictionary = TERRACES._definitions[StringName("kaykit.terrace.%s" % suffix)]
		var edges := {}
		var faces: PackedVector3Array = definition.collision_faces
		for i in range(0, faces.size(), 3):
			for j in 3:
				var a := faces[i + j].snapped(Vector3.ONE * .00001)
				var b := faces[i + (j + 1) % 3].snapped(Vector3.ONE * .00001)
				var key := [a, b]
				if b < a: key.reverse()
				edges[key] = int(edges.get(key, 0)) + 1
		var open_edges := 0
		for count: int in edges.values():
			if count != 2: open_edges += 1
		assert_eq(open_edges, 0, "The physical cap is closed along every edge: " + suffix)
	var rock: Dictionary = TERRACES._definitions[TERRACES.ROCK]
	assert_eq(rock.collision_faces, rock.faces, "Rock props keep their native collision")
