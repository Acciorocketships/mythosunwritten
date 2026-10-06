extends GutTest
const FIELD := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")

func test_courts_preserve_the_high_massif_and_outer_ring_distance() -> void:
	var checked := 0
	for seed_value in [7, 10, 38, 1260018864828801968]:
		var profile := WarrenVillageScaleProfile.for_id(&"standard")
		var field := FIELD.sample(seed_value, profile)
		if not (field.platform as Dictionary).is_empty(): continue
		var before := WarrenMassifBuilder._terraced_massif(seed_value, field.height_domain, {})
		var after := WarrenMassifBuilder.build(seed_value, {}, profile)
		var peak := 0
		for cell: Vector2i in before.columns:
			peak = maxi(peak, before.layer_at(cell))
		for cell: Vector2i in after.columns:
			if after.is_reserved_ground(cell): continue
			if before.layer_at(cell) >= peak * 0.8:
				assert_eq(after.top_at(cell), before.top_at(cell), "a green must preserve the high massif")
			assert_eq(after.ring_depth(cell), before.ring_depth(cell))
			checked += 1
	assert_gt(checked, 100)

func test_complete_plots_and_volume_preserve_reserved_ground() -> void:
	var checked := 0
	for seed_value in [7, 10, 38, 1260018864828801968]:
		var source := WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.for_id(&"standard"), &"", false)
		assert_not_null(source)
		if source == null: continue
		assert_true(source.massif.validate_construction(), source.massif.last_rejection)
		var volume := WarrenMazeVolumeAdapter.to_volume_plan(source, false)
		assert_not_null(volume)
		if volume == null: continue
		var derived: WarrenMassif = volume.mass_context[&"massif"]
		assert_eq(derived.open_spaces, source.massif.open_spaces)
		for space: Dictionary in source.massif.open_spaces:
			for cell: Vector2i in space.cells:
				assert_true(derived.is_reserved_ground(cell))
				var base := source.massif.base_at(cell)
				assert_eq(WarrenPassageLatticeRules.slot_is_borable(source.massif,
					WarrenExcavation.new(seed_value), Vector3i(cell.x, base, cell.y), 2),
					not bool(source.massif.columns[cell].get("planting_core",false)))
				assert_false(WarrenPassageLatticeRules.slot_is_borable(source.massif,
					WarrenExcavation.new(seed_value), Vector3i(cell.x, base + 1, cell.y), 2))
				for band in range(base, derived.top_at(cell)):
					assert_false(source.solid_at(Vector3i(cell.x, band, cell.y)))
					assert_false(volume.has_mass(Vector3i(cell.x, band, cell.y)), "route envelope must compile to air")
				for plot: Dictionary in source.plots:
					assert_false(plot.cells.has(cell), "reserved ground must survive plot partition")
				checked += 1
	assert_gt(checked, 10)

func test_reserved_gaps_are_explicit_and_never_regrow_as_solid() -> void:
	var total := 0
	for seed_value in [7, 10, 38, 1260018864828801968]:
		var field := FIELD.sample(seed_value, WarrenVillageScaleProfile.for_id(&"standard"))
		assert_true(field.has("open_spaces"), "open spaces must survive as typed-purpose reservations")
		for space: Dictionary in field.get("open_spaces", []):
			assert_gte(space.cells.size(), 4, "a green needs room beyond one street cell")
			assert_true(space.purpose in [&"green", &"grove", &"courtyard", &"market", &"workyard"])
			for cell: Vector2i in space.cells:
				assert_false(field.solid.has(cell), "a reserved gap cannot regrow from crown/shoulder restoration")
			total += 1
	assert_gt(total, 2, "the corpus must contain useful reserved open spaces")

func test_clearings_include_useful_interior_ground_across_the_corpus() -> void:
	# Before the interior preference this corpus had 16 interior greens.
	# Count four actual reserved cells inside the old boundary, not a circle
	# centre that happens to lie inside while its usable area is outside.
	var interior := 0
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	for seed_value in 40:
		var field := FIELD.sample(seed_value,profile)
		var before := WarrenMassifBuilder._terraced_massif(seed_value,field.height_domain,{})
		for space: Dictionary in field.open_spaces:
			if not String(space.id).begins_with("open."): continue
			var cells := 0
			for cell: Vector2i in space.cells:
				if before.ring_depth(cell) >= 2: cells += 1
			interior += int(cells >= 4)
	assert_gte(interior,24,"preserve interior greens as well as cottage-edge gardens")

func test_large_towns_offer_more_substantial_interior_clearings() -> void:
	var interior_towns := 0
	var broad_clearings := 0
	for seed_value in range(1,41):
		var field := FIELD.sample(seed_value,WarrenVillageScaleProfile.for_id(&"large"))
		var before := WarrenMassifBuilder._terraced_massif(seed_value,field.height_domain,{})
		var has_interior := false
		for space: Dictionary in field.open_spaces:
			if not String(space.id).begins_with("open."): continue
			broad_clearings += int(space.cells.size() >= 9)
			var inside := 0
			for cell: Vector2i in space.cells: inside += int(before.ring_depth(cell)>=2)
			has_interior = has_interior or inside>=4
		interior_towns += int(has_interior)
	assert_gte(interior_towns,24,"a majority of these large towns retain useful interior greens")
	assert_gte(broad_clearings,10,"a meaningful share have room for a grove, not just a tiny edge pocket")

func test_planting_cores_survive_complete_path_planning() -> void:
	var checked := 0
	for seed_value in [6,7,9,10,15,21,32,35]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
		assert_not_null(source,WarrenMazeSitePlanner.last_failure)
		if source==null: continue
		for column: Vector2i in source.massif.columns:
			if not bool(source.massif.columns[column].get("planting_core",false)): continue
			for cell: Vector3i in source.passage_kinds:
				assert_ne(Vector2i(cell.x,cell.z),column,"a finished street must skirt the reserved planting core")
			checked += 1
	assert_gte(checked,24,"several real towns retain usable planting islands")
