extends GutTest
const F=preload("res://scripts/terrain/heightfield/LandformFeatures.gd")
func _forms()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for z in range(-6,7):
		for x in range(-6,7):
			var f:=F.local_candidate(2697992464,Vector2i(x,z))
			if not f.is_empty():result.append(f)
	return result
func _at(f:Dictionary,q:Vector2)->float:
	return F.local_shape(f,f.pos+q.rotated(f.angle))
func test_local_crests_offer_three_summits_and_lower_connected_passes()->void:
	var checked:=0
	for f in _forms():
		if f.hollow:continue
		var nodes:PackedVector2Array=f.nodes
		for i in 2:
			var peak:=minf(_at(f,nodes[i]),_at(f,nodes[i+1]))
			var saddle:=_at(f,(nodes[i]+nodes[i+1])*.5)
			assert_lt(saddle,peak-4.0,"a usable change of elevation between adjacent local summits")
			assert_gt(saddle,peak*.45,"summits belong to a connected ridge")
		checked+=1
	assert_gt(checked,20)
func test_hollows_keep_a_bridge_across_two_lower_pockets()->void:
	var checked:=0
	for f in _forms():
		if not f.hollow:continue
		for y in [-50.0,0.0,50.0]:
			assert_almost_eq(_at(f,Vector2(f.offset,y)),0.0,.00001,"bridge crosses the hollow without excavating its deck")
		assert_lt(_at(f,Vector2(f.offset-45,0)),-3.0,"lower pocket on one side")
		assert_lt(_at(f,Vector2(f.offset+45,0)),-3.0,"lower pocket on the other side")
		checked+=1
	assert_gt(checked,20)
func test_footprints_end_smoothly_and_leave_the_spawn_clearing_alone()->void:
	for f in _forms():
		for i in 12:
			var axis:=Vector2.from_angle(i*TAU/12)
			assert_almost_eq(_at(f,axis*F.LOCAL_RADIUS),0.0,.00001)
			assert_almost_eq(_at(f,axis*(F.LOCAL_RADIUS-.5)),0.0,.00001)
	for i in 24:
		assert_eq(F.local_relief(2697992464,Vector2.from_angle(i*TAU/24)*199),0.0)
