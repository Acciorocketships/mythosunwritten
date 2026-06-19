extends GutTest

# Phase 3b: cells -> placement records (pure, no scene instantiation).

func _stepped_plan() -> HeightfieldPlan:
	# A clean E-W step: x<0 is storey 0 (ground), x>=0 is storey 1 (cliff plateau).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return 4.2 if cx >= 0 else 0.0)
	return plan

func test_placements_cover_every_cell_in_radius() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 1)
	# radius 1 => a 3x3 block => 9 cells, each yields exactly one record.
	assert_eq(recs.size(), 9, "one placement per cell in the (2r+1)^2 block")

func test_placement_record_fields() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 0)
	var r: Dictionary = recs[0]
	for key in ["variant_tag", "family", "world_x", "world_z", "origin_y", "yaw"]:
		assert_true(r.has(key), "record has '%s'" % key)

func test_placement_world_position_uses_tile_spacing() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 2, -3, 0)
	var r: Dictionary = recs[0]
	assert_almost_eq(r["world_x"], 2.0 * HeightfieldPlan.TILE, 0.0001, "world_x = cx * TILE")
	assert_almost_eq(r["world_z"], -3.0 * HeightfieldPlan.TILE, 0.0001, "world_z = cz * TILE")

func test_placement_classifies_the_cliff_edge() -> void:
	# The cell at cx=0 (storey 1) has its west neighbour (cx=-1) a storey lower:
	# a cliff edge => cliff family, cliff-side variant, origin 4.0m.
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 0)
	var r: Dictionary = recs[0]
	assert_eq(r["family"], "cliff", "the storey-1 edge cell is cliff")
	assert_eq(r["variant_tag"], "cliff-side", "single cliff wall => cliff-side")
	assert_almost_eq(r["origin_y"], 4.0, 0.0001, "cliff plateau top at storey*4")
	assert_almost_eq(r["yaw"], PI * 0.5, 0.0001, "left wall => rotation_steps 3 => yaw PI/2")

func test_placement_flat_cliff_plateau_interior() -> void:
	# Far inside the storey-1 plateau (cx=5): all neighbours same storey => a flat
	# cliff-interior tile, no rotation.
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 5, 0, 0)
	var r: Dictionary = recs[0]
	assert_eq(r["family"], "cliff", "interior of the plateau is cliff family")
	assert_eq(r["variant_tag"], "cliff-interior", "flat plateau interior => cliff-interior")
	assert_almost_eq(r["yaw"], 0.0, 0.0001, "no walls => no rotation")
	assert_almost_eq(r["origin_y"], 4.0, 0.0001, "plateau top at 4m")

func test_placement_flat_ground_interior() -> void:
	# Far inside the storey-0 region (cx=-5): flat ground.
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, -5, 0, 0)
	var r: Dictionary = recs[0]
	assert_eq(r["family"], "ground", "interior of the lowland is ground")
	assert_eq(r["variant_tag"], "ground", "flat ground => ground tile")
	assert_almost_eq(r["origin_y"], 0.0, 0.0001, "ground at y=0")
