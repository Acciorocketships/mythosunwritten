extends GutTest

## September 5, 5:51:45: the gallery view exposes these two stacked facades.
## Count actual coincident upward-facing triangles, rather than AABB contact.
## A wall/floor interface may share a boundary but cannot draw the same surface
## twice. Translate intersections before measuring area to avoid cancellation
## at the screenshot's large world coordinates.
func test_reported_upper_floor_has_one_horizontal_surface_owner() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	# Keep the photographed arrangement when the procedural massif changes.
	# Its rooms still pass through today's compiler and material ownership code.
	var fixture = preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := fixture.spatial(fixture.read(
		"res://tests/fixtures/reported-september4-source.txt"), program)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var placements: Dictionary = {}
	var fabric := _photographed_floor_interfaces(spatial.compiled_fabric_cache(), catalog)
	for placement: Dictionary in fabric.expanded_placements():
		placements[String(placement.stable_id)] = placement
	for pair: Array in [
		["spatial.fabric.spatial.maze_bridge_end.02.00.room00/floor",
			"spatial.fabric.spatial.parcel.maze.bridge.02.end.0.lower.part00.room00/west"],
		["spatial.fabric.spatial.maze_bridge_end.02.00.room00/floor",
			"spatial.fabric.spatial.parcel.maze.bridge.02.end.0.lower.part00.room00/south"],
		["spatial.fabric.spatial.maze_bridge_end.02.01.room00/floor",
			"spatial.fabric.spatial.parcel.maze.bridge.02.end.1.lower.part00.room00/east.1"],
	]:
		assert_true(placements.has(pair[0]), "retain the reported upper floor")
		assert_true(placements.has(pair[1]), "retain the reported lower facade")
		if not placements.has(pair[0]) or not placements.has(pair[1]):
			continue
		var floor_faces := _horizontal_faces(catalog, placements[pair[0]])
		var wall_faces := _horizontal_faces(catalog, placements[pair[1]])
		for cap: Dictionary in fabric.wall_cap_surfaces:
			if String(cap.stable_id).begins_with(String(pair[1]) + "/cap."):
				wall_faces.append_array(_payload_faces(cap))
		var overlap := _shared_area(floor_faces, wall_faces)
		assert_lt(overlap, 0.00001,
			"%s duplicates %.6f square metres of its upper floor" % [pair[1], overlap])
	var exposed := "spatial.fabric.spatial.parcel.maze.bridge.02.end.1.lower.part00.room00/north"
	assert_true(placements.has(exposed), "retain the exposed photographed facade")
	if placements.has(exposed):
		assert_false(String(placements[exposed].asset_id).ends_with(".course_open"),
			"a neighboring roof alone cannot erase an exposed wall cap")
	var residual_area := 0.0
	for cap: Dictionary in fabric.wall_cap_surfaces:
		if String(cap.stable_id).contains("bridge.02.end.1.lower.part00.room00/east.1/cap."):
			residual_area += _shared_area(_payload_faces(cap), _payload_faces(cap))
	assert_gt(residual_area, 0.0001, "retain the reported cap's exposed end")


func _photographed_floor_interfaces(source: SettlementFabricPlan,
		catalog: EnvironmentCatalog) -> SettlementFabricPlan:
	# Preserve the two measured September 5 upper-floor rectangles. Room
	# composition may now choose different upper rooms; that must not erase
	# the original full-cap and partial-cap regression from this test.
	var result := SettlementFabricPlan.new(&"photographed-floor-interfaces")
	for unit: FabricUnit in source.units:
		if not String(unit.stable_id).begins_with(
				"spatial.fabric.spatial.parcel.maze.bridge.02.end."):
			continue
		if not result._recipes.has(unit.recipe_id):
			assert_true(result.register_recipe(source.recipe(unit.recipe_id)))
		result.units.append(unit)
	var floor_bounds := catalog.descriptor(SettlementFabricProgram.FLOOR).measured_aabb
	for end in 2:
		var recipe_id := StringName("photographed-floor.%d" % end)
		var recipe := FabricRecipe.new(recipe_id, [&"floor"], 0)
		var minimum := Vector3(2.24898 if end == 0 else -3.75102,
			12.0 - floor_bounds.size.y, -3.75)
		recipe.add_placement(&"floor", SettlementFabricProgram.FLOOR,
			Transform3D(Basis.IDENTITY, minimum - floor_bounds.position))
		assert_true(recipe.seal(catalog), recipe.last_rejection)
		assert_true(result.register_recipe(recipe))
		result.units.append(FabricUnit.new(StringName(
			"spatial.fabric.spatial.maze_bridge_end.02.%02d.room00" % end),
			recipe_id, Vector3i.ZERO, 0))
	result._assign_wall_cap_owners()
	return result


func _payload_faces(mesh: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vertices: PackedVector3Array = mesh.vertices
	for offset in range(0, vertices.size(), 3):
		var a := vertices[offset]
		var b := vertices[offset + 1]
		var c := vertices[offset + 2]
		result.append({"y": a.y, "polygon": PackedVector2Array([
			Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])})
	return result


func _horizontal_faces(catalog: EnvironmentCatalog, placement: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
	for piece: EnvironmentVisualPiece in visual.pieces:
		var pose := (placement.transform as Transform3D) * piece.local_transform
		for surface in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(0, indices.size(), 3):
				var a := pose * vertices[indices[offset]]
				var b := pose * vertices[indices[offset + 1]]
				var c := pose * vertices[indices[offset + 2]]
				# Godot's clockwise winding makes an upward face's cross point down.
				if absf(a.y - b.y) > 0.00001 or absf(a.y - c.y) > 0.00001 \
						or (b - a).cross(c - a).y >= -0.000001:
					continue
				result.append({"y": a.y, "polygon": PackedVector2Array([
					Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])})
	return result


func _shared_area(first: Array[Dictionary], second: Array[Dictionary]) -> float:
	var area := 0.0
	for left: Dictionary in first:
		for right: Dictionary in second:
			if absf(float(left.y) - float(right.y)) > 0.00001:
				continue
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(left.polygon, right.polygon):
				for index in range(1, polygon.size() - 1):
					area += absf((polygon[index] - polygon[0]).cross(
						polygon[index + 1] - polygon[0])) * 0.5
	return area
