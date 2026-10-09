extends GutTest
const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const B=preload("res://scripts/terrain/water/WaterBankBound.gd")

func _field(sample:Callable)->RefCounted:
	var env=E.new()
	env.origin=Vector2.ZERO;env.w=73;env.h=73
	env.surface.resize(env.w*env.h)
	for z in env.h:
		for x in env.w:env.surface[z*env.w+x]=sample.call(Vector2(x,z)*E.H)
	return env

func _violation(env:RefCounted, bound:Dictionary, step:float)->float:
	var worst:=0.0
	for z in range(24,49):
		for x in range(24,49):
			var p:=Vector2(x,z)*E.H/step-Vector2(bound.first)
			var cell:=Vector2i(p.floor());var t:=p-Vector2(cell)
			var idx:int=cell.y*bound.size.x+cell.x
			var values:PackedFloat64Array=bound.values
			var water:=lerpf(lerpf(values[idx],values[idx+1],t.x),lerpf(values[idx+bound.size.x],values[idx+bound.size.x+1],t.x),t.y)
			worst=maxf(worst,env.surface[z*env.w+x]-water)
	return worst

func test_a_plane_needs_no_artificial_clearance_margin()->void:
	var env=_field(func(p:Vector2)->float:return 30.0+p.x*.5-p.y*.25)
	var bound:=B.node_bounds(env,Rect2(12,12,12,12),Vector2.ZERO,6.0)
	for z in bound.size.y:
		for x in bound.size.x:
			var p:Vector2=Vector2(bound.first+Vector2i(x,z))*6.0
			assert_almost_eq(bound.values[z*bound.size.x+x],env.at(p),0.000001)

func test_coarse_and_fine_interpolation_cannot_cut_sampled_bank_crests()->void:
	var shapes:Array[Callable]=[
		func(p:Vector2)->float:return 60.0-.12*(p-Vector2(17,19)).length_squared(),
		func(p:Vector2)->float:return 30.0+4.0*sin(p.x*.4)*cos(p.y*.3),
		func(p:Vector2)->float:return 20.0 if p.x<17.5 else 8.0,
	]
	for shape in shapes:
		var env=_field(shape)
		for step:float in [3.0,6.0]:
			var bound:=B.node_bounds(env,Rect2(12,12,12,12),Vector2.ZERO,step)
			assert_lte(_violation(env,bound,step),0.000001,"interpolated lower bound covers every bank-grid node")

func test_bounds_keep_their_values_across_negative_world_coordinates()->void:
	var env=_field(func(p:Vector2)->float:return 30.0+4.0*sin(p.x*.4)*cos(p.y*.3))
	var focus:=Rect2(12,12,12,12)
	var expected:=B.node_bounds(env,focus,Vector2.ZERO,6.0)
	var offset:=Vector2(-1533,-879)
	env.origin+=offset
	var actual:=B.node_bounds(env,Rect2(focus.position+offset,focus.size),offset,6.0)
	assert_eq(actual.first,expected.first)
	assert_eq(actual.size,expected.size)
	assert_eq(actual.values,expected.values,"world-aligned cells produce identical bounds after translation")

func test_native_bound_matches_the_reference_and_falls_back_on_fault()->void:
	var native=preload("res://scripts/native/NativeGridKernels.gd")
	native.setup()
	var env=_field(func(p:Vector2)->float:return 30.0+4.0*sin(p.x*.4)*cos(p.y*.3))
	var expected:=B.node_bounds(env,Rect2(12,12,12,12),Vector2.ZERO,6.0,false)
	if ClassDB.class_exists(&"CSharpScript"):
		assert_true(native.enabled,"all native grid and bank-bound parity cases pass")
	assert_eq(B.node_bounds(env,Rect2(12,12,12,12),Vector2.ZERO,6.0).values,expected.values)
	if native.enabled:
		native.arm_fault()
		assert_eq(B.node_bounds(env,Rect2(12,12,12,12),Vector2.ZERO,6.0).values,expected.values,"a native exception returns the reference result")
		assert_false(native.enabled,"a fault disables the port")
		var warnings:=0
		for error in get_errors():
			if error.contains_text("forced test fault"):
				error.handled=true;warnings+=1
		assert_eq(warnings,1,"the forced exception is reported once")
		native.enabled=true # restore the previously gated test process

func test_fixed_bank_tiles_reuse_bounds_across_certified_source_windows()->void:
	var plan:=HeightfieldPlan.new(23,160.0,40,"mean",3)
	plan.set_raw_height_override(func(x:int,z:int)->float:return 32.0+float(x)*.7+float(z)*.2)
	var small:=plan.compute_rect_region(Rect2i(-12,-12,32,32))
	var large:=plan.compute_rect_region(Rect2i(-24,-24,64,64))
	var a:=B.tile_bounds(small,Vector2i.ZERO,23)
	var b:=B.tile_bounds(large,Vector2i.ZERO,23)
	assert_eq(a,b,"source window size does not change a cached world tile")
	assert_eq(plan._water_bank_bounds.size(),1,"both requests retain one compact tile")
	plan._water_bank_lock.lock()
	plan._water_bank_bounds.clear()
	plan._water_bank_lock.unlock()
	var rebuilt:=B.tile_bounds(large,Vector2i.ZERO,23)
	assert_eq(rebuilt,a,"cold bounds agree across certified region windows")
