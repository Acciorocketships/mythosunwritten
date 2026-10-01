extends GutTest

var _fields: WorldFieldBlockCache
func _water_fields() -> WorldFieldBlockCache:
	if _fields==null:
		var water:=TerrainWorldTuning.make_water(2697992464)
		_fields=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	return _fields

func test_reported_connected_river_clears_the_upper_lip_before_falling() -> void:
	var fields := _water_fields()
	var field := fields.water_at(Vector2(-240,-1473))
	var region := fields.region_at(Vector2(-240,-1473))
	var missing := 0
	var worst_depth := INF
	for x: float in [-246,-240,-234]:
		for offset in range(1,61):
			var p := Vector2(x,-1476+offset*.1)
			var ground := TerrainTileField.surface_y(region,p.x,p.y)
			var level := WaterField.level_at(field.raw_context(),p)
			worst_depth=minf(worst_depth,level-ground)
			if not field.is_wet(p): missing+=1
	assert_eq(missing,0,"water supplied above and below the cliff must not dry before the lip")
	assert_gt(worst_depth,WaterField.EPS,"the full upper approach clears its real supporting ground")
	assert_true(field.is_wet(Vector2(-240,-1477)),"the downstream receiving water remains")
	assert_false(field.is_wet(Vector2(-260,-1500)),"the neighboring high dry bank stays dry")

## Synthetic cliff on 12 m lattice points (dual-grid terrain): storey
## `storeys` where x*dir.x + z*dir.y >= 0, so the wall stands on the dual-cell
## border 6 m from the origin point. The 9x9 fill lattice uses the offset fill
## phase (nodes at 12 i +- 3), so the wall lies between two nodes; there is
## no node on the crest and no node is lifted: WaterField evaluates the cell
## per side of the wall toward a crest at crown + DESCENT_CLAMP.
func _cliff_fixture(direction: Vector2i, storeys: int = 2, offset: Vector2i = Vector2i.ZERO) -> Dictionary:
	var controls: Dictionary = {}
	for z in range(-5,6):
		for x in range(-5,6):
			controls[Vector2i(x,z)+offset] = storeys if (x*direction.x+z*direction.y)>=0 else 0
	var region := HeightfieldRegion.new(controls,{})
	var base := Vector2(-27,-27)+Vector2(offset)*12
	var ground := WaterField._sample_ground_lattice(region,base,9,6)
	var levels := ground.duplicate()
	for i in levels.size(): levels[i]=maxf(2,ground[i]+WaterField.DESCENT_CLAMP)
	var ctx := {"fill_base":base,"fill_size":9,"fill":{"levels":levels},"region":region}
	return {"region":region,"base":base,"ground":ground,"levels":levels,"ctx":ctx,
		"wall":Vector2(offset)*12-Vector2(direction)*6}

func test_native_cliff_spill_is_supported_in_all_four_directions() -> void:
	for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var f := _cliff_fixture(direction)
		WaterField._reconcile_connected_surface(f.levels,f.ground,9,6)
		# From 3 m inside the cliff top across the wall to 3 m below it.
		for i in 49:
			var p: Vector2 = f.wall+Vector2(direction)*(3.0-i*.125)
			var depth := WaterField._fill_bilinear_coarse(f.ctx,p)-TerrainTileField.surface_y(f.region,p.x,p.y)
			assert_gt(depth,WaterField.EPS,"continuous wet spill "+str(direction)+" at "+str(p))

func test_cliff_support_does_not_fill_a_dry_upper_bank() -> void:
	var f := _cliff_fixture(Vector2i.RIGHT)
	for i in f.levels.size():
		if f.ground[i]>2: f.levels[i]=-INF
	for d in [0.5,1.0,2.0,3.0]:
		var p: Vector2 = f.wall+Vector2(d,0)
		var level := WaterField._fill_bilinear_coarse(f.ctx,p)
		assert_true(level==-INF or level<=TerrainTileField.surface_y(f.region,p.x,p.y)+WaterField.EPS,
			"a lower river cannot climb an unsupplied bank at "+str(p))

func test_ordinary_slopes_keep_their_existing_water_profile() -> void:
	var f := _cliff_fixture(Vector2i.RIGHT,1)
	for i in 49:
		var p: Vector2 = f.wall+Vector2(3.0-i*.125,0)
		assert_almost_eq(WaterField._fill_bilinear_coarse(f.ctx,p),WaterField._fill_untapered_level(f.ctx,p),0.00001,
			"a continuous native slope has no cliff crest: plain interpolation at "+str(p))

## Re-pinned (dual-grid terrain, 2026-09-30): the photographed second lip at
## (-229,-1432) no longer carries water on the 12 m field. Scan criteria: in
## the four chunks around the reported lips, every TerrainTileField
## wall_segments half-segment whose field is wet 1 m on both sides, with the
## upper water above the wall top by more than EPS and the receiving water
## below it (a supplied spill); the one nearest the old lip, excluding the
## first lip's reach at z = -1470..-1476, is the z = -1446 wall at
## x = -234..-228 (top 8.00, upper water 8.10, fall below at 7.17). The points
## run from 4 m up the approach, across the lip, 2 m down the fall.
func test_the_other_reported_lip_retains_its_incoming_water() -> void:
	var field:=_water_fields().water_at(Vector2(-231,-1446))
	var missing:=0
	for z in [-1442,-1444,-1445.5,-1446.5,-1448]:
		for x in [-232.5,-231.5,-230.5,-229.5]:
			if not field.is_wet(Vector2(x,z)):
				missing+=1
	assert_eq(missing,0,"the supplied upper flow crosses the left-hand lip as well")

func test_a_supplied_dry_crest_connects_only_to_existing_receiving_water() -> void:
	var f:=_cliff_fixture(Vector2i.LEFT,2,Vector2i(-10,-62))
	# Supplied upper water spills over the negative-world wall to the lip.
	var lip: Vector2 = f.wall+Vector2(0.01,0)
	assert_gt(WaterField._fill_bilinear_coarse(f.ctx,lip)-TerrainTileField.surface_y(f.region,lip.x,lip.y),
		WaterField.EPS,"supplied film reaches its physical spill crest")
	# Without receiving water the crest is not a spill: the low side stays dry.
	for i in f.levels.size():
		if f.ground[i]<4: f.levels[i]=-INF
	for d in [1.0,2.0,3.0]:
		var p: Vector2 = f.wall+Vector2(d,0)
		var level := WaterField._fill_bilinear_coarse(f.ctx,p)
		assert_true(level==-INF or level<=TerrainTileField.surface_y(f.region,p.x,p.y)+WaterField.EPS,
			"no lower body or hanging outlet is invented at "+str(p))

func test_spill_and_receiving_water_match_the_detached_physics_sampler() -> void:
	var field:=_water_fields().water_at(Vector2(-240,-1473))
	var ctx:=field.raw_context()
	var sampler:=WaterSampler.build(ctx,ctx.region,Vector2(-250,-1485),3,13,23)
	var worst:=0.0
	var dry:=0
	# The second line crosses the re-pinned second lip (z = -1446, see
	# test_the_other_reported_lip_retains_its_incoming_water) from 6 m up its
	# approach to 6 m down its fall.
	for line:Array in [[Vector2(-240,-1470),Vector2(0,-.125),89],
			[Vector2(-231,-1440),Vector2(0,-.125),97]]:
		for i in line[2]:
			var p:Vector2=line[0]+line[1]*i
			var expected:=WaterField.level_at(ctx,p)
			var actual:=sampler.level_at(p)
			if not is_finite(actual): dry+=1
			else: worst=maxf(worst,absf(actual-expected))
	assert_eq(dry,0,"both connected drops retain physical water across their full approach and descent")
	assert_lt(worst,.00001,"physical sampling retains the canonical spill height")

func test_one_sided_bounds_keep_the_actual_corner_owner_and_real_ridges() -> void:
	var f:=_cliff_fixture(Vector2i.LEFT,2,Vector2i(-10,-62))
	# A taller flat neighbor touches the approach at z = -738. It is a
	# different crown, not a ridge inside the supplied upper water's tile.
	# (Per edge, September 27: two storeys taller, so it walls down to the
	# approach; a one-storey neighbour would meet it on one shared slope.)
	# 12 m points (dual-grid terrain): the approach line lies on the dual-cell
	# border z = -61.5 * 12 between points (-10,-62) (8 m) and (-10,-61), inside
	# point -10's dual cell in x.
	f.region._storeys[Vector2i(-10,-61)]=4
	var line:=Rect2(Vector2(-120,-738),Vector2(5.99,0))
	assert_eq(TerrainTileField.height_bounds_on_side(f.region,line,Vector2i(-10,-62)),Vector2(8,8))
	assert_eq(TerrainTileField.height_bounds(f.region,line).y,16.0,"unowned closed bounds retain both neighboring crowns")
	assert_eq(TerrainTileField.height_bounds_on_side(f.region,line,Vector2i(-10,-61)).y,16.0,"a real high owner must never be omitted")
