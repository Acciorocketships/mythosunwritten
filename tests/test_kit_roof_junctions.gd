extends GutTest
const JOIN := preload("res://scripts/terrain/features/villages/kit/KitRoofJunctions.gd")

func test_neighbors_share_one_continuous_roof() -> void:
	var a := BuildingMass.new()
	var b := BuildingMass.new()
	a.add_roof(Rect2i(0, 0, 4, 4), 0, 4, &"red")
	b.add_roof(Rect2i(5, 0, 3, 4), 0, 4, &"blue")
	var masses: Array[BuildingMass] = [a, b]
	assert_eq(JOIN.join(masses), 1)
	assert_eq(a.roofs.size() + b.roofs.size(), 1)
	assert_eq(a.roofs[0].rect, Rect2i(0, 0, 8, 4))

func test_join_respects_street_headroom_and_different_roof_datums() -> void:
	var a := BuildingMass.new()
	var b := BuildingMass.new()
	a.add_roof(Rect2i(0, 0, 4, 4), 0, 4, &"red")
	b.add_roof(Rect2i(5, 0, 3, 4), 0, 4, &"red")
	var masses: Array[BuildingMass] = [a, b]
	assert_eq(JOIN.join(masses, func(_cell: Vector2i, _band: int) -> bool: return false), 0)
	b.roofs[0].eave_band = 6
	assert_eq(JOIN.join(masses), 0)

func test_boring_retains_short_supported_tunnels_without_reducing_headroom() -> void:
	var columns := {}
	for x in range(22):
		for z in range(3): columns[Vector2i(x, z)] = {"base": 0, "top": 12}
	var massif := WarrenMassif.with_columns(17, columns, 12)
	var excavation := WarrenExcavation.new(17)
	for x in range(1, 21):
		var cell := Vector3i(x, 0, 1)
		excavation.route.append(cell)
		for y in 3: excavation.carved[Vector3i(x, y, 1)] = true
	WarrenMazeCarver._open_passages_to_air(17, massif, excavation, [],
		WarrenVillageScaleProfile.for_id(&"compact"))
	var bridge_cells := {}
	for span: Array in excavation.bridge_spans:
		for cell: Vector3i in span: bridge_cells[cell] = true
	var covered := 0
	var open := 0
	for cell: Vector3i in excavation.route:
		for y in 3: assert_true(excavation.carved.has(cell + Vector3i.UP * y))
		if not excavation.carved.has(cell + Vector3i.UP * 3) and not bridge_cells.has(cell): covered += 1
		if excavation.carved.has(cell + Vector3i.UP * 11): open += 1
	assert_gte(covered, 3, "natural tunnels remain independently of bridge-house quotas")
	assert_gt(open, covered, "daylit street breaks separate the short tunnels")

func test_cross_house_wing_reaches_host_and_withdraws_buried_gable() -> void:
	var a := BuildingMass.new()
	var b := BuildingMass.new()
	a.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	b.add_roof(Rect2i(2, 5, 2, 3), 1, 4, &"blue")
	var masses: Array[BuildingMass] = [a, b]
	assert_eq(JOIN.join(masses), 1)
	assert_true(b.roofs[0].open_min)
	assert_eq(b.roofs[0].extend_min, 2)
	assert_eq(b.roofs[0].colour, &"red")

func test_triangle_subtraction_preserves_uv_and_removes_only_buried_geometry() -> void:
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var surface := {"vertices": PackedVector3Array([Vector3(-2, 1, 0), Vector3(2, 1, 0), Vector3(0, 1, 3)]),
		"normals": PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
		"uvs": PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, 3)]),
		"indices": PackedInt32Array([0, 1, 2])}
	var box := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 3))
	var cutters: Array[Dictionary] = [union_script.box_volume(box)]
	var result := union_script.trim_surface(surface, Transform3D.IDENTITY, cutters)
	assert_gt(result.vertices.size(), 3)
	for i in result.vertices.size():
		var p: Vector3 = result.vertices[i]
		assert_almost_eq(result.uvs[i], Vector2(p.x, p.z), Vector2.ONE * 0.0001)
	for i in range(0, result.vertices.size(), 3):
		var centre: Vector3 = (result.vertices[i] + result.vertices[i + 1] + result.vertices[i + 2]) / 3.0
		assert_false(box.grow(-0.0001).has_point(centre))

func test_native_cross_roof_triangles_are_trimmed_with_matching_collision() -> void:
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var kit := SuntailBuildingKit.create()
	var a := BuildingMass.new()
	a.stable_id = &"host"
	var b := BuildingMass.new()
	b.stable_id = &"branch"
	a.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	b.add_roof(Rect2i(2, 4, 2, 3), 1, 4, &"blue")
	var masses: Array[BuildingMass] = [a, b]
	JOIN.join(masses)
	var roofs: Array[Dictionary] = [a.roofs[0], b.roofs[0]]
	var placements: Array[Dictionary] = []
	for i in masses.size():
		roofs[i].union_index = i
		placements.append_array(BuildingKitAssembler.new(kit).assemble(masses[i]))
	var data: Dictionary = FileAccess.open(union_script.DATA_PATH, FileAccess.READ).get_var()
	var buried_before := 0
	var buried_after := 0
	for placement: Dictionary in placements:
		if not data.has(placement.asset_id): continue
		var other := union_script.roof_volume(roofs[1 - int(placement.roof_index)], kit)
		for surface: Dictionary in data[placement.asset_id]:
			var raw := surface.duplicate(true)
			raw.vertices = placement.transform * raw.vertices
			buried_before += _buried_triangles(raw, other.planes)
			var cutters: Array[Dictionary] = [other]
			var trimmed := union_script.trim_surface(surface, placement.transform, cutters)
			buried_after += _buried_triangles(trimmed, other.planes)
	assert_gt(buried_before, 20, "native overlapping assets reproduce the reported defect")
	assert_eq(buried_after, 0, "no triangle centroid remains buried in the other roof")
	var payload := EnvironmentInstancePayload.new()
	union_script.append(placements, roofs, [], kit, Transform3D.IDENTITY, payload)
	assert_true(payload.validate())
	assert_gt(payload.surface_meshes.size(), 0)
	for mesh: Dictionary in payload.surface_meshes:
		assert_eq(mesh.collision_faces.size(), mesh.indices.size())
		assert_eq(mesh.tangents.size(), mesh.vertices.size() * 4)
		for i in mesh.vertices.size():
			var t := Vector3(mesh.tangents[i * 4], mesh.tangents[i * 4 + 1], mesh.tangents[i * 4 + 2])
			assert_almost_eq(t.length(), 1.0, 0.001)
			assert_almost_eq(t.dot(mesh.normals[i]), 0.0, 0.001)
		for i in mesh.indices.size():
			assert_eq(mesh.collision_faces[i], mesh.vertices[mesh.indices[i]])

func _buried_triangles(surface: Dictionary, planes: Array) -> int:
	var count := 0
	for i in range(0, surface.indices.size(), 3):
		var centre := Vector3.ZERO
		for k in 3: centre += surface.vertices[surface.indices[i + k]] / 3.0
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(centre) >= -0.0002: inside = false
		count += int(inside)
	return count

func test_joined_native_roof_has_no_open_seam() -> void:
	await _assert_closed_roof(Rect2i(2, 4, 2, 3), 1)

func test_stepped_parallel_roofs_have_no_open_seam() -> void:
	await _assert_closed_roof(Rect2i(6, 0, 3, 2), 0)

func _assert_closed_roof(branch_rect: Rect2i, axis: int) -> void:
	var kit := SuntailBuildingKit.create()
	var a := BuildingMass.new()
	a.stable_id = &"host"
	var b := BuildingMass.new()
	b.stable_id = &"branch"
	a.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	b.add_roof(branch_rect, axis, 4, &"red")
	var masses: Array[BuildingMass] = [a, b]
	JOIN.join(masses)
	var roofs: Array[Dictionary] = [a.roofs[0], b.roofs[0]]
	var placements: Array[Dictionary] = []
	for i in masses.size():
		roofs[i].union_index = i
		placements.append_array(BuildingKitAssembler.new(kit).assemble(masses[i]))
	var payload := EnvironmentInstancePayload.new()
	preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").append(
		placements, roofs, [], kit, Transform3D.IDENTITY, payload)
	var stage := Node3D.new()
	add_child_autofree(stage)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	EnvironmentCollisionBuilder.commit(stage, payload, cache, &"native")
	var body := StaticBody3D.new()
	stage.add_child(body)
	for mesh: Dictionary in payload.surface_meshes:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mesh.collision_faces)
		var instance := CollisionShape3D.new()
		instance.shape = shape
		body.add_child(instance)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	var misses: Array[Vector2] = []
	for xi in range(1, 72):
		for zi in range(1, 56):
			# Avoid rays exactly on native mesh triangle/instance boundaries;
			# those are ambiguous in Godot's triangle intersection kernel.
			var p := Vector2(xi * 0.25 + 0.013, zi * 0.25 + 0.017)
			if not (Rect2(0, 0, 12, 8).has_point(p) or Rect2(Vector2(branch_rect.position) * 2, Vector2(branch_rect.size) * 2).has_point(p)): continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(p.x, 20, p.y), Vector3(p.x, 5.9, p.y)))
			if hit.is_empty(): misses.append(p)
	assert_eq(misses.size(), 0, "native union stays closed, missing rays: %s" % str(misses.slice(0, 12)))
