extends GutTest

func _ground() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(1)
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0)
	return plan.compute_region(4,4,16).with_terrain_grades([
		TerrainGradePatch.new(&"flat_pad", {Vector2i.ZERO:1.08}, Vector2(49.5,49.5), 3)])

func _faces(region: HeightfieldRegion, x: float, z: float) -> Array[Vector3]:
	var mesh := TerrainChunkMesher.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var owner := Vector2i(TerrainTileField.point_of(x+1),TerrainTileField.point_of(z+1))
	var road := Vector2i(roundi((x+1)/24),roundi((z+1)/24))
	var faces: Array[Vector3] = []
	mesh._emit_path_surface(surface, region, null, null, owner, road, x, z,
		[Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE],
		TerrainTileField.bake_point(region,owner), faces)
	return faces

func test_constant_pad_keeps_exact_extent_and_height_with_two_collision_triangles() -> void:
	var region := _ground()
	var faces := _faces(region,48,48)
	assert_eq(faces.size(),6,"a flat square needs two collision triangles, not 128")
	var area := 0.0
	for i in range(0,faces.size(),3):
		area += (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*0.5
	assert_almost_eq(area,4.0,0.000001)
	for point: Vector3 in faces:
		assert_eq(point.y, Vector3(0,1.08,0).y)
		assert_between(point.x,48.0,50.0)
		assert_between(point.z,48.0,50.0)

func test_curved_grade_collar_retains_every_fine_collision_triangle() -> void:
	var faces := _faces(_ground(),44,48)
	assert_eq(faces.size(),384,"a real height change retains its complete quarter-metre grid")
	var heights: Dictionary = {}
	for point: Vector3 in faces: heights[point.y] = true
	assert_gt(heights.size(),2,"fixture exercises a curved slope")
