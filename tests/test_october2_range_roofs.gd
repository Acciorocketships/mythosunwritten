extends GutTest


func test_end_pavilion_tries_the_other_end_when_only_one_end_is_blocked() -> void:
	var rect := Rect2i(0, 0, 8, 2)
	var plain := BuildingDesigner.new(SuntailBuildingKit.create())
	var constrained := BuildingDesigner.new(SuntailBuildingKit.create())
	constrained.covered = func(cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and cell.x < 3 and band == 2
	var exercised := 0
	for seed_value in 24:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var mass := _mass(rect, seed_value)
		if plain._range_end_bay(mass, rect, 0, 2, rng).is_empty():
			continue
		rng.seed = seed_value
		var wings := constrained._range_end_bay(mass, rect, 0, 2, rng)
		assert_false(
			wings.is_empty(),
			"A legal opposite-end pavilion should survive the preferred end's rejection."
		)
		if wings.is_empty():
			continue
		exercised += 1
		assert_between(
			(wings[0].rect as Rect2i).position.x,
			3,
			5,
			"The pavilion stays entirely beyond the blocked end; central bays are legal too."
		)
	assert_gt(exercised, 12)


func _mass(rect: Rect2i, seed_value: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.seed = seed_value
	mass.stable_id = &"range.test"
	mass.add_storey(0, BuildingMass.rect_cells(rect), BuildingMass.MATERIAL_TIMBER)
	return mass


func test_long_halls_gain_connected_cross_gables_on_their_own_rooms() -> void:
	var kit := SuntailBuildingKit.create()
	var changed := 0
	var simple := 0
	for axis in 2:
		var rect := Rect2i(-4, -3, 8, 2) if axis == 0 else Rect2i(-4, -3, 2, 8)
		for seed_value in 24:
			var mass := _mass(rect, seed_value)
			BuildingDesigner.new(kit).articulate(mass, {})
			var occupied := {}
			var axes := {}
			var open_ends := 0
			for roof: Dictionary in mass.roofs:
				axes[roof.axis] = true
				open_ends += int(roof.open_min) + int(roof.open_max)
				for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
					assert_true(rect.has_point(cell), "no unsupported new roof footprint")
					assert_false(occupied.has(cell), "the two wings partition the original crown")
					occupied[cell] = true
			assert_eq(occupied.size(), rect.get_area(), "the full hall stays roofed")
			if axes.size() == 2:
				changed += 1
				assert_between(open_ends, 1, 2, "one or two halls open into the taller cross gable")
			else:
				simple += 1
	assert_gt(changed, 24)
	assert_eq(simple, 0, "very elongated unobstructed halls always gain a cross gable")


func test_transverse_bay_yields_to_reserved_headroom_without_mutation() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 3
	var rect := Rect2i(0, 0, 8, 2)
	var mass := _mass(rect, 1)
	var before := mass.storeys.duplicate(true)
	for seed_value in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_true(designer._range_end_bay(mass, rect, 0, 2, rng).is_empty())
	assert_eq(mass.storeys, before)
	assert_true(mass.roofs.is_empty())


func test_cross_gable_does_not_face_into_a_partial_taller_neighbor() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.covered = func(cell: Vector2i, band: int) -> bool: return cell.y == -1 and band == 2
	var rect := Rect2i(0, 0, 8, 2)
	for seed_value in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_true(
			designer._range_end_bay(_mass(rect, seed_value), rect, 0, 2, rng).is_empty(),
			"a taller adjacent wall would cut a hole in the new gable"
		)


func test_medium_and_broad_ranges_also_gain_full_size_cross_wings() -> void:
	var kit := SuntailBuildingKit.create()
	for size: Vector2i in [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 3), Vector2i(6, 4)]:
		var changed := 0
		for seed_value in 24:
			var rect := Rect2i(Vector2i.ZERO, size)
			var mass := _mass(rect, seed_value)
			BuildingDesigner.new(kit).articulate(mass, {})
			var cover := {}
			var axes := {}
			for roof: Dictionary in mass.roofs:
				assert_gte(
					mini(roof.rect.size.x, roof.rect.size.y),
					2,
					"Neither wing degenerates to a one-bay sliver."
				)
				axes[roof.axis] = true
				for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
					assert_true(rect.has_point(cell))
					assert_false(cover.has(cell))
					cover[cell] = true
			assert_eq(cover.size(), rect.get_area())
			if axes.size() == 2:
				changed += 1
		assert_gt(
			changed,
			12,
			"Real town ranges should participate, not just exceptionally long test halls."
		)


func test_central_pavilion_survives_when_both_ends_face_taller_neighbors() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.covered = func(cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and (cell.x < 3 or cell.x >= 7) and band == 2
	var rect := Rect2i(0, 0, 10, 2)
	for seed_value in range(12):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var wings := designer._range_end_bay(_mass(rect, seed_value), rect, 0, 2, rng)
		assert_eq(
			wings.size(), 3, "Use the clear middle without forcing a gable into either neighbor."
		)
		if wings.size() != 3:
			continue
		assert_between((wings[0].rect as Rect2i).position.x, 3, 4)
		for wing: Dictionary in wings:
			assert_gte(mini(wing.rect.size.x, wing.rect.size.y), 2)


func test_cross_gable_can_close_against_a_complete_taller_wall() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.covered = func(cell: Vector2i, _band: int) -> bool: return cell.y == -1
	var rect := Rect2i(0, 0, 8, 2)
	for seed_value in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_false(
			designer._range_end_bay(_mass(rect, seed_value), rect, 0, 2, rng).is_empty(),
			"A fully backed rear gable leaves a complete street-facing cross wing."
		)
	designer.covered = func(cell: Vector2i, _band: int) -> bool: return cell.y == -1 or cell.y == 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_true(
		designer._range_end_bay(_mass(rect, 1), rect, 0, 2, rng).is_empty(),
		"Do not add a cross wing with neither gable visible."
	)


func test_lower_cross_wing_fits_below_the_taller_pavilion_limit() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 4
	var rect := Rect2i(0, 0, 8, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var wings := designer._range_end_bay(_mass(rect, 1), rect, 0, 2, rng)
	assert_false(wings.is_empty())
	if wings.is_empty():
		return
	assert_eq((wings[0].rect as Rect2i).size, Vector2i(2, 2), "Use a complete lower native gable.")
	assert_eq(int(wings[0].axis), 1)


func test_dense_grand_ranges_use_lower_cross_wings_with_closed_finished_roofs() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		2, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var changed := 0
	for house: BuildingMass in built.houses:
		if (
			house.stable_id
			not in [&"kit.spatial.parcel.maze.house.003", &"kit.spatial.parcel.maze.house.019"]
		):
			continue
		var axes := {}
		for roof: Dictionary in house.roofs:
			axes[roof.axis] = true
		assert_eq(axes.size(), 2, "The photographed dense range gains a real transverse wing.")
		changed += 1
	assert_eq(changed, 2)
	var audit := preload("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit)
	for key in ["gable_holes", "open_exposed", "air_unsupported"]:
		assert_eq(int(audit[key]), 0, str(audit.examples))
	assert_eq(
		int(
			(
				preload("res://tests/fixtures/kit_roof_public_air_audit.gd")
				. audit(built, kit)
				. intrusions
			)
		),
		0
	)
	assert_true(built.payload.validate())


func test_cross_gable_keeps_its_native_ridge_trim_away_from_elevated_walk_rails() -> void:
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 4
	designer.walked = func(cell: Vector2i, band: int) -> bool:
		return cell.x < 2 and cell.y == -1 and band == 4
	var rect := Rect2i(0, 0, 8, 2)
	for seed_value in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var wings := designer._range_end_bay(_mass(rect, seed_value), rect, 0, 2, rng)
		assert_false(wings.is_empty(), "Keep the legal cross wing at the other end.")
		if wings.is_empty():
			continue
		assert_gte(
			(wings[0].rect as Rect2i).position.x, 3, "Ridge-height rails need their full rim."
		)


func test_two_to_one_ranges_always_seek_a_connected_cross_gable() -> void:
	var kit := SuntailBuildingKit.create()
	for size: Vector2i in [Vector2i(4, 2), Vector2i(2, 4), Vector2i(6, 3), Vector2i(3, 6)]:
		for seed_value in 24:
			var rect := Rect2i(Vector2i.ZERO, size)
			var mass := _mass(rect, seed_value)
			BuildingDesigner.new(kit).articulate(mass, {})
			var axes := {}
			var cover := {}
			for roof: Dictionary in mass.roofs:
				axes[roof.axis] = true
				for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
					assert_false(cover.has(cell))
					cover[cell] = true
			assert_eq(
				axes.size(),
				2,
				"Unobstructed elongated houses must not skip articulation on a random roll"
			)
			assert_eq(cover.size(), rect.get_area(), "Retain the complete inhabited footprint")


func test_large_ranges_keep_native_depth_and_break_up_every_long_tail() -> void:
	var kit := SuntailBuildingKit.create()
	for size: Vector2i in [Vector2i(12, 4), Vector2i(4, 12), Vector2i(14, 2)]:
		for seed_value in 8:
			var rect := Rect2i(Vector2i.ZERO, size)
			var mass := _mass(rect, seed_value)
			BuildingDesigner.new(kit).articulate(mass, {})
			var coverage := {}
			for roof: Dictionary in mass.roofs:
				var footprint: Rect2i = roof.rect
				var axis := int(roof.axis)
				assert_lte(
					footprint.size[1 - axis],
					BuildingDesigner.MAX_ROOF_DEPTH,
					"A pavilion must use the same depth limit as the main roof"
				)
				assert_lt(
					footprint.size[axis],
					maxi(
						4, maxi(footprint.size[1 - axis] + 2, ceili(footprint.size[1 - axis] * 1.5))
					),
					"An unobstructed elongated remainder also receives a joined pavilion"
				)
				for cell: Vector2i in BuildingMass.rect_cells(footprint):
					assert_false(coverage.has(cell), "Roof footprints partition the existing rooms")
					coverage[cell] = true
			assert_eq(coverage.size(), rect.get_area(), "No room loses its roof")


func test_adjacent_crown_strips_do_not_recombine_pavilions_into_eight_bay_runs() -> void:
	var kit := SuntailBuildingKit.create()
	for seed_value in 8:
		var mass := _mass(Rect2i(0, 0, 10, 8), seed_value)
		BuildingDesigner.new(kit).articulate(mass, {})
		for roof: Dictionary in mass.roofs:
			var rect: Rect2i = roof.rect
			# This compound has neighboring pavilions: a six-bay hall may
			# remain where another four-bay gable plus its two connectors
			# cannot fit. Eight-bay unions recreate the rejected silhouette.
			assert_lte(rect.size[int(roof.axis)], 6)
			assert_lte(rect.size[1 - int(roof.axis)], BuildingDesigner.MAX_ROOF_DEPTH)
