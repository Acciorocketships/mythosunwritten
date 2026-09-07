extends GutTest

func test_reported_slope_apron_matches_the_surface_lighting() -> void:
	var region := _reported_region("slope_apron")
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	mesher.set_seed(2697992464)
	var data := mesher.compute_chunk(Vector2i(4,-8),region)
	var neighbor := mesher.compute_chunk(Vector2i(3,-8),region)
	var surface: Array = data.surface_arrays
	var apron: Array = data.apron_arrays
	var seam := {}
	for arrays: Array in [neighbor.surface_arrays, surface]:
		for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			seam[arrays[Mesh.ARRAY_VERTEX][i]] = [arrays[Mesh.ARRAY_NORMAL][i], arrays[Mesh.ARRAY_COLOR][i]]
	var compared := 0
	var worst_normal := 0.0
	var worst_color := 0.0
	for i in (apron[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = apron[Mesh.ARRAY_VERTEX][i]
		if not seam.has(v) or (apron[Mesh.ARRAY_NORMAL][i] as Vector3).y < 0:
			continue
		var expected: Array = seam[v]
		compared += 1
		worst_normal = maxf(worst_normal,(apron[Mesh.ARRAY_NORMAL][i] as Vector3).distance_to(expected[0]))
		var a: Color = apron[Mesh.ARRAY_COLOR][i]
		var b: Color = expected[1]
		worst_color = maxf(worst_color,absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))
	assert_gt(compared,10)
	assert_lt(worst_normal,0.001,"apron and slope share the same edge normals")
	assert_lt(worst_color,0.001,"apron and slope share the same edge tint")

func test_reported_ground_hole_has_one_shared_slope_boundary() -> void:
	var region := _reported_region("ground_hole")
	for x in range(924,937):
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region,x,-2772,39,-116),
			TerrainSurfaceField.surface_y_in_cell(region,x,-2772,39,-115),0.0001,
			"ordinary slope owners must agree beside the higher cliff")

func test_reported_cliff_does_not_replace_a_straight_wall_with_a_false_inner_corner() -> void:
	var region := _reported_region("cliff_backing")
	assert_false(TerrainSurfaceField.own_edge_flat(region,24,-32,Vector2i.DOWN),
		"the east arm actually slopes toward the pocket")
	assert_ne(CliffDressing.corner_flags(region,23,-32).get(Vector2i.ONE,""),"inner",
		"a sloping arm cannot own the wall that an inner-corner replacement requires")

func _reported_region(name: String) -> HeightfieldRegion:
	# The atmosphere rebuild changes H(seed, cell). Keep the actual reported
	# formation so this regression cannot pass merely because the cliff moved.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/september6_reported_terrain.json"))
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	var carved: Dictionary = {}
	for row: Array in fixture.regions[name]:
		var cell := Vector2i(int(row[0]),int(row[1]))
		storeys[cell] = int(row[2])
		levels[cell] = int(row[3])
		if bool(row[4]): carved[cell] = true
	return HeightfieldRegion.new(storeys, levels, carved)
