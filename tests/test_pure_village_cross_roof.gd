extends GutTest
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossRoof.gd")


func _triangles(
	root: Node3D, roof_only: bool = true, attic_only: bool = false
) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if roof_only and not String(mesh.name).begins_with("Roof_"):
			continue
		if (
			attic_only
			and not (String(mesh.name).contains("_30x10_") or String(mesh.name).contains("_15x10_"))
		):
			continue
		var local := mesh.mesh.get_faces()
		for vertex: Vector3 in local:
			out.append(mesh.global_transform * vertex)
	return out


func _hit(vertices: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	for index in range(0, vertices.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				a, b, vertices[index], vertices[index + 1], vertices[index + 2]
			)
			!= null
		):
			return true
	return false


func test_extended_arms_and_valleys_remain_covered_by_actual_roof_triangles() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]:
		var roof := Roof.instantiate(dimensions.x, dimensions.y)
		add_child(roof)
		var triangles := _triangles(roof)
		# Dense transverse probes cross base/cornice joints, central valleys,
		# and all new longitudinal module seams. Leave the outer verge out.
		for axis in 2:
			var length := dimensions[axis] * 3.0 + 1.5
			for along_index in range(int(length * 4) + 1):
				var along := -length + along_index * .5
				for across in [-3.75, -3.0, -2.25, -1.5, -.75, 0.0, .75, 1.5, 2.25, 3.0, 3.75]:
					var at := (
						Vector3(along, 12, across) if axis == 0 else Vector3(across, 12, along)
					)
					at.x -= .125
					assert_true(
						_hit(triangles, at, at - Vector3.UP * 10),
						"Uncovered cross roof %s at %s" % [dimensions, at]
					)
		roof.free()


func test_gables_close_each_arm_at_both_peak_and_lower_curved_course() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]:
		var roof := Roof.instantiate(dimensions.x, dimensions.y)
		add_child(roof)
		var triangles := _triangles(roof, false)
		for axis in 2:
			var edge := dimensions[axis] * 3.0 + (3.0 if axis == 0 else 1.375)
			for end: int in [-1, 1]:
				for sample: Vector2 in [
					Vector2(-2, 4),
					Vector2(0, 4),
					Vector2(2, 4),
					Vector2(-.5, 7.5),
					Vector2(.5, 7.5)
				]:
					var centre := (
						Vector3(end * edge, sample.y, sample.x)
						if axis == 0
						else Vector3(sample.x, sample.y, end * edge)
					)
					centre.x -= .125
					var normal := Vector3.RIGHT if axis == 0 else Vector3.BACK
					assert_true(
						_hit(triangles, centre - normal * .3, centre + normal * .3),
						"Open gable %s at %s" % [dimensions, centre]
					)
		roof.free()


func test_short_attic_walls_cover_extended_eave_runs() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]:
		var roof := Roof.instantiate(dimensions.x, dimensions.y)
		add_child(roof)
		var triangles := _triangles(roof, false, true)
		for axis in 2:
			var far := dimensions[axis] * 3.0 + (3.0 if axis == 0 else 1.5)
			for end: int in [-1, 1]:
				for side: int in [-1, 1]:
					for index in range(int((far - 3) * 4)):
						var along := end * (3.125 + index * .25)
						for y in [3.15, 3.45, 3.7]:
							var at := (
								Vector3(along, y, side * 3.0)
								if axis == 0
								else Vector3(side * 3.0, y, along)
							)
							at.x -= .125
							var normal := Vector3.BACK if axis == 0 else Vector3.RIGHT
							assert_true(
								_hit(triangles, at - normal * .25, at + normal * .25),
								"Open attic side %s at %s" % [dimensions, at]
							)
		roof.free()
