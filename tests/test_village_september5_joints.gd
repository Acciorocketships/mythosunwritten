extends GutTest

func test_outcrop_cover_bears_on_walls_instead_of_sharing_their_top_faces() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var faces: Dictionary = {}
	var treatments: Dictionary = {}
	for direction_index in 4:
		var normal: Vector3i = SettlementFabricAssembler.STONE_FACE_DIRECTIONS[direction_index]
		var tangent := Vector3i(-normal.z,0,normal.x)
		for member in 2:
			for band in [1,3]:
				var key := Vector4i(tangent.x*member,band,tangent.z*member,direction_index)
				faces[key] = true
				treatments[key] = SettlementFabricAssembler.SkinTreatment.FACADE
	var payload := SettlementFabricAssembler.maze_facade_outcroppings({}, {}, {}, {}, {},
		{"faces":faces,"treatments":treatments})
	var count := 0
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in batch.transforms.size():
			if not String(batch.ids[index]).ends_with("/cap"):
				continue
			var bounds: AABB = batch.transforms[index] * catalog.descriptor(asset).measured_aabb
			assert_almost_eq(bounds.position.y, 6.0, 0.0001,
				"the cap underside is the wall's top bearing plane")
			assert_gt(bounds.end.y, 6.1, "the visible cap top cannot coincide with wall faces")
			count += 1
	assert_gt(count, 0)
	var shell := {"faces":faces,"treatments":treatments}
	var choices := SettlementFabricAssembler.maze_facade_outcrop_kinds({}, {}, {}, {}, {}, shell)
	var key: Vector4i = choices.keys()[0]
	var front := Vector3i(key.x,key.y+1,key.z) \
		+ SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w]
	var blocked := SettlementFabricAssembler.maze_facade_outcrop_kinds({}, {}, {}, {}, {}, shell, {front:true})
	assert_false(blocked.has(key), "an occupied cap course rejects the whole optional projection")

func test_ground_mass_connectivity_requires_faces_not_edges() -> void:
	var envelope := WarrenVolumeEnvelope.new()
	for z in range(-2, 3):
		for x in range(-2, 3):
			envelope.ground_bands[Vector2i(x,z)] = 0
			envelope.height_bands[Vector2i(x,z)] = 8
	var source := WarrenSpatialPlan.new(&"bearing.fixture", 1, null)
	source.source_volume = WarrenVolumePlan.new(&"bearing.volume", 1, envelope)
	var union := {Vector3i.ZERO:true, Vector3i(0,1,0):true,
		Vector3i(1,1,0):true, Vector3i(2,2,0):true}
	var connected := WarrenSpatialFabricCompiler._ground_connected_mass(source, union)
	assert_true(connected.has(Vector3i(1,1,0)), "a cardinal face transfers bearing")
	assert_false(connected.has(Vector3i(2,2,0)), "a lower edge is not bearing")
	union.erase(Vector3i(0,1,0))
	connected = WarrenSpatialFabricCompiler._ground_connected_mass(source, union)
	assert_false(connected.has(Vector3i(1,1,0)), "removed source stone cannot bear a room")

func test_ground_frame_courses_meet_without_surface_gaps() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var one := program.recipe(&"foundation.timber.post.1")
	var two := program.recipe(&"foundation.timber.post.2")
	assert_almost_eq(one.local_bounds.size.y, 1.5, 0.0001)
	assert_almost_eq(two.local_bounds.size.y, 3.0, 0.0001)
	assert_almost_eq(two.local_bounds.end.y, 3.0 + one.local_bounds.position.y, 0.0001,
		"consecutive courses share the same endpoint plane")

func test_perpendicular_stone_facades_select_baked_corner_ends() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var room := program.recipe(&"room.tower.base.rock")
	assert_true(program.referenced_asset_ids.has(SettlementFabricAssembler.MAZE_STONE_MODULE),
		"retained masonry is an explicit dependency, independent of the room facade pool")
	var miter_count := 0
	for panel: Dictionary in room.placements:
		if String(panel.asset_id).contains(".miter"):
			miter_count += 1
		if String(panel.asset_id).begins_with("sfv.fabric.wall.rock.door."):
			assert_eq(room.realized_facade_asset(panel, []),
				SettlementFabricProgram.ROCK_DOOR_CLOSED,
				"the whole deep doorway owns its ends; adjacent panels stop at its back plane")
	assert_gte(miter_count, 2, "both perpendicular stone panels need finite corner ends")
	for asset: StringName in SettlementFabricProgram.ROCK_FACADE:
		assert_gte(catalog.descriptor(asset).measured_aabb.size.x, 3.0,
			"a three-metre facade slot cannot be filled with a half-bay panel")

func test_straight_facade_repeat_keeps_square_ends() -> void:
	var modules := SettlementFabricProgram.compile(EnvironmentCatalog.load_default()).module_program
	var recipe := FabricRecipe.new(&"test.straight", [&"room", &"generated_building"], 0)
	var asset := &"sfv.fabric.wall.rock.window.010"
	for index in 2:
		recipe.add_placement(StringName(str(index)), asset,
			modules.facade_aligned_transform(asset,
				Transform3D(Basis.IDENTITY, Vector3(index * 3.0, 0, 0)), Vector3i.BACK, 0))
	modules.finish_facade_corners(recipe)
	for panel: Dictionary in recipe.placements:
		assert_eq(panel.asset_id, asset)

func test_facade_alignment_always_presents_finished_side_outward() -> void:
	var modules := FabricModuleProgram.new(EnvironmentCatalog.load_default())
	var asset := SettlementFabricProgram.WOOD_DOOR
	assert_true(modules.add_generic(asset))
	assert_true(modules.seal())
	for outward: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		for yaw in [0.0, PI]:
			var pose := Transform3D(Basis(Vector3.UP,
				atan2(float(outward.x), float(outward.z)) + yaw), Vector3.ZERO)
			var aligned := modules.facade_aligned_transform(asset, pose, outward, 2.25)
			assert_gt(aligned.basis.z.dot(Vector3(outward)), 0.99,
				"the boundary normal owns exterior facing even for a reversed input")
			var bounds := aligned * modules.contract(asset).visual_bounds
			var boundary := bounds.end.x if outward.x > 0 else bounds.position.x \
				if outward.x < 0 else bounds.end.z if outward.z > 0 else bounds.position.z
			assert_almost_eq(boundary, 2.25, 0.001)

func test_diagonal_stone_contact_has_one_closed_joint_per_band() -> void:
	var retained := {Vector3i(0,0,0): true, Vector3i(1,0,1): true,
		Vector3i(0,1,0): true, Vector3i(1,1,1): true}
	var payload := SettlementFabricAssembler.masonry_corner_joints(retained, {})
	assert_eq(payload.instance_count, 2)
	var positions: Array = payload.batches[SettlementFabricAssembler.TIMBER_SUPPORT].transforms
	for pose: Transform3D in positions:
		assert_eq(pose.origin.x, 0.75)
		assert_eq(pose.origin.z, 0.75)
	retained[Vector3i(1,0,0)] = true
	assert_eq(SettlementFabricAssembler.masonry_corner_joints(retained, {}).instance_count, 2,
		"a recessed inside corner also requires one common joint")
	retained[Vector3i(0,0,1)] = true
	assert_eq(SettlementFabricAssembler.masonry_corner_joints(retained, {}).instance_count, 1,
		"a full four-cell vertex is buried and needs no joint")

func test_diagonal_room_contact_without_masonry_does_not_get_rock_joint() -> void:
	assert_eq(SettlementFabricAssembler.masonry_corner_joints({},
		{Vector3i.ZERO: true, Vector3i(1,0,1): true}).instance_count, 0)
