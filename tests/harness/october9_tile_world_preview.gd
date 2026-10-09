extends "res://tests/harness/terrain_preview.gd"
var variant:=0
var baseline:Script
func _run()->void:
	baseline=preload("res://tests/harness/october9_tile_transition_kernel.gd").make(1.0)
	_size=960;_step=2
	var c:=Vector2(-200,1000)
	for mode in 2:
		variant=mode
		var top:=_build(c)
		var focus:=Vector3(c.x,top*.45,c.y)
		await _shoot(_output+"/"+str(mode)+"_oblique.png",focus+Vector3(-.62,.48,.62)*_size*.95,focus)
		await _shoot(_output+"/"+str(mode)+"_low.png",focus+Vector3(-.55,.16,.55)*_size*.75,focus)
		await _shoot(_output+"/"+str(mode)+"_top.png",Vector3(c.x,_size*1.25,c.y+.01),Vector3(c.x,0,c.y))
		var local_focus:=Vector3(-180,_height_at(Vector2(-180,900)),900)
		await _shoot(_output+"/"+str(mode)+"_battle.png",local_focus+Vector3(-180,150,190),local_focus)
	print("TILE_WORLD_PREVIEW done")
	get_tree().quit()
func _build(c: Vector2) -> float:
	var plan := HeightfieldPlan.new(_seed, TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
		TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS, "mean", TerrainWorldTuning.MAX_CLIFF_STEP)
	var half := _size * 0.5
	var lo := Vector2i(floori((c.x - half) / 12.0) - 2, floori((c.y - half) / 12.0) - 2)
	var count := int(_size / 12.0) + 5
	var region := plan.compute_rect_region(Rect2i(lo, Vector2i(count, count)))
	var n := int(_size / _step) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var top := -INF
	for j in n:
		for i in n:
			var x := c.x - half + i * _step
			var z := c.y - half + j * _step
			var h := TerrainTileField.surface_y(region, x, z)
			if variant == 1:
				var tile := Vector2i(floori(x / 12.0), floori(z / 12.0))
				h = baseline.eval_params(TerrainTileField.tile_params(region, tile), x/12.0-tile.x, z/12.0-tile.y)
			heights[j * n + i] = h
			top = maxf(top, h)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			verts[j * n + i] = Vector3(c.x - half + i * _step, h, c.y - half + j * _step)
			var hx := heights[j * n + mini(i + 1, n - 1)] - heights[j * n + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, n - 1) * n + i] - heights[maxi(j - 1, 0) * n + i]
			normals[j * n + i] = Vector3(-hx, 2.0 * _step, -hz).normalized()
	var indices := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_terrain.mesh = mesh
	_heights = heights
	_origin = c - Vector2(half, half)
	_n = n
	FileAccess.open(_output+"/"+str(variant)+"_heights.json",FileAccess.WRITE).store_string(JSON.stringify({"n":n,"step":_step,"heights":heights}))
	return top
