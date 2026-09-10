extends GutTest

const Assembler = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")

func _shell(direction_index: int, length: int) -> Dictionary:
	var normal: Vector3i = Assembler.STONE_FACE_DIRECTIONS[direction_index]
	var tangent := Vector3i(-normal.z, 0, normal.x)
	var faces: Dictionary = {}
	var treatments: Dictionary = {}
	for member in length:
		for band in [1, 3]:
			var key := Vector4i(tangent.x * member, band,
				tangent.z * member, direction_index)
			faces[key] = true
			treatments[key] = Assembler.SkinTreatment.FACADE
	return {"faces": faces, "treatments": treatments}

func test_continuous_garden_wall_has_one_projection_depth() -> void:
	for direction_index in 4:
		var shell := _shell(direction_index, 6)
		var kinds := Assembler.maze_facade_outcrop_kinds({}, {}, {}, {}, {}, shell)
		assert_eq(kinds.size(), 3, "all three reserved pairs remain present")
		var profile := int(kinds.values()[0])
		for kind: int in kinds.values():
			assert_eq(kind, profile, "a continuous garden wall has a straight outer edge")

func test_cover_depth_matches_its_wall_projection() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var shallow_count := 0
	for direction_index in 4:
		var shell := _shell(direction_index, 2)
		var kinds := Assembler.maze_facade_outcrop_kinds({}, {}, {}, {}, {}, shell)
		var payload := Assembler.maze_facade_outcroppings({}, {}, {}, {}, {}, shell)
		for key: Vector4i in kinds:
			var normal := Vector3(Assembler.STONE_FACE_DIRECTIONS[key.w])
			var reach := FabricRecipe.CELL_SIZE if int(kinds[key]) == Assembler.FacadeOutcrop.BAY \
				else Assembler.FACADE_BUMP_REACH
			if reach < FabricRecipe.CELL_SIZE:
				shallow_count += 1
			var boundary := Vector3(key.x, 0, key.z) * FabricRecipe.CELL_SIZE \
				+ normal * FabricRecipe.CELL_SIZE * 0.5
			var batch: Dictionary = payload.batches[Assembler.PLANK_GALLERY]
			for index in batch.transforms.size():
				var pose: Transform3D = batch.transforms[index]
				var is_base := String(batch.ids[index]).ends_with("/base")
				var bounds: AABB = pose * catalog.descriptor(Assembler.PLANK_GALLERY).measured_aabb
				var distances: Array[float] = []
				for corner in 8:
					distances.append((bounds.get_endpoint(corner) - boundary).dot(normal))
				assert_almost_eq(distances.min(), -Assembler.FACADE_FRONT_DEPTH if is_base else 0.0, 0.002,
					"base sockets into the parent wall; top cover starts at its face")
				if is_base:
					assert_almost_eq(bounds.end.y,(key.y-1)*1.5,0.001,"bearing top meets the wall foot")
				assert_almost_eq(distances.max(), reach, 0.002, "cover ends at its own projection")
	assert_gt(shallow_count, 0, "the shallow authored profile is covered independently")
