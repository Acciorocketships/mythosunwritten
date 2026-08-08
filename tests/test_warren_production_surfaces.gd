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


func test_a_bank_under_a_house_is_a_plinth_over_a_mountain() -> void:
	## Round-3b doctrine. The last course under the house is the authored
	## FOUNDATION piece -- that is the liked wood-over-stone junction -- and the
	## bank below it is the mountain the house stands on, tiled by whole rock
	## modules because a building covers it. Faces the town itself already closes
	## still get nothing.
	var retained: Dictionary = {}
	for band in 6:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 5)
	for band in 6:
		# The neighbour to the east is another house's wall, so that face is
		# already closed and no rock may appear inside it.
		solids[Vector3i(1, band, 0)] = &"neighbour"
	var plinths := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	assert_true(plinths.validate())
	var foundations: Array = (plinths.batches.get(
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
	var substrate := SettlementFabricAssembler.hill_substrate_walls(retained,
		solids)
	var walls: Array = (substrate.batches.get(
		SettlementFabricAssembler.LOW_RETAINING_WALL, {}) as Dictionary).get(
		"transforms", [])
	assert_eq(walls.size(), 6,
		"the four bands under the plinth are mountain a house covers, two "
		+ "modules on each of the three open faces")
	for value: Variant in walls:
		assert_lt((value as Transform3D).origin.y + 3.0, 6.001,
			"substrate may not rise into the course the plinth owns")


func test_the_hill_is_drawn_so_a_house_never_stands_over_undrawn_mass() -> void:
	## SUPERSEDES "hill no building stands over carries no stone at all"
	## (commit 439a497). That rule hid a face behind mass that was DECLARED and
	## never DRAWN, so on a terrace the last drawn thing under a house was the
	## house, and the round-5 review saw buildings floating.
	##
	## The declaration covers the whole solid, so the fix is to draw all of it
	## and let the neighbour test do the hiding: a face survives only where the
	## mass beside it is genuinely absent, which is a terrace step or the rim.
	## What is still forbidden is the generated slab -- the "box" the round-4
	## review threw out -- and a plinth on mass no building stands on.
	var retained: Dictionary = {}
	for band in 4:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	assert_eq(SettlementFabricAssembler.house_plinth_walls(retained,
		{}).instance_count, 0, "unbuilt hill mass may not be plinthed")
	var bare := SettlementFabricAssembler.hill_substrate_walls(retained, {})
	assert_gt(bare.instance_count, 0,
		"declared mass that draws nothing is what makes a house float")
	# Interior faces stay closed: only the block's own eight outward faces may
	# carry stone, never the four between its own columns.
	for asset_id: StringName in bare.batches.keys():
		for value: Variant in (bare.batches[asset_id] as Dictionary).get(
				"transforms", []):
			var origin := (value as Transform3D).origin
			assert_false(origin.x > 0.1 and origin.x < 1.4 \
				and origin.z > 0.1 and origin.z < 1.4,
				"a face between two retained columns must stay closed")
	var methods: Array[String] = []
	for entry: Dictionary in (load(
			"res://scripts/terrain/features/villages/fabric/"
			+ "SettlementFabricAssembler.gd") as GDScript
			).get_script_method_list():
		methods.append(String(entry.name))
	assert_false(methods.has("terrace_ground_mesh") \
		or methods.has("earth_skin_mesh"),
		"the generated earth skin is a box and must not come back")


func test_hill_standing_over_a_street_is_not_a_stone_vault() -> void:
	## The excavation's cover gate guarantees a majority of route cells carry
	## mass overhead. Round 2 closed that underside with flat rock modules laid
	## as a vault. The timber soffits and plank floors over a street stay, but
	## the hill's own underside is not masonry and is not a slab.
	var retained: Dictionary = {}
	for band: int in [1, 2, 3, 4]:
		for x in 2:
			for z in 2:
				retained[Vector3i(x, band, z)] = true
	assert_eq(SettlementFabricAssembler.house_plinth_walls(retained,
		{}).instance_count, 0, "a vault must not be plinthed")
	# The hill's own sides are drawn (see the grounding test above), but its
	# UNDERSIDE over a street never gains a horizontal module: a flat-laid wall
	# is exactly the vault round 2 built.
	var solids := _house_over(retained, 4)
	var covered := SettlementFabricAssembler.hill_substrate_walls(retained,
		solids)
	covered.append_from(SettlementFabricAssembler.hill_substrate_walls(retained,
		{}))
	assert_gt(covered.instance_count, 0,
		"mass a building stands over is the mountain and must render")
	for asset_id: StringName in covered.batches.keys():
		for value: Variant in (covered.batches[asset_id] as Dictionary).get(
				"transforms", []):
			assert_gt((value as Transform3D).basis.y.y, 0.5,
				"every substrate module must stand upright, never lie flat")


func test_bare_stone_never_exceeds_one_storey_in_an_assembled_payload() -> void:
	## The round-3b budget, pinned: stone a building covers is the mountain and
	## is exempt, but stone left in the open may not exceed one storey. A plinth
	## under a house whose own ground storey is ALREADY rock would also put a
	## second storey of masonry on one continuous face, so it is refused.
	var retained: Dictionary = {}
	for band in 4:
		retained[Vector3i(0, band, 0)] = true
	var solids := _house_over(retained, 3)
	var assembled := SettlementFabricAssembler.house_plinth_walls(retained,
		solids)
	assembled.append_from(SettlementFabricAssembler.hill_substrate_walls(
		retained, solids))
	assert_gt(SettlementFabricAssembler.tallest_bare_stone_stack_bands(
		assembled), SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"the control must show the whole column measured as bare, or the "
		+ "covered-column exemption below proves nothing")
	var covered := SettlementFabricAssembler.building_ceiling(solids)
	assert_eq(SettlementFabricAssembler.tallest_bare_stone_stack_bands(
		assembled, covered), 0,
		"a column a house stands on is substrate, not bare masonry")
	# The one-band court wall is the only stone this assembler leaves in the
	# open, and it is a single module.
	var court := SettlementFabricAssembler.house_plinth_walls(retained, solids)
	assert_lte(SettlementFabricAssembler.tallest_bare_stone_stack_bands(court),
		SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"bare stone may never exceed one storey")
	# A rock ground storey already spends the budget, so no foundation joins it.
	var stone_clad: Dictionary = {}
	for cell_value: Variant in solids.keys():
		stone_clad[cell_value as Vector3i] = true
	assert_eq(SettlementFabricAssembler.house_plinth_walls(retained, solids,
		stone_clad).instance_count, 0,
		"a house that already wears rock may not be given a rock plinth")


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
