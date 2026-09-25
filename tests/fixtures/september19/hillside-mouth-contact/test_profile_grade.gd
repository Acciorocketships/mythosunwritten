extends GutTest
const STUDY = preload("res://tests/fixtures/september19/hillside-mouth-contact/profile_grade.gd")
func test_descent_uses_distance_along_bend() -> void:
	var points := PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(12,12),Vector2(0,12)])
	var levels := PackedFloat32Array([12,12,12,2])
	var result := STUDY.constrain(points,levels,PackedFloat32Array([0,0,0,0]),.22)
	assert_almost_eq(result[0],9.92,.00001)
	assert_almost_eq(result[1],7.28,.00001)
	assert_almost_eq(result[2],4.64,.00001)
	assert_eq(result[3],2.0)
	assert_eq(levels,PackedFloat32Array([12,12,12,2]),"Input profiles stay immutable")
func test_sill_keeps_actual_clearance_and_upstream_head() -> void:
	var points := PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(24,0),Vector2(36,0)])
	var result := STUDY.constrain(points,PackedFloat32Array([12,12,12,2]),PackedFloat32Array([0,9,0,0]),.22)
	assert_almost_eq(result[1],9.1,.00001,"A physical sill prevents the gentle ramp from cutting into land")
	for i in result.size()-1:
		assert_gte(result[i],result[i+1],"Sill may steepen descent but cannot create an uphill segment")
	assert_eq(result[-1],2.0)
func test_already_gentle_channel_and_lake_stay_identical() -> void:
	var points := PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(24,0)])
	for levels: PackedFloat32Array in [PackedFloat32Array([6,5,4]),PackedFloat32Array([4,4,4])]:
		assert_eq(STUDY.constrain(points,levels,PackedFloat32Array([0,0,0]),.22),levels)
func test_densification_preserves_original_bank_spans() -> void:
	var plan := HeightfieldPlan.new(2697992464,128,32)
	plan.set_raw_height_override(func(_x,_z): return 0.0)
	var region := plan.compute_region(0,0,4)
	var trace := RiverTrace.new()
	trace.points=PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(24,0)])
	trace.widths=PackedFloat32Array([4,5,6])
	trace.beds=PackedFloat32Array([10,6,0])
	var descent := {"lo":1,"hi":2,"pos":PackedVector2Array([Vector2(12,0),Vector2(18,0),Vector2(24,0)]),"w":PackedFloat32Array([5,5.5,6]),"lvl":PackedFloat32Array([8,5,2])}
	var result := STUDY.shape(trace,region,PackedFloat32Array([12,8,2]),[descent])
	var dense: Dictionary = result.descents[0]
	assert_true(dense.has("bank_sources"),"Densifying ordinary river segments must retain their bank constraints")
	if not dense.has("bank_sources"): return
	assert_eq(dense.bank_sources.size(),dense.pos.size()-1,"One provenance entry per offered segment")
	assert_eq(dense.bank_sources,PackedInt32Array([0,0,0,-1,-1]),"Ordinary collar and true descent remain distinct")
func test_seeded_gentle_bank_matches_native_constraint() -> void:
	var plan := HeightfieldPlan.new(2697992464,128,32)
	plan.set_raw_height_override(func(_x,_z): return 0.0)
	var region := plan.compute_region(0,0,4)
	var trace := RiverTrace.new()
	trace.points=PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(24,0),Vector2(300,0),Vector2(312,0)])
	trace.widths=PackedFloat32Array([4,4,4,4,4])
	trace.beds=PackedFloat32Array([4,4,4,4,0])
	var water := WaterPlan.new(2697992464,128,32)
	var context := {"water":water,"rivers":[trace],"ponds":[]}
	var offered: Array[PackedFloat32Array] = []
	for field in [WaterField,preload("res://tests/fixtures/september19/hillside-mouth-contact/candidate_field.gd")]:
		var levels := PackedFloat32Array(); levels.resize(81); levels.fill(-INF)
		var ground := PackedFloat32Array(); ground.resize(81); ground.fill(0)
		var rivers := levels.duplicate()
		var queue := PriorityQueue.new()
		field._seed_rivers(context,region,Vector2(-12,-12),9,levels,ground,rivers,queue)
		offered.append(rivers)
		var bank_index := 4*9+4 # (12,12): outside the channel, inside its bank.
		assert_true(is_finite(rivers[bank_index]),"Ordinary bank retains a head ceiling")
		assert_eq(levels[bank_index],-INF,"The bank constraint is not a water source")
		queue.free()
	assert_almost_eq(offered[0][40],offered[1][40],.00001,"Experimental densification preserves the native bank head")
