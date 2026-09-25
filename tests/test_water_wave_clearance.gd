extends GutTest

class CliffRegion extends RefCounted:
	func storey_at(_x:int,z:int)->int:return 4 if z<=0 else 0
	func surface_height(x:int,z:int)->float:return storey_at(x,z)*4.0

func test_submerged_cliff_cannot_create_a_sharp_wave_amplitude_boundary()->void:
	var st:={"region":CliffRegion.new()}
	var previous:=WaterSkin._swell_scale(st,Vector2(0,12),17,INF)
	var jump:=0.0
	for i in range(1,1201):
		var scale:=WaterSkin._swell_scale(st,Vector2(0,12+i*.01),17,INF)
		jump=maxf(jump,absf(scale-previous));previous=scale
	assert_lte(jump,.01,"crossing a submerged cliff must not suddenly turn full waves on")
	assert_almost_eq(previous,1.0,.00001,"deep water beyond the bank retains its full wave spectrum")

func test_shallow_covered_cliff_remains_covered_during_the_maximum_trough()->void:
	var st:={"region":CliffRegion.new()}
	for z in [10.0,11.0,12.0,13.0]:
		var scale:=WaterSkin._swell_scale(st,Vector2(0,z),16.2,INF)
		assert_gte(16.2-WaterSkin.SWELL_TROUGH_BOUND*scale,16.07-.00001,
			"a face crossing the higher native turf keeps its visual cover")
