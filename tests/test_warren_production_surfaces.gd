extends GutTest

## Production streaming must give every stair/ramp span the same walk surface
## the review scene shows: the sealed plan's generated transition meshes travel
## inside the ordinary instance payload and the feature commit queue builds
## their visuals and collision. A STAIR claim without a committed surface is a
## hole in the streamed town.


func _stair_transition_payload(stable_id: StringName,
		claim_cells: Array[Vector3i]) -> Dictionary:
	var vertices := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(3, 1.5, 0), Vector3(3, 1.5, 3),
		Vector3(0, 0, 3),
	])
	var normals := PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
	])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var collision := PackedVector3Array([
		vertices[0], vertices[1], vertices[2],
		vertices[0], vertices[2], vertices[3],
	])
	return {
		"stable_id": stable_id,
		"kind": PublicRealmSurfacePlan.SurfaceKind.STAIR,
		"is_transition": true,
		"claim_cells": claim_cells.duplicate(),
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision,
	}


func _sealed_plan_with_stairs() -> PublicRealmSurfacePlan:
	## Ground streets are deliberately unplanked in production (dirt paths
	## carved between masses), so the plank-coexistence fixture uses a
	## structural court beside the stair claims.
	var plan := PublicRealmSurfacePlan.new(&"test.production.stairs")
	for x in 2:
		for z in 2:
			assert_true(plan.add_claim(Vector3i(x, 0, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"court.owner"), plan.last_rejection)
	var stair_cells: Array[Vector3i] = [Vector3i(2, 0, 0), Vector3i(2, 0, 1)]
	for cell: Vector3i in stair_cells:
		assert_true(plan.add_claim(cell,
			PublicRealmSurfacePlan.SurfaceKind.STAIR, &"stair.owner"),
			plan.last_rejection)
	assert_true(plan.add_transition_mesh_payload(_stair_transition_payload(
		&"test.transition.00", stair_cells)), plan.last_rejection)
	assert_true(plan.seal(), plan.last_rejection)
	return plan


func test_production_surface_bundle_carries_stair_transition_meshes() -> void:
	var plan := _sealed_plan_with_stairs()
	var bundle := SettlementFabricAssembler.production_surface_bundle(plan)
	assert_gt(bundle.instance_count, 0,
		"plank instances must survive alongside the mesh channel")
	assert_gt(bundle.surface_meshes.size(), 0,
		"stair transition meshes must enter the production payload")
	var covered: Dictionary = {}
	for mesh: Dictionary in bundle.surface_meshes:
		assert_false((mesh.collision_faces as PackedVector3Array).is_empty(),
			"a production surface mesh must be collision-bearing")
		for cell: Vector3i in mesh.claim_cells as Array:
			covered[cell] = true
	for cell: Vector3i in plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STAIR):
		assert_true(covered.has(cell),
			"STAIR claim %s has no production surface mesh" % cell)


func test_payload_surface_meshes_validate_and_respect_block_ownership() -> void:
	var payload := EnvironmentInstancePayload.new()
	var mesh := _stair_transition_payload(&"test.transition.own",
		[Vector3i(2, 0, 0)] as Array[Vector3i])
	mesh["anchor"] = Vector3(3.0, 0.0, 1.5)
	payload.add_surface_mesh(mesh)
	assert_true(payload.validate())
	var inside := EnvironmentInstancePayload.new()
	inside.append_from(payload, Rect2(0, 0, 192, 192))
	assert_eq(inside.surface_meshes.size(), 1,
		"a mesh anchored inside the ownership rect must be kept")
	var outside := EnvironmentInstancePayload.new()
	outside.append_from(payload, Rect2(192, 0, 192, 192))
	assert_eq(outside.surface_meshes.size(), 0,
		"a mesh anchored outside the ownership rect must be dropped")
	var broken := EnvironmentInstancePayload.new()
	var bad := mesh.duplicate(true)
	bad["collision_faces"] = PackedVector3Array()
	broken.add_surface_mesh(bad)
	assert_false(broken.validate(),
		"a surface mesh without collision faces is invalid")


func test_commit_queue_stages_surface_mesh_collision_and_visuals() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := FeatureCommitQueue.new(cache)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	var mesh := _stair_transition_payload(&"test.transition.commit",
		[Vector3i(2, 0, 0)] as Array[Vector3i])
	mesh["anchor"] = Vector3(3.0, 0.0, 1.5)
	payload.add_surface_mesh(mesh)
	queue.enqueue(Vector2i.ZERO, 2, parent, payload)
	assert_true(queue.drain(4, 0, 0, 100000).is_empty(),
		"a mesh-only block is not empty and must stage collision first")
	var events: Array[Dictionary] = []
	for _iteration in 64:
		events = queue.drain(0, 4, 0, 100000)
		if not events.is_empty():
			break
	assert_eq(events.size(), 1, "mesh collision must publish readiness")
	var block := events[0].node as Node3D
	assert_not_null(block)
	var body := block.get_node_or_null("FeatureCollision") as StaticBody3D
	assert_not_null(body)
	assert_eq(body.get_child_count(), 1)
	var shape := (body.get_child(0) as CollisionShape3D).shape \
		if body.get_child_count() > 0 else null
	assert_true(shape is ConcavePolygonShape3D,
		"surface mesh collision commits as a concave triangle shape")
	queue.drain(0, 0, 16, 100000)
	var visuals := block.get_node_or_null("Visuals")
	assert_not_null(visuals)
	var mesh_instances := visuals.find_children("*", "MeshInstance3D", true,
		false) if visuals != null else []
	assert_eq(mesh_instances.size(), 1,
		"the committed block must draw the generated surface mesh")


func _house_over(retained: Dictionary, band: int) -> Dictionary:
	## A timber house standing on the top of a column of hill: its own base
	## storey is not rock, so the last course of hill under it is the one place
	## the round-3 budget still allows stone.
	var solids: Dictionary = {}
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		if cell.y == band:
			solids[cell + Vector3i.UP] = &"house"
	return solids


func test_a_multi_band_terrace_is_never_stacked_with_stone() -> void:
	## Round 2 tiled a six-band bank with three courses of rock, which is how a
	## hill town became a monument. The budget now allows ONE module per face,
	## top flush with the house it carries; everything under it is earth. Faces
	## the town itself already closes still get nothing.
	var retained: Dictionary = {}
	for band in 6:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 5)
	for band in 6:
		# The neighbour to the east is another house's wall, so that face is
		# already closed and no rock may appear inside it.
		solids[Vector3i(1, band, 0)] = &"neighbour"
	var payload := SettlementFabricAssembler.house_plinth_walls(retained,
		solids)
	assert_true(payload.validate())
	var batch := payload.batches.get(
		SettlementFabricAssembler.LOW_RETAINING_WALL, {}) as Dictionary
	var transforms: Array = batch.get("transforms", [])
	assert_eq(transforms.size(), 3,
		"a six-band bank owes one plinth course to its three open faces, "
		+ "not one course per two bands")
	for value: Variant in transforms:
		var origin := (value as Transform3D).origin
		assert_almost_eq(origin.y + 3.0, 9.0, 0.001,
			"the plinth must hang from the house floor it carries")
		assert_lt(origin.x, 0.4,
			"a face closed by a neighbouring house must stay unretained")
	assert_eq(SettlementFabricAssembler.tallest_stone_stack_bands(payload),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"one plinth course is exactly one storey of stone")


func test_hill_the_town_did_not_build_on_carries_no_stone_at_all() -> void:
	## Terrace mass, tunnel walls, and cut faces with no house on top are the
	## bulk of the retained set. Round 2 rendered every one of them as coursed
	## rock. They are ground: the earth skin owns them and stone never appears.
	var retained: Dictionary = {}
	for band in 4:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	var payload := SettlementFabricAssembler.house_plinth_walls(retained, {})
	assert_eq(payload.instance_count, 0,
		"unbuilt hill mass rendered %d stone modules" % payload.instance_count)
	var skin := SettlementFabricAssembler.earth_skin_mesh(retained, {},
		SettlementFabricAssembler.plinth_faces(retained, {}))
	assert_not_null(skin, "the hill it replaces must still be skinned as earth")
	assert_true(_skin_has_normal(skin, Vector3.UP),
		"the terrace tread must be earth")
	assert_true(_skin_has_normal(skin, Vector3.LEFT) \
		and _skin_has_normal(skin, Vector3.BACK),
		"the cut faces of the hill must be earth, not masonry")


func test_hill_standing_over_a_street_is_closed_by_earth_underneath() -> void:
	## The excavation's cover gate guarantees a majority of route cells carry
	## mass overhead. Round 2 closed that underside with flat rock modules -- a
	## stone vault. It is the underside of a hill, so it is earth; without it a
	## covered street reads as a roofless trench however much mass is above.
	var retained: Dictionary = {}
	for band: int in [3, 4]:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	var payload := SettlementFabricAssembler.house_plinth_walls(retained, {})
	assert_eq(payload.instance_count, 0, "a vault must not be stone")
	var skin := SettlementFabricAssembler.earth_skin_mesh(retained, {},
		SettlementFabricAssembler.plinth_faces(retained, {}))
	var heights := _skin_face_heights(skin, Vector3.DOWN)
	assert_eq(heights, [4.5, 4.5, 4.5, 4.5] as Array[float],
		"only the lowest exposed underside is skinned, once per cell")
	# Extending the hill one band down moves the soffit down with it, and a
	# band resting on the world floor is never an overhang.
	var lowered := retained.duplicate()
	for x in 2:
		for z in 2:
			lowered[Vector3i(x, 2, z)] = true
	assert_eq(_skin_face_heights(SettlementFabricAssembler.earth_skin_mesh(
		lowered, {}, SettlementFabricAssembler.plinth_faces(lowered, {})),
		Vector3.DOWN), [3.0, 3.0, 3.0, 3.0] as Array[float],
		"only the lowest exposed underside is skinned")


func test_no_stone_face_in_an_assembled_payload_exceeds_one_storey() -> void:
	## The round-3 budget, pinned: "almost no stone should be visible, it should
	## only be used sparingly to make a house one storey taller". A plinth under
	## a house whose own ground storey is ALREADY rock would put a second storey
	## of masonry on one continuous face, so it is refused and that course reads
	## as earth instead.
	var retained: Dictionary = {}
	for band in 4:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 3)
	var assembled := SettlementFabricAssembler.house_plinth_walls(retained,
		solids)
	# The house's own ground storey, as room.base.rock places it: a 3 m rock
	# facade sitting directly on the plinth, offset half a cell along the wall.
	assembled.add(SettlementFabricProgram.ROCK_WINDOW,
		Transform3D(Basis.IDENTITY, Vector3(0.75, 6.0, -0.75)), Color.WHITE,
		&"test.house.front")
	assert_gt(SettlementFabricAssembler.tallest_stone_stack_bands(assembled),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"the control must show an unguarded plinth stacking under a rock "
		+ "ground storey, or this test proves nothing")
	var stone_clad: Dictionary = {}
	for cell_value: Variant in solids.keys():
		stone_clad[cell_value as Vector3i] = true
	var guarded := SettlementFabricAssembler.house_plinth_walls(retained,
		solids, stone_clad)
	assert_eq(guarded.instance_count, 0,
		"a house that already wears rock may not be given a rock plinth")
	guarded.add(SettlementFabricProgram.ROCK_WINDOW,
		Transform3D(Basis.IDENTITY, Vector3(0.75, 6.0, -0.75)), Color.WHITE,
		&"test.house.front")
	assert_lte(SettlementFabricAssembler.tallest_stone_stack_bands(guarded),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"no continuous stone face may exceed one storey")


func _skin_has_normal(mesh: ArrayMesh, normal: Vector3) -> bool:
	return not _skin_face_heights(mesh, normal).is_empty()


func _skin_face_heights(mesh: ArrayMesh, normal: Vector3) -> Array[float]:
	## One entry per quad whose normal matches, at its height. Read back
	## approximately: an ArrayMesh may store its normals compressed.
	var out: Array[float] = []
	if mesh == null:
		return out
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var index := 0
	while index < normals.size():
		if normals[index].dot(normal) > 0.99:
			out.append(snappedf(vertices[index].y, 0.001))
		index += 6
	out.sort()
	return out


func test_plinth_walls_are_deterministic_and_uniquely_identified() -> void:
	var retained: Dictionary = {}
	for band in 5:
		for x in 2:
			retained[Vector3i(x, band, 0)] = true
	var solids := _house_over(retained, 4)
	var first := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	var second := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	assert_gt(first.instance_count, 0, "the fixture must place some stone")
	assert_eq(first.instance_count, second.instance_count)
	var batch := first.batches.get(
		SettlementFabricAssembler.LOW_RETAINING_WALL, {}) as Dictionary
	var ids: Array = batch.get("ids", [])
	var unique: Dictionary = {}
	for index in ids.size():
		unique[StringName(ids[index])] = true
		assert_eq(StringName(ids[index]),
			StringName((second.batches[
				SettlementFabricAssembler.LOW_RETAINING_WALL] as Dictionary
				).ids[index]), "instance order must be a pure function")
	assert_eq(unique.size(), ids.size(), "stable ids must be unique")
