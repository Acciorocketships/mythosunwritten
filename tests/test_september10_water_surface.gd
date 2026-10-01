extends GutTest

## The three photo-16 free-shore interpolation tests below were re-pinned
## (dual-grid terrain, 2026-09-30). Their frozen input
## (tests/fixtures/september15/water-drops/shore_before.bin) was a fill solved
## by the retired pre-September-15 WaterField over retired 24 m cell ground;
## its generator (september15_water_drop_legacy_probe.gd) runs that retired
## field, so it cannot be re-frozen on 12 m points, and reading its cell-keyed
## storeys as points put the frozen fill over the wrong ground. They now run on
## a LIVE free shoreline of the same photographed geography, found by
## tests/harness/september10_free_shore_scan.gd over chunks (2..4,-11..-9): a
## 6 x 6 m window, origin on a whole metre, whose ground is flat (every 1 m
## sample within 1 mm) and which holds both wet and dry samples, measured with
## the routine below. The window at (888,-1812) in chunk (4,-10) has 78
## flat-ground crossings. Limits are unchanged.
const FREE_SHORE_CORNER := Vector2(888,-1812)

func _free_shore() -> Dictionary:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	return fields.water(Vector2i((FREE_SHORE_CORNER/192.0).floor())).raw_context()

func test_photographed_connected_water_does_not_form_a_cliff_over_flat_ground()->void:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	for pair in [[Vector2(831,-1809),Vector2(831,-1806)],
			[Vector2(879,-1809),Vector2(879,-1806)],
			# Re-pinned (dual-grid terrain, 2026-09-30): (825,-1767) is now the
			# dry shore of the 12 m resampled river. The nearest pair 3 m apart
			# with flat ground between them and wet at every 1 m sample within
			# 3 m of both ends (connected water, not a shoreline taper) that
			# still carries a real descent (> 0.3 m) is (825,-1774)/(825,-1771)
			# (tests/harness/september10_photo16_rescan.gd).
			[Vector2(825,-1774),Vector2(825,-1771)]]:
		var a:Vector2=pair[0];var b:Vector2=pair[1]
		var field:=fields.water(Vector2i((a/192.0).floor()))
		assert_true(field.is_wet(a),"retain the lower connected reach at "+str(a))
		assert_true(field.is_wet(b),"retain the upper connected reach at "+str(b))
		var ctx:=field.raw_context()
		assert_lte(absf(WaterField.level_at(ctx,a)-WaterField.level_at(ctx,b)),
			0.90001,"connected water over the photographed flat excavation must descend gently: "+str(pair))

func test_surface_reconciliation_preserves_lakes_dry_barriers_and_wet_beds()->void:
	var ground:=PackedFloat32Array();ground.resize(15*9);ground.fill(0)
	var original:=PackedFloat32Array();original.resize(ground.size());original.fill(-INF)
	for z in range(1,8):
		for x in range(1,7):original[z*15+x]=3.0
		for x in range(8,14):original[z*15+x]=9.0
	# A true dry ridge separates the two lakes. Their different levels must
	# not interact through a rectangular solve, or through missing samples.
	for z in 9:ground[z*15+7]=12
	var levels:=original.duplicate()
	WaterField._reconcile_connected_surface(levels,ground,15,6)
	assert_eq(levels,original,"two enclosed lakes stay flat at their own levels")
	# Open one real wet passage. The upper water should now descend, without
	# changing the dry perimeter or crossing the high bed behind that passage.
	ground[4*15+7]=0;levels[4*15+7]=3
	ground[4*15+10]=8
	original=levels.duplicate()
	WaterField._reconcile_connected_surface(levels,ground,15,6)
	assert_lt(levels[4*15+8],original[4*15+8],"the connected upper reach descends")
	assert_gte(levels[4*15+10],8.09,"actual rising terrain retains a wet cover")
	for i in levels.size():
		if not is_finite(original[i]):
			assert_false(is_finite(levels[i]),"dry nodes stay dry")
		else:
			assert_lte(levels[i],original[i],"never raise a contained head")
			assert_gt(levels[i],ground[i]+WaterField.EPS,"never empty an existing wet node")

func test_surface_reconciliation_is_symmetric_and_idempotent()->void:
	var ground:=PackedFloat32Array();ground.resize(11*11);ground.fill(0)
	var levels:=ground.duplicate();levels.fill(9.7)
	levels[5*11+5]=1.2
	WaterField._reconcile_connected_surface(levels,ground,11,6)
	for z in 11:
		for x in 11:
			assert_almost_eq(levels[z*11+x],levels[x*11+(10-z)],0.000001,"rotation does not change the hydraulic solution")
	var settled:=levels.duplicate()
	WaterField._reconcile_connected_surface(levels,ground,11,6)
	assert_eq(levels,settled,"settling again cannot keep draining the same surface")

func test_an_existing_gentle_descent_is_not_a_conflicting_head_break()->void:
	var ground:=PackedFloat32Array();ground.resize(21*5);ground.fill(0)
	var original:=ground.duplicate()
	for z in 5:
		for x in 21:original[z*21+x]=1.2+x*6*.24
	var levels:=original.duplicate()
	WaterField._reconcile_connected_surface(levels,ground,21,6)
	assert_eq(levels,original,"a continuous authored descent retains its height and cadence")

func test_photo16_water_enters_the_ledge_at_ground_height()->void:
	var ctx:=_free_shore()
	var crossings:=0;var was_wet:=false;var worst:=0.0
	# The window's water lies to the west: walk its middle row from the dry
	# east edge into the water.
	for i in 601:
		var p:=FREE_SHORE_CORNER+Vector2(6-i*.01,3)
		var wet:=WaterField.wet(ctx,ctx.region,p)
		if wet and not was_wet:
			worst=maxf(worst,WaterField.level_at(ctx,p)-TerrainTileField.surface_y(ctx.region,p.x,p.y))
			crossings+=1
		was_wet=wet
	assert_gt(crossings,0,"retain the upper ledge's real shoreline")
	assert_lte(worst,.06,"a dry-to-wet crossing cannot begin above the ground as a floating sheet")

func test_photo16_fine_support_boundary_has_no_vertical_water_step()->void:
	var ctx:=_free_shore()
	# x = 891 is a coarse (6 n + 3) and fine (3 n) fill lattice line inside the
	# window: every wet crossing of it over flat ground is checked.
	var checked:=0
	for row in 61:
		var z:=FREE_SHORE_CORNER.y+row*.1
		var a:=Vector2(890.99,z);var b:=Vector2(891,z)
		var ga:=TerrainTileField.surface_y(ctx.region,a.x,a.y)
		var gb:=TerrainTileField.surface_y(ctx.region,b.x,b.y)
		assert_almost_eq(ga,gb,.001,"the interpolation boundary crosses one flat ledge")
		var la:=WaterField.level_at(ctx,a);var lb:=WaterField.level_at(ctx,b)
		if la<=ga+WaterField.EPS or lb<=gb+WaterField.EPS:continue
		checked+=1
		assert_lte(absf(la-lb),.03,
			"fine rescue cannot insert a vertical step into the same upper water")
	assert_gt(checked,3,"exercise wet water across the lattice line")

func test_photo16_entire_ledge_has_continuous_wet_entries_and_refinement_seams()->void:
	var ctx:=_free_shore()
	var crossing_count:=0;var worst_entry:=0.0;var worst_step:=0.0
	for axis in 2:
		for row in 61:
			var previous:Dictionary={}
			for column in 601:
				var p:=FREE_SHORE_CORNER+(Vector2(column*.01,row*.1) if axis==0 else Vector2(row*.1,column*.01))
				var ground:=TerrainTileField.surface_y(ctx.region,p.x,p.y)
				var level:=WaterField.level_at(ctx,p)
				var wet:=is_finite(level) and level>ground+WaterField.EPS
				if not previous.is_empty() and absf(previous.ground-ground)<.001:
					if wet!=previous.wet:
						worst_entry=maxf(worst_entry,level-ground if wet else previous.level-previous.ground)
						crossing_count+=1
					if wet and previous.wet:worst_step=maxf(worst_step,absf(level-previous.level))
				previous={"ground":ground,"level":level,"wet":wet}
	assert_gt(crossing_count,40,"exercise the full shoreline in both grid directions")
	assert_lte(worst_entry,.06,"water always enters through the actual flat ledge")
	assert_lte(worst_step,.03,"neither the fine-cell boundary nor shore correction inserts a vertical step")

func test_photo16_supplied_outlet_now_crosses_its_crest_without_wetting_the_high_bank()->void:
	var field:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields().water(Vector2i(3,-10))
	var missing:=0
	var worst_step:=0.0
	# Per edge (September 27) the lip's cliff dies toward the south: the
	# outlet crosses where the lip has faded (z >= -1734); the 3-6 m band
	# beside the higher north bank is dry sloping ground (as its crown is).
	for z in [-1734.0,-1731.0,-1728.0]:
		var previous:=NAN
		for i in 1501:
			var p:=Vector2(678+i*.01,z)
			var level:=field.level_at(p)
			if not is_finite(level): missing+=1
			if is_finite(previous) and is_finite(level):worst_step=maxf(worst_step,absf(previous-level))
			previous=level
	assert_eq(missing,0,"the upper supplied reach descends to existing lower receiving water across its actual lip")
	assert_lt(worst_step,.03,"the connected outlet has no vertical surface discontinuity")
	assert_false(field.is_wet(Vector2(690,-1740)),"the adjacent higher crown stays dry")

func test_shore_correction_preserves_a_real_fine_channel_across_a_coarse_dry_edge()->void:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var field:=fields.water(Vector2i(4,-10))
	for p in [Vector2(879,-1815),Vector2(878.9,-1815),Vector2(879.1,-1815)]:
		assert_true(field.is_wet(p),"the existing lower river's fine support cannot be mistaken for a free shoreline")
		assert_almost_eq(field.level_at(p),1.2,.001,"retain the connected lower channel's real head")
