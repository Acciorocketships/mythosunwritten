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


func test_a_multi_band_terrace_is_retained_by_stacked_authored_modules() -> void:
	## The one-band court already renders as a half-buried 3 m rock module. A
	## house standing on a six-band hill needs the same module STACKED, never
	## stretched: three of them, top flush with the terrace, each covering two
	## bands. Faces the town itself already closes get nothing.
	var retained: Dictionary = {}
	for band in 6:
		retained[Vector3i(0, band, 0)] = true
	var solids: Dictionary = {}
	for band in 6:
		# The neighbour to the east is another house's wall, so that face is
		# already closed and no rock may appear inside it.
		solids[Vector3i(1, band, 0)] = true
	var payload := SettlementFabricAssembler.retaining_walls(retained, solids)
	assert_true(payload.validate())
	var batch := payload.batches.get(
		SettlementFabricAssembler.LOW_RETAINING_WALL, {}) as Dictionary
	var transforms: Array = batch.get("transforms", [])
	assert_eq(transforms.size(), 9,
		"three exposed faces of a six-band terrace need three modules each")
	var tops: Dictionary = {}
	var eastward := 0
	for value: Variant in transforms:
		var origin := (value as Transform3D).origin
		tops[snappedf(origin.y + 3.0, 0.001)] = true
		eastward += int(origin.x > 0.4)
	assert_eq(eastward, 0,
		"a face closed by a neighbouring house must stay unretained")
	var expected: Array[float] = [9.0, 6.0, 3.0]
	for top: float in expected:
		assert_true(tops.has(top),
			"no module tops out at %.1f m; the hill has a gap" % top)
	assert_eq(tops.size(), expected.size(),
		"modules must tile the terrace rather than overlap it")


func test_a_terrace_face_the_hill_itself_closes_gets_no_wall() -> void:
	## Two neighbouring houses on the same hill share a face that is solid rock
	## on both sides. Retaining it would build a wall inside the hill.
	var retained: Dictionary = {}
	for band in 4:
		retained[Vector3i(0, band, 0)] = true
		retained[Vector3i(1, band, 0)] = true
	var payload := SettlementFabricAssembler.retaining_walls(retained, {})
	var batch := payload.batches.get(
		SettlementFabricAssembler.LOW_RETAINING_WALL, {}) as Dictionary
	var transforms: Array = batch.get("transforms", [])
	assert_eq(transforms.size(), 12,
		"six exposed faces of a four-band pair need two modules each")
	for value: Variant in transforms:
		var origin := (value as Transform3D).origin
		assert_false(is_equal_approx(origin.x, 0.75) \
			and is_equal_approx(origin.z, 0.0),
			"a wall was built on the face the two terraces share")


func test_retaining_walls_are_deterministic_and_uniquely_identified() -> void:
	var retained: Dictionary = {}
	for band in 5:
		for x in 2:
			retained[Vector3i(x, band, 0)] = true
	var first := SettlementFabricAssembler.retaining_walls(retained, {})
	var second := SettlementFabricAssembler.retaining_walls(retained, {})
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
