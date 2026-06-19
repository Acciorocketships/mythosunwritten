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


func _library() -> TerrainModuleLibrary:
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	lib.init()
	return lib

func test_spawn_placement_creates_a_tile_at_the_right_transform() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var rec: Dictionary = {
		"variant_tag": "cliff-side", "family": "cliff",
		"world_x": 48.0, "world_z": -24.0, "origin_y": 4.0, "yaw": 0.0,
	}
	var inst: TerrainModuleInstance = HeightfieldInstantiator.spawn_placement(rec, lib, parent)
	assert_not_null(inst, "a tile instance is produced")
	assert_not_null(inst.root, "the scene was instantiated")
	assert_true(inst.def.tags.has("cliff-side"), "the chosen module is a cliff-side variant")
	assert_almost_eq(inst.transform.origin.x, 48.0, 0.01, "x placed")
	assert_almost_eq(inst.transform.origin.y, 4.0, 0.01, "origin_y placed")
	assert_almost_eq(inst.transform.origin.z, -24.0, 0.01, "z placed")
	assert_eq(inst.root.get_parent(), parent, "tile parented under the target node")

func test_spawn_placement_ground_uses_ground_plain() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var rec: Dictionary = {
		"variant_tag": "ground", "family": "ground",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 0.0, "yaw": 0.0,
	}
	var inst: TerrainModuleInstance = HeightfieldInstantiator.spawn_placement(rec, lib, parent)
	assert_not_null(inst, "ground tile produced")
	assert_true(inst.def.tags.has("ground-plain"), "ground maps to the ground-plain module")

func test_spawn_placement_applies_nonzero_yaw_to_basis() -> void:
	# A dropped/zeroed basis would pass the other (yaw 0) tests; this asserts the
	# yaw actually reaches the placed tile's basis. cliff-side is not a "rotate"
	# tile, so create() leaves the basis we set.
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var rec: Dictionary = {
		"variant_tag": "cliff-side", "family": "cliff",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 4.0, "yaw": PI * 0.5,
	}
	var inst: TerrainModuleInstance = HeightfieldInstantiator.spawn_placement(rec, lib, parent)
	assert_true(inst.transform.basis.is_equal_approx(Basis(Vector3.UP, PI * 0.5)),
		"non-zero yaw is applied to the tile basis")

func test_place_region_places_each_cell_once_and_is_idempotent() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	# First pass over a 3x3 block: 9 tiles spawned.
	var first: Array = placer.place_region(plan, lib, parent, 0, 0, 1)
	assert_eq(first.size(), 9, "first pass spawns 9")
	assert_eq(parent.get_child_count(), 9, "9 tiles for a 3x3 block")
	# Second pass over the same block: returns nothing, no duplicates.
	var second: Array = placer.place_region(plan, lib, parent, 0, 0, 1)
	assert_eq(second.size(), 0, "re-running the same block spawns nothing")
	assert_eq(parent.get_child_count(), 9, "re-running places nothing new (idempotent)")

func test_place_region_tiles_sit_at_plan_heights() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	placer.place_region(plan, lib, parent, 0, 0, 1)
	# Every spawned tile's origin.y equals the plan's surface height for its cell.
	for child in parent.get_children():
		var t: Transform3D = (child as Node3D).transform
		var cx: int = int(round(t.origin.x / HeightfieldPlan.TILE))
		var cz: int = int(round(t.origin.z / HeightfieldPlan.TILE))
		assert_almost_eq(t.origin.y, plan.surface_height(cx, cz), 0.01,
			"tile at (%d,%d) sits at its plan surface height" % [cx, cz])

func test_place_region_streams_incrementally_on_shift() -> void:
	# The real streaming pattern: a block, then a block shifted by one tile in x.
	# Only the new (non-overlapping) column is spawned; overlap is skipped.
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	var first: Array = placer.place_region(plan, lib, parent, 0, 0, 1)
	assert_eq(first.size(), 9, "first block: 9 cells")
	# Center shifts +1 in x: cells cx in {0,1} overlap (already placed); cx=2 is new.
	var shifted: Array = placer.place_region(plan, lib, parent, 1, 0, 1)
	assert_eq(shifted.size(), 3, "only the new column (cx=2, 3 cells) is spawned")
	assert_eq(parent.get_child_count(), 12, "total tiles = 9 + 3 new")

func test_evict_placed_outside_radius_prunes_distant_cells() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	placer.place_region(plan, lib, parent, 0, 0, 1)            # places 9 cells around (0,0)
	assert_eq(placer.placed_count(), 9, "9 cells tracked")
	# Evict everything not within radius 0 of a far center => all 9 pruned.
	placer.evict_placed_outside(100, 100, 0)
	assert_eq(placer.placed_count(), 0, "distant cells pruned from the placed set")

func test_place_region_reports_dropped_cells_for_unknown_tag() -> void:
	# A record whose tag has no module is dropped; spawn_count_dropped returns 1.
	# (spawn_placement internally reports the error via push_error for visibility.)
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	var dropped: int = placer.spawn_count_dropped({
		"variant_tag": "no-such-variant", "family": "cliff",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 0.0, "yaw": 0.0,
	}, lib, parent)
	assert_eq(dropped, 1, "an unknown tag is reported as a dropped placement")
