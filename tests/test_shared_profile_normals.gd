extends GutTest

class SteepRegion extends RefCounted:
	func surface_height(x: int, _z: int) -> float: return 40.0 if x >= 1 else 0.0
	func storey_at(x: int, _z: int) -> int: return 10 if x >= 1 else 0

func test_continuous_steep_ground_uses_both_sides_of_its_derivative() -> void:
	var saved := TerrainTileField.cliff_end
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	var region := SteepRegion.new()
	var vertices := PackedVector3Array()
	for i in range(1, 120):
		var x := float(i) * 0.1
		vertices.append(Vector3(x, TerrainTileField.surface_y(region,x,3.0),3.0))
	var normals := TerrainChunkMesher.field_normals(vertices,region)
	var worst := 0.0
	for i in vertices.size():
		var v := vertices[i]
		var slope := (TerrainTileField.surface_y(region,v.x+0.25,v.z)-TerrainTileField.surface_y(region,v.x-0.25,v.z))/0.5
		worst = maxf(worst,normals[i].distance_to(Vector3(-slope,1,0).normalized()))
	TerrainTileField.cliff_end = saved
	print("SHARED_NORMAL maximum_vector_error=", worst)
	assert_lt(worst,0.0001,"a steep continuous slope must not be mistaken for a discontinuous cliff lip")
