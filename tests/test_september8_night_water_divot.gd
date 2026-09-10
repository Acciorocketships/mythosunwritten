extends GutTest

func test_connected_rescue_pocket_inherits_water_head_not_shoreline_taper() -> void:
	var terrain := {}
	for z in range(-4,18):
		for x in range(-4,18): terrain[Vector2i(x,z)]=0
	var region := HeightfieldRegion.new(terrain,terrain)
	var levels := PackedFloat32Array()
	var n := WaterField.FILL_M+1
	levels.resize(n*n);levels.fill(-INF)
	for j in n:
		for i in range(16,n):levels[j*n+i]=4.7
	var rescue := WaterField._build_sub_lattice_rescue(region,Vector2.ZERO,levels)
	var ctx := {"fill_base":Vector2.ZERO,"region":region,"fill":{"levels":levels,"sub_levels":rescue.levels,"sub_ground":rescue.ground}}
	var sampler := WaterSampler.build(ctx,region,Vector2(84,84),3.0,9,9)
	for x in range(84,103):
		assert_almost_eq(WaterField.level_at(ctx,Vector2(x,96)),4.7,0.0001,
			"Continuous water has no trough across the former coarse shoreline: x=%d" % x)
	assert_eq(WaterField.level_at(ctx,Vector2(120,96)),float(levels[0*n+20]),"Untouched interior retains its exact datum")
	for x in range(84,103):
		var p := Vector2(float(x)+0.37,96.61)
		assert_almost_eq(sampler.level_at(p),4.7,0.0001,
			"Frozen swimming heights share the flat pocket at interpolated samples")
