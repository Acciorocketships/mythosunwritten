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
	# TASK I4 ROUND 7: the courtyard-planter gate's module index is a REQUIRED
	# argument now, so a caller that has none says so. This fixture builds a bare
	# surface plan with no fabric behind it.
	var bundle := SettlementFabricAssembler.production_surface_bundle(plan, {})
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


func test_a_bank_under_a_house_is_one_plinth_course_and_no_more() -> void:
	## Round-3b doctrine, RE-MEASURED for the buildable layer. The last course
	## under the house is the authored FOUNDATION piece -- the liked
	## wood-over-stone junction -- and the bank below it is now the MOUNTAIN,
	## which SettlementReliefPlan stamped into the heightfield and the terrain
	## mesher renders, dresses and collides. The fabric draws none of it.
	## Faces the town itself already closes still get nothing.
	var retained: Dictionary = {}
	for band in 6:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 5)
	for band in 6:
		# The neighbour to the east is another house's wall, so that face is
		# already closed and no rock may appear inside it.
		solids[Vector3i(1, band, 0)] = &"neighbour"
	var payload := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	assert_true(payload.validate())
	var foundations: Array = (payload.batches.get(
		SettlementFabricAssembler.HOUSE_PLINTH, {}) as Dictionary).get(
		"transforms", [])
	assert_eq(foundations.size(), 3,
		"the three open faces owe one foundation course each")
	for value: Variant in foundations:
		var origin := (value as Transform3D).origin
		assert_almost_eq(origin.y + 3.0, 9.0, 0.001,
			"the plinth must hang from the house floor it carries")
		assert_lt(origin.x, 0.4,
			"a face closed by a neighbouring house must stay unretained")
	assert_eq(payload.instance_count, foundations.size(),
		"a six-band bank owes exactly its plinth course and nothing else: "
		+ "the four bands beneath it are terrain")
	assert_lte(SettlementFabricAssembler.tallest_bare_stone_stack_bands(payload),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"one course is one storey of stone, whatever the bank's depth")


func test_hollow_room_bearing_footprint_closes_all_four_plinth_sides() -> void:
	## Generated rooms are hollow shells: most footprint cells are headroom, not
	## SOLID. Foundation eligibility must therefore use the recipe's explicit
	## terrain-bearing rectangle instead of producing a few disconnected faces
	## only beneath structural piers.
	var retained: Dictionary = {}
	var bearing: Dictionary = {}
	for z in 2:
		for x in 2:
			retained[Vector3i(x, 0, z)] = true
			bearing[Vector3i(x, 1, z)] = &"hollow-room"
	var faces := SettlementFabricAssembler.plinth_faces(retained, {}, bearing)
	assert_eq(faces.size(), 8,
		"a 2x2 base has two modules on each of its four exterior sides")
	var directions: Dictionary = {}
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		directions[key.w] = int(directions.get(key.w, 0)) + 1
	assert_eq(directions.size(), 4)
	for index in 4:
		assert_eq(int(directions.get(index, 0)), 2,
			"foundation side %d must be continuous" % index)


func test_the_hill_substrate_renderer_is_gone_and_may_not_return() -> void:
	## Tripwire for the terrain-bearing invariant.
	## `hill_substrate_walls` tiled the riser under a house with whole rock
	## modules because the fabric owned the hill and an undrawn hill left its
	## houses floating. The hill is terrain now: re-drawing it would put a
	## masonry collider inside the terrain's own volume and rebuild the monument
	## rounds 2 and 3 rejected. So would the earth skin the same review threw
	## out as a box.
	var methods: Array[String] = []
	for entry: Dictionary in (load(
			"res://scripts/terrain/features/villages/fabric/"
			+ "SettlementFabricAssembler.gd") as GDScript
			).get_script_method_list():
		methods.append(String(entry.name))
	for banned: String in ["hill_substrate_walls", "terrace_ground_mesh",
			"earth_skin_mesh"]:
		assert_false(methods.has(banned),
			"%s draws the mountain the terrain already renders" % banned)


func test_hill_no_building_stands_over_carries_no_stone_at_all() -> void:
	## Terrace mass, bare risers and uncovered ring faces are what the retained
	## set used to be full of, and rendering them as coursed rock is the uniform
	## masonry field the reviewer rejected twice. Nothing at all is drawn there.
	var retained: Dictionary = {}
	for band in 4:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	assert_eq(SettlementFabricAssembler.house_plinth_walls(retained,
		{}).instance_count, 0, "unbuilt hill mass may not be plinthed")


func test_hill_standing_over_a_street_is_not_a_stone_vault() -> void:
	## The excavation's cover gate guarantees a majority of route cells carry
	## mass overhead. Round 2 closed that underside with flat rock modules laid
	## as a vault. The timber soffits and plank floors over a street stay; the
	## hill's own underside is neither masonry nor a slab; terrain owns it.
	var retained: Dictionary = {}
	for band: int in [1, 2, 3, 4]:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	assert_eq(SettlementFabricAssembler.house_plinth_walls(retained,
		{}).instance_count, 0, "a vault must not be stone")
	# With a house on top the same mass owes exactly one upright plinth course
	# per open face -- never a horizontal module, because a flat-laid wall IS
	# the vault, and never a second course, because that is the mountain.
	var solids := _house_over(retained, 4)
	var covered := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	assert_gt(covered.instance_count, 0,
		"the course a house rests on is the plinth and must render")
	for asset_id: StringName in covered.batches.keys():
		for value: Variant in (covered.batches[asset_id] as Dictionary).get(
				"transforms", []):
			assert_gt((value as Transform3D).basis.y.y, 0.5,
				"every plinth module must stand upright, never lie flat")
	assert_lte(SettlementFabricAssembler.tallest_bare_stone_stack_bands(covered),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"a four-band bank under a house is still one course of stone")


func test_bare_stone_never_exceeds_one_storey_in_an_assembled_payload() -> void:
	## The round-3b budget, pinned. The only stone this assembler places under a
	## house is the single plinth course, so
	## the budget now holds by construction rather than by a covered-column
	## exemption -- and the test says so both ways: the payload is inside the
	## budget with no exemption at all, and it is fully exempt once read against
	## the house standing over it.
	##
	## task-24-report.md concern #2: a round-5 veto refused this same plinth
	## whenever the house's own ground storey already read as rock. Mass-first
	## now usually begins in timber, but the plinth contract remains independent
	## of facade style. house_plinth_walls no longer takes a stone-clad hint:
	## the plinth is FRONTED stone (a building stands directly on it by the
	## eligibility check alone) and is bounded on its own terms by the
	## declaration side's PLINTH_BUDGET_BANDS, so what the house above is made
	## of cannot refuse it. See test_warren_solid_partitioner.gd's
	## test_a_grounded_corpus_seed_draws_its_declared_plinths for the
	## corpus-wide regression.
	var retained: Dictionary = {}
	for band in 4:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 3)
	var assembled := SettlementFabricAssembler.house_plinth_walls(retained,
		solids)
	assert_gt(assembled.instance_count, 0, "the fixture must place some stone")
	assert_lte(SettlementFabricAssembler.tallest_bare_stone_stack_bands(
		assembled), SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"bare stone may never exceed one storey, with no exemption claimed")
	var covered := SettlementFabricAssembler.building_ceiling(solids)
	assert_eq(SettlementFabricAssembler.tallest_bare_stone_stack_bands(
		assembled, covered), 0,
		"a column a house stands on is read against that house")


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
		SettlementFabricAssembler.HOUSE_PLINTH, {}) as Dictionary
	var ids: Array = batch.get("ids", [])
	var unique: Dictionary = {}
	for index in ids.size():
		unique[StringName(ids[index])] = true
		assert_eq(StringName(ids[index]),
			StringName((second.batches[
				SettlementFabricAssembler.HOUSE_PLINTH] as Dictionary
				).ids[index]), "instance order must be a pure function")
	assert_eq(unique.size(), ids.size(), "stable ids must be unique")


func test_rock_cladding_stops_at_the_ground_storey() -> void:
	## Round-5 review note 4, second half: the style system could clad a whole
	## house in rock -- ten contiguous bands of house-stone on a measured seed.
	## Every stack already builds its ground storey from a `*.base.rock` recipe,
	## so a rock UPPER storey puts a second, third and fourth masonry course on
	## the same continuous face and the house reads as a tower.
	##
	## Pinned at the two places it can leak: the family table itself, and the
	## recipe ids StaggeredFabricCompiler expands a proposal into for every
	## family the table can return.
	assert_false(WarrenAssetCompiler.UPPER_FACADE_FAMILIES.has(&"stone"),
		"an upper storey may not draw from the rock family")
	assert_gte(WarrenAssetCompiler.UPPER_FACADE_FAMILIES.size(), 2,
		"one upper family is a repeated house row, not a streetscape")
	var ground_rock := 0
	var upper_rock := 0
	for family: StringName in WarrenAssetCompiler.UPPER_FACADE_FAMILIES:
		for kind: StringName in [&"building", &"long", &"slim", &"tower"]:
			for storeys in range(1, 4):
				var proposal := {
					"stable_id": StringName("probe.%s.%s.%d" % [family, kind,
						storeys]),
					"kind": kind,
					"origin": Vector3i(0, 0, 0),
					"yaw_quarters": 0,
					"storeys": storeys,
					"route_y": 0,
					"roof_feature": 0,
					"theme": family,
					"roof_theme": &"blue",
					"facade_phase": 0,
				}
				for component: Dictionary in \
						StaggeredFabricCompiler.proposal_components(proposal):
					var recipe_id := String(component.recipe_id)
					if not recipe_id.begins_with("room."):
						continue
					var rock := recipe_id.contains("rock") \
						or recipe_id.contains("stone")
					if recipe_id.contains(".upper"):
						upper_rock += int(rock)
						assert_false(rock,
							"%s clads an upper storey in rock" % recipe_id)
					else:
						ground_rock += int(rock)
	assert_eq(upper_rock, 0, "%d upper storeys still compile as rock"
		% upper_rock)
	assert_gt(ground_rock, 0,
		"capping the family table must not also delete the reviewed "
		+ "wood-over-stone ground storey")


func test_the_facade_family_selector_can_never_return_rock() -> void:
	## The table is only half the guarantee: _select_facade_family sorts by
	## adjacency cost, so a table entry that leaked in through a count would
	## still reach a recipe. Swept over every neighbour/global count shape the
	## graph colouring can present, including ones that make rock the cheapest
	## family if it were still a candidate.
	for world_seed in [0, 1, 7, 11, 2697992464]:
		for blue in 3:
			for orange in 3:
				var proposal := {
					"stable_id": &"probe",
					"kind": &"building",
					"origin": Vector3i(blue, orange, world_seed % 7),
					"storeys": 2,
				}
				var chosen := WarrenAssetCompiler._select_facade_family(proposal,
					{&"blue": blue, &"orange": orange, &"stone": 0},
					{&"blue": blue * 2, &"orange": orange * 2, &"stone": 0},
					world_seed)
				assert_true(WarrenAssetCompiler.UPPER_FACADE_FAMILIES.has(chosen),
					"selector returned %s, outside the capped table" % chosen)
