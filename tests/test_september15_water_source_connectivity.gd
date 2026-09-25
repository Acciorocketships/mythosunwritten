extends GutTest

func _retain(levels: PackedFloat32Array, side: int, roots: PackedInt32Array) -> void:
	WaterField._retain_source_connected_fill(levels, side, roots)

func test_spill_cannot_leave_a_pool_beyond_its_now_dry_sill() -> void:
	var side := 9
	var ground := PackedFloat32Array(); ground.resize(side*5); ground.fill(10)
	for z in range(1,4):
		for x in range(1,8): ground[z*side+x]=0 if x!=4 else 2
	ground[2*side]=2
	var levels := ground.duplicate(); levels.fill(-INF)
	for z in range(1,4):
		for x in range(1,8): levels[z*side+x]=4
	var anchors := levels.duplicate(); anchors.fill(-INF)
	var root := 2*side+2
	anchors[root]=4
	WaterField._cap_hydrostatic_fill(null,Vector2.ZERO,side,levels,ground,anchors)
	assert_false(is_finite(levels[2*side+4]),"the spill lowers water beneath the separating sill")
	_retain(levels,side,PackedInt32Array([root]))
	assert_true(is_finite(levels[root]),"the real source survives")
	assert_true(is_finite(levels[2*side+1]),"its connected receiving water survives")
	assert_false(is_finite(levels[2*side+6]),"the pool beyond the dry sill no longer has a supply")

func test_independent_sources_keep_their_own_basins_and_levels() -> void:
	var levels := PackedFloat32Array([2,2,-INF,5,5,2,2,-INF,5,5])
	var before := levels.duplicate()
	_retain(levels,5,PackedInt32Array([0,4]))
	assert_eq(levels,before,"disconnected but genuinely sourced ponds remain unchanged")

func test_a_dried_seed_cannot_reactivate_disconnected_water() -> void:
	var levels := PackedFloat32Array([-INF,-INF,-INF,-INF,3,3])
	_retain(levels,3,PackedInt32Array([0]))
	assert_false(is_finite(levels[4]),"a rejected source supplies no retained water")

func test_component_walk_does_not_wrap_between_grid_rows() -> void:
	var levels := PackedFloat32Array([-INF,-INF,3,3,-INF,-INF])
	_retain(levels,3,PackedInt32Array([2]))
	assert_eq(levels[2],3.0)
	assert_false(is_finite(levels[3]),"adjacent array entries are not necessarily adjacent terrain")

func test_fine_passage_can_resupply_a_pocket_after_coarse_retention() -> void:
	var terrain: Dictionary = {}
	for z in range(-5,6):
		for x in range(-5,6): terrain[Vector2i(x,z)] = 2 if absi(x)>=2 or absi(z)>=2 else 0
	var region := HeightfieldRegion.new(terrain,terrain)
	var base := Vector2(-48,-48)
	var coarse := PackedFloat32Array(); coarse.resize(17*17); coarse.fill(-INF)
	for z in range(5,12):
		for x in range(5,12):
			if x!=8: coarse[z*17+x]=3
	_retain(coarse,17,PackedInt32Array([8*17+6]))
	assert_false(is_finite(coarse[8*17+10]),"coarse topology alone cannot connect the pocket")
	var refined := WaterField._build_sub_lattice_rescue(region,base,coarse,PackedFloat32Array(),17)
	assert_true(is_finite(refined.levels[16*33+20]),"the real submerged passage restores supply through the fine terrain graph")
	assert_almost_eq(refined.levels[16*33+20],3.0,0.001,"fine supply retains the source head")
