extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")

func _jump(sample: Callable, p: Vector2, axis: Vector2) -> float:
	const EPS := 0.01
	return absf(float(sample.call(p+axis*EPS))+float(sample.call(p-axis*EPS))-2.0*float(sample.call(p)))/EPS

func test_reported_diagonal_collar_has_no_slope_jump() -> void:
	var region := Frozen.region("res://tests/fixtures/september8-night-crease-field.txt")
	var sample := func(p: Vector2) -> float: return TerrainSurfaceField.surface_y(region,p.x,p.y)
	for i in range(17):
		var p := Vector2(1910.0,403.0)+Vector2.ONE*float(i)*0.25
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			assert_lt(_jump(sample,p,axis),0.012,"reported collar must have a continuous tangent at %s" % p)
	assert_almost_eq(sample.call(Vector2(1918,412)),12.0,0.00001,"fixed foundation remains level")
	assert_eq(sample.call(Vector2(1896,402)),8.0,"unaffected natural terrain remains unchanged")

func test_concave_claim_boundary_blends_in_every_orientation() -> void:
	var claims: Dictionary={}
	for z in range(-5,6):
		for x in range(-5,6):
			if x<=0 or z<=0: claims[Vector2i(x,z)]=12.0
	for quarter in 4:
		var rotated: Dictionary={}
		for cell: Vector2i in claims:
			var p:=Vector2(cell).rotated(quarter*PI/2)
			rotated[Vector2i(roundi(p.x),roundi(p.y))]=claims[cell]
		var patch:=TerrainGradePatch.new(&"concave",rotated,Vector2.ZERO,3.0)
		var sample:=func(p: Vector2)->float:return patch.surface_y(p,8.0)
		var point:=Vector2(7,7).rotated(quarter*PI/2)
		assert_lt(_jump(sample,point,Vector2.RIGHT),0.012)
		assert_lt(_jump(sample,point,Vector2.DOWN),0.012)

func test_collar_convex_cover_preserves_the_claim_union() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=4081911
	for example in 12:
		var claims: Dictionary={Vector2i.ZERO:12.0}
		for z in range(-4,5):
			for x in range(-4,5):
				if rng.randf()<0.65: claims[Vector2i(x,z)]=12.0
		var patch:=TerrainGradePatch.new(&"cover",claims,Vector2.ZERO,3.0)
		for z in range(-5,6):
			for x in range(-5,6):
				var covered:=false
				for area: Rect2 in patch._collar_rectangles:
					covered=covered or area.has_point(Vector2(x,z)*3)
				assert_eq(covered,claims.has(Vector2i(x,z)),"convex inputs must neither fill holes nor discard claims")
		for i in patch._collar_rectangles.size():
			for j in range(i+1,patch._collar_rectangles.size()):
				assert_false(patch._collar_rectangles[i].encloses(patch._collar_rectangles[j]) or patch._collar_rectangles[j].encloses(patch._collar_rectangles[i]),"redundant subdivisions must not change collar weights")

func test_straight_pad_profile_does_not_depend_on_construction_pitch() -> void:
	var coarse: Dictionary={}
	var fine: Dictionary={}
	for z in 4:
		for x in range(-1,2): coarse[Vector2i(x,z)]=12.0
	for z in 8:
		for x in 6: fine[Vector2i(x,z)]=12.0
	var a:=TerrainGradePatch.new(&"coarse",coarse,Vector2.ZERO,3.0)
	var b:=TerrainGradePatch.new(&"fine",fine,Vector2(-3.75,-.75),1.5)
	for z in range(-16,26):
		for x in range(-19,20):
			assert_almost_eq(a.surface_y(Vector2(x,z),8),b.surface_y(Vector2(x,z),8),0.000001)
