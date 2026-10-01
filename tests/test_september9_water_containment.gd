extends GutTest

func test_baked_water_lattice_keeps_the_exact_natural_surface_samples()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=2697992464
	var storeys:Dictionary={}
	var detail:Dictionary={}
	for z in range(-10,11):
		for x in range(-10,11):
			storeys[Vector2i(x,z)]=rng.randi_range(0,6)
			detail[Vector2i(x,z)]=rng.randi_range(0,3)
	var region:=HeightfieldRegion.new(storeys,detail)
	for step:float in [3.0,6.0]:
		var base:=Vector2(-108,-102)
		var actual:=WaterField._sample_ground_lattice(region,base,49,step)
		var expected:=PackedFloat32Array()
		for j in 49:
			for i in 49:
				var p:=base+Vector2(i,j)*step
				expected.append(TerrainTileField.surface_y(region,p.x,p.y))
		assert_eq(actual,expected,"exact float32 samples include positive/negative half-cell ownership at step "+str(step))

func test_priority_flood_matches_the_full_heap_reference()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=2697992464
	for run in 40:
		var side:=9+run%7
		var ground:=PackedFloat32Array()
		var levels:=PackedFloat32Array()
		var rivers:=PackedFloat32Array()
		for index in side*side:
			var g:=float(rng.randi_range(0,8)) if run%2==0 else rng.randf_range(0,8)
			ground.append(g)
			levels.append(g+rng.randf_range(0.1,5.0) if rng.randf()<0.4 else -INF)
			rivers.append(levels[-1] if rng.randf()<0.15 else -INF)
		var expected:=levels.duplicate()
		preload("res://tests/fixtures/september9_spill_reference.gd").solve(null,Vector2.ZERO,side,expected,ground.duplicate(),rivers)
		WaterField._cap_hydrostatic_fill(null,Vector2.ZERO,side,levels,ground,rivers)
		assert_eq(levels,expected,"identical spill-limited water on mixed flat/sloped terrain, case %d"%run)

func test_lazy_fine_ground_preserves_a_real_connected_pocket()->void:
	var terrain:Dictionary={}
	for z in range(-5,6):
		for x in range(-5,6): terrain[Vector2i(x,z)]=2 if absi(x)>=2 or absi(z)>=2 else 0
	var region:=HeightfieldRegion.new(terrain,terrain)
	var base:=Vector2(-48,-48)
	var levels:=PackedFloat32Array();levels.resize(17*17);levels.fill(-INF)
	for j in 17:
		for i in range(8,17):
			var p:=base+Vector2(i,j)*6
			if TerrainTileField.surface_y(region,p.x,p.y)<4.65: levels[j*17+i]=4.7
	var dense:=WaterField._build_sub_lattice_rescue(region,base,levels,PackedFloat32Array(),17,WaterField._sample_ground_lattice(region,base,33,3))
	var lazy:=WaterField._build_sub_lattice_rescue(region,base,levels,PackedFloat32Array(),17)
	assert_eq(lazy.levels,dense.levels,"sampling terrain on demand preserves every fine hydraulic value")
	var rescued:=0
	for value:float in lazy.levels:
		if is_finite(value): rescued+=1
	assert_gt(rescued,20,"the comparison contains a real rescued pocket, not two empty outputs")

func test_rectangular_spill_matches_an_identical_domain_with_high_padding()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=2697992464
	for shape:Vector2i in [Vector2i(7,19),Vector2i(23,5),Vector2i(11,17)]:
		var side:=maxi(shape.x,shape.y)+2
		var ground:=PackedFloat32Array();ground.resize(shape.x*shape.y)
		var levels:=ground.duplicate();levels.fill(-INF)
		var rivers:=levels.duplicate()
		var padded_ground:=PackedFloat32Array();padded_ground.resize(side*side);padded_ground.fill(1000000.0)
		var padded_levels:=padded_ground.duplicate();padded_levels.fill(-INF)
		var padded_rivers:=padded_levels.duplicate()
		for j in shape.y:
			for i in shape.x:
				var index:=j*shape.x+i
				var padded:=(j+1)*side+i+1
				ground[index]=rng.randf_range(0,8)
				levels[index]=ground[index]+rng.randf_range(0.1,5)
				padded_ground[padded]=ground[index]
				padded_levels[padded]=levels[index]
				# The rectangle perimeter is an open outlet. Encode that same
				# boundary condition as a fixed head in the padded reference.
				if i==0 or j==0 or i==shape.x-1 or j==shape.y-1:
					padded_rivers[padded]=ground[index]-WaterField.EPS
		var expected:=padded_levels.duplicate()
		preload("res://tests/fixtures/september9_spill_reference.gd").solve(null,Vector2.ZERO,side,expected,padded_ground,padded_rivers)
		WaterField._cap_hydrostatic_fill(null,Vector2.ZERO,shape.x,levels,ground,rivers)
		for j in range(1,shape.y-1):
			for i in range(1,shape.x-1):
				assert_eq(levels[j*shape.x+i],expected[(j+1)*side+i+1],"same physical outlet graph in a rectangular grid")

func _flood(ground:PackedFloat32Array,side:int,seed_level:float)->PackedFloat32Array:
	var levels:=PackedFloat32Array();levels.resize(side*side);levels.fill(-INF)
	var rivers:=PackedFloat32Array();rivers.resize(side*side);rivers.fill(-INF)
	var queue:=PriorityQueue.new()
	queue.push([int(side*side/2),seed_level],seed_level)
	WaterField._relax_fill(null,Vector2.ZERO,side,levels,ground,rivers,queue)
	WaterField._cap_hydrostatic_fill(null,Vector2.ZERO,side,levels,ground,rivers)
	queue.free()
	return levels

func test_an_unbounded_flat_has_no_hydrostatic_lake_above_it()->void:
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(4.0)
	var levels:=_flood(ground,9,9.0)
	var wet:=0
	for value:float in levels:
		if is_finite(value):wet+=1
	assert_eq(wet,0,"an open flat cannot hold five metres of water merely because a high seed touches it")

func test_a_real_bowl_keeps_water_below_its_rim()->void:
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(0.0)
	for i in 9:
		for index in [i,72+i,i*9,i*9+8]:ground[index]=8.0
	var levels:=_flood(ground,9,3.0)
	assert_almost_eq(levels[40],3.0,0.000001)
	assert_false(is_finite(levels[4]),"the eight-metre rim stays dry")

func test_a_bowl_with_a_low_outlet_cannot_hold_the_upstream_head()->void:
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(0.0)
	for i in 9:
		for index in [i,72+i,i*9,i*9+8]:ground[index]=8.0
	ground[4]=2.0
	var levels:=_flood(ground,9,6.0)
	assert_lte(levels[40],2.0,"the actual outlet limits the held lake level")
	assert_gt(levels[40],1.0,"containment must retain the real lower basin")

func test_unfilled_ground_inside_a_closed_basin_is_not_an_outlet()->void:
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(0.0)
	for i in 9:
		for index in [i,72+i,i*9,i*9+8]:ground[index]=8.0
	var levels:=PackedFloat32Array();levels.resize(81);levels.fill(-INF)
	levels[40]=3.0
	var rivers:=PackedFloat32Array();rivers.resize(81);rivers.fill(-INF)
	WaterField._cap_hydrostatic_fill(null,Vector2.ZERO,9,levels,ground,rivers)
	assert_almost_eq(levels[40],3.0,0.000001,"a dry neighbor inside the same enclosing rim is not a drain")

func test_reported_plateaus_and_lower_channel_banks_do_not_hold_high_water()->void:
	var geography:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd")
	var water:=geography.make_water(2697992464)
	var plan:=geography.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0.0,0.0,64)
	for p:Vector2 in [Vector2(48,-1569),Vector2(132,-1710),Vector2(114,-1854),Vector2(180,-1830)]:
		var chunk:=Vector2i((p/192.0).floor())
		assert_false(fields.water(chunk).is_wet(p),
			"the photographed site cannot retain a distant high head above its basin/local-river ceiling: "+str(p))

func test_surface_smoothing_cannot_raise_a_retained_spill_level()->void:
	var levels:=PackedFloat32Array([2,2,7,2,2,7,2,2,7])
	var ground:=PackedFloat32Array();ground.resize(9);ground.fill(0)
	var rivers:=PackedFloat32Array([-INF,-INF,7,-INF,-INF,7,-INF,-INF,7])
	WaterField._smooth_fill_surface(null,Vector2.ZERO,3,levels,ground,rivers)
	assert_lte(levels[4],2.0,"the neighboring upstream river cannot lift a lake above its outlet")

func test_a_carved_flowing_channel_can_descend_to_its_open_lower_end()->void:
	var cells:Dictionary={}
	for z in range(-3,4):
		for x in range(-3,4): cells[Vector2i(x,z)]=2
	var natural:=HeightfieldRegion.new(cells,{})
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(0.0)
	var levels:=ground.duplicate()
	var anchors:=ground.duplicate();anchors.fill(-INF)
	for j in 9:
		for i in 9:
			levels[j*9+i]=7.0-float(j)*0.5
		anchors[j*9+4]=levels[j*9+4]
	var ceilings:=WaterField._cap_hydrostatic_fill(null,Vector2(-24,-24),9,levels,ground,anchors,6.0,null,natural,levels.duplicate())
	WaterField._smooth_fill_surface(null,Vector2(-24,-24),9,levels,ground,anchors,ceilings)
	for j in range(1,8):
		assert_gt(levels[j*9+3],0.0,"the side of the excavated channel does not drain to its downstream head")
		assert_lt(levels[j*9+3],8.0,"the flow remains below the uncarved hillside")
		assert_gt(levels[j*9+3],levels[(j+1)*9+3],"the connected channel continues downhill")

func test_pre_carve_ground_does_not_license_water_on_unchanged_land()->void:
	var cells:Dictionary={}
	for z in range(-3,4):
		for x in range(-3,4): cells[Vector2i(x,z)]=2
	var natural:=HeightfieldRegion.new(cells,{})
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(8.0)
	var levels:=ground.duplicate();levels.fill(12.0)
	var anchors:=ground.duplicate();anchors.fill(-INF)
	WaterField._cap_hydrostatic_fill(null,Vector2(-24,-24),9,levels,ground,anchors,6.0,null,natural,levels.duplicate())
	assert_false(is_finite(levels[40]),"a high head on an unchanged open plateau still has no containing volume")

func test_excavation_ceiling_allows_a_smooth_river_join_without_lifting_a_lake()->void:
	var levels:=PackedFloat32Array([2,2,7,2,2,7,2,2,7])
	var ground:=PackedFloat32Array();ground.resize(9);ground.fill(0)
	var rivers:=PackedFloat32Array([-INF,-INF,7,-INF,-INF,7,-INF,-INF,7])
	var ceilings:=PackedFloat32Array([2,8,7,2,8,7,2,8,7])
	WaterField._smooth_fill_surface(null,Vector2.ZERO,3,levels,ground,rivers,ceilings)
	assert_gt(levels[4],2.0,"the carved join can smooth its initially stair-stepped flood levels")
	assert_lte(levels[4],8.0,"the original hillside still contains the flow")
	assert_lte(levels[3],2.0,"the neighboring standing basin retains its physical spill ceiling")

func test_a_distant_high_source_cannot_fill_a_lower_rivers_excavation()->void:
	var cells:Dictionary={}
	for z in range(-3,4):
		for x in range(-3,4): cells[Vector2i(x,z)]=4
	var natural:=HeightfieldRegion.new(cells,{})
	var ground:=PackedFloat32Array();ground.resize(81);ground.fill(4.0)
	var levels:=ground.duplicate();levels.fill(12.0)
	var anchors:=ground.duplicate();anchors.fill(-INF)
	var local_flow:=ground.duplicate();local_flow.fill(1.2)
	WaterField._cap_hydrostatic_fill(null,Vector2(-24,-24),9,levels,ground,anchors,6.0,null,natural,local_flow)
	assert_false(is_finite(levels[40]),"cutting ground from 16 to 4 m for a 1.2 m river does not license a 12 m mound")

func test_fine_rescue_cannot_spread_a_high_shoreline_over_an_open_flat()->void:
	var terrain:Dictionary={}
	for z in range(-4,18):
		for x in range(-4,18):terrain[Vector2i(x,z)]=0
	var region:=HeightfieldRegion.new(terrain,terrain)
	var n:=WaterField.FILL_M+1
	var levels:=PackedFloat32Array();levels.resize(n*n);levels.fill(-INF)
	for j in n:
		for i in range(16,n):levels[j*n+i]=4.7
	var rescue:=WaterField._build_sub_lattice_rescue(region,Vector2.ZERO,levels)
	var ctx:Dictionary={"fill_base":Vector2.ZERO,"region":region,"fill":{"levels":levels,"sub_levels":rescue.levels,"sub_ground":rescue.ground}}
	assert_false(WaterField.wet(ctx,region,Vector2(84,96)),"fine topology repair must respect an open lower escape route")

func test_enclosing_rim_is_independent_of_extra_dry_domain()->void:
	for side in [9,15,23]:
		var ground:=PackedFloat32Array();ground.resize(side*side);ground.fill(0)
		var center:=int(side/2)
		for z in range(center-3,center+4):
			for x in range(center-3,center+4):
				if abs(x-center)==3 or abs(z-center)==3:ground[z*side+x]=8
		var levels:=_flood(ground,side,5.0)
		assert_almost_eq(levels[center*side+center],5.0,0.000001,"adding dry terrain outside a real rim preserves its lake")

func test_photographed_water_neighborhoods_agree_across_chunk_borders()->void:
	var geography:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd")
	var water:=geography.make_water(2697992464)
	var plan:=geography.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,12,0,64)
	var failures:Array=[]
	for chunk:Vector2i in [Vector2i(-1,-9),Vector2i(0,-9),Vector2i(-1,-10),Vector2i(0,-10)]:
		var own:=fields.water(chunk)
		for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			var other:=fields.water(chunk+direction)
			for along in range(0,193,3):
				for offset in [-6,0,6]:
					var p:=Vector2(chunk)*192.0+(Vector2(192+offset,along) if direction.x else Vector2(along,192+offset))
					var a:=own.level_at(p)
					var b:=other.level_at(p)
					if is_finite(a)!=is_finite(b) or (is_finite(a) and absf(a-b)>0.001):
						failures.append({"p":p,"a":a,"b":b})
	assert_eq(failures,[],"independent source domains and fine windows share one physical surface")

func test_sparse_spill_outlets_match_dense_preparation_including_boundary_anchors()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=2697992464
	for shape:Vector2i in [Vector2i(11,19),Vector2i(23,7),Vector2i(9,9)]:
		var ground:=PackedFloat32Array()
		var levels:=PackedFloat32Array()
		var anchors:=PackedFloat32Array()
		var indices:=PackedInt32Array()
		for index in shape.x*shape.y:
			ground.append(rng.randf_range(0,10))
			levels.append(ground[-1]+rng.randf_range(.1,5) if rng.randf()<.3 else -INF)
			anchors.append(levels[-1])
			if is_finite(anchors[-1]): indices.append(index)
		var dense:=WaterField.SpillSearch.new(null,Vector2.ZERO,shape.x,levels,ground.duplicate(),anchors,3)
		var sparse:=WaterField.SpillSearch.new(null,Vector2.ZERO,shape.x,levels,ground.duplicate(),anchors,3,null,indices)
		assert_eq(sparse.escape,dense.escape,"same initial physical outlets, including anchors on the outer boundary")
		for index in levels.size():
			assert_eq(sparse.height_at(index),dense.height_at(index),"identical escape for every wet or dry terrain point")
		dense.close();sparse.close()
