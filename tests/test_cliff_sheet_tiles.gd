extends GutTest

## October 6: the cliff sheet renders as SHEET_TILE world squares, each an
## indexed surface with its own LODs, so the GPU can cull, LOD and share
## vertices. Splitting must keep every triangle exactly once, with all its
## attributes (an empty-tile bug made the sheet vanish in game).

const CRAGS := preload("res://scripts/terrain/field/CliffRockCrags.gd")

## A connected heightfield soup (shared lattice points, like the sheet's
## surface nets), attributes a function of position as in mesh_arrays.
func _soup() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	var point := func(i: int, j: int) -> Vector3: return Vector3(i * 2.0, sin(i * 0.3) * 3.0 + cos(j * 0.2) * 2.0, j * 2.0)
	for i in 100:
		for j in 105:
			var a: Vector3 = point.call(i, j)
			var b: Vector3 = point.call(i + 1, j)
			var c: Vector3 = point.call(i, j + 1)
			var d: Vector3 = point.call(i + 1, j + 1)
			for v: Vector3 in [a, b, d, a, d, c]:
				vertices.append(v)
				colors.append(Color(v.x / 200.0, v.z / 210.0, 0.5, 1.0))
				uv2.append(Vector2(v.x, v.z))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

func test_tiles_keep_every_triangle_once_with_its_attributes() -> void:
	var pose := Transform3D(Basis(Vector3.UP, 0.3), Vector3(-100, 5, 30))
	var arrays := _soup()
	var tiles := CRAGS.split_tiles(arrays, pose, CRAGS.SHEET_TILE, false)
	assert_gt(tiles.size(), 4, "a 200 x 210 m sheet spans several 48 m tiles")
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var seen := {}
	var unique := 0
	for tile: Dictionary in tiles:
		var v: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = tile.arrays[Mesh.ARRAY_COLOR]
		var u: PackedVector2Array = tile.arrays[Mesh.ARRAY_TEX_UV2]
		var index: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
		assert_gt(index.size(), 0, "no empty tile")
		assert_eq(c.size(), v.size())
		for k in v.size():
			assert_eq(u[k], Vector2(v[k].x, v[k].z), "attributes travel with their vertex")
		var squares := {}
		for t in index.size() / 3:
			var a := v[index[3 * t]]; var b := v[index[3 * t + 1]]; var d := v[index[3 * t + 2]]
			var centre := pose * ((a + b + d) / 3.0)
			squares[Vector2i(floori(centre.x / CRAGS.SHEET_TILE), floori(centre.z / CRAGS.SHEET_TILE))] = true
			seen[[a, b, d]] = true
		assert_eq(squares.size(), 1, "a tile holds one world square")
		unique += v.size()
	assert_eq(seen.size(), source.size() / 3, "every triangle kept once")
	assert_lt(unique, source.size() / 4, "welding shares vertices (the soup had six per quad)")

func test_tiles_carry_lods() -> void:
	var tiles := CRAGS.split_tiles(_soup(), Transform3D.IDENTITY, 400.0)
	assert_eq(tiles.size(), 1)
	assert_gt((tiles[0].lods as Dictionary).size(), 0, "a 21k-triangle tile simplifies")
