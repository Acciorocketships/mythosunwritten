extends GutTest
const GREEN = preload("res://scripts/terrain/field/CliffVegetation.gd")
func test_vines_cover_broad_patches_of_tall_walls() -> void:
	GREEN.prepare()
	var walls := []
	for x in range(-32,32):
		for y in 4: walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,10.5)))
	var placements := GREEN.vines(walls,2697992464)
	var area := 0.0
	var longest := 0.0
	for p: Dictionary in placements:
		area += p.bounds.size.x*p.bounds.size.y
		longest = maxf(longest,p.bounds.size.y)
	assert_gt(area/(192.0*16.0),0.14,"P05: broad clustered foliage should cover a visible fraction of a tall face")
	assert_gt(longest,8.0,"Tall faces need long hanging groups, not only short strips")
	for asset: StringName in GREEN._bounds:
		if not str(asset).begins_with("native.cliff.trailing_"): continue
		var box: AABB = GREEN._bounds[asset]
		assert_gte(box.size.x,1.0,"Mixed narrow fronds and broad clusters keep distinct silhouettes; total wall coverage is checked above")
		assert_gte(box.position.x,-1.49)
		assert_lte(box.end.x,1.49,"Keep the entire vine inside its real wall bearing")
