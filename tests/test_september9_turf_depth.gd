extends GutTest
const A = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_soil_follows_a_clipped_union_without_internal_walls() -> void:
	var turf := {"anchor":Vector3.ZERO,"vertices":PackedVector3Array([
		Vector3(-0.5,6,-0.5),Vector3(0.5,6,-0.5),Vector3(-0.5,6,0.5),Vector3(0.5,6,0.5)]),
		"indices":PackedInt32Array([0,1,2,1,3,2])}
	var original: PackedVector3Array = turf.vertices.duplicate()
	var soil := A.suspended_soil_bed(turf,{Vector3i(0,3,0):true})
	assert_true(EnvironmentInstancePayload._surface_mesh_is_valid(soil))
	assert_eq((soil.indices as PackedInt32Array).size(),36,"Closed two-triangle cap: top, bottom, and four exterior sides")
	assert_eq(turf.vertices,original,"The original walking surface cannot move")
	assert_true((soil.collision_faces as PackedVector3Array).is_empty())
	_assert_closed(soil)
	assert_eq(A.suspended_soil_bed(turf,{}),{},"Ordinary supported ground needs no suspended bed")

func test_photographed_lawn_has_a_closed_bed_seated_in_the_actual_deck() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september9-thin-turf-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var transaction := A.maze_ground_skin_transaction(fabric)
	var payload := A.terrace_retaining_payload(fabric)
	var soil: Dictionary = {}
	for mesh: Dictionary in payload.surface_meshes:
		if mesh.get("soil_bed",false): soil = mesh
	assert_false(soil.is_empty(),"The photographed suspended lawn has soil beneath its surface")
	if soil.is_empty(): return
	_assert_closed(soil)
	var soil_faces := PackedVector3Array()
	for index: int in soil.indices: soil_faces.append(soil.vertices[index])
	var deck_faces := PackedVector3Array()
	var grass_faces := PackedVector3Array()
	for mesh: Dictionary in payload.surface_meshes:
		if not mesh.get("terrain_ground",false) and not mesh.has("rim_owner"): continue
		for index: int in mesh.indices: grass_faces.append(mesh.vertices[index])
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in batch.ids.size():
			var is_deck := String(batch.ids[index]).begins_with("turf-substrate/")
			var is_rim := String(batch.ids[index]).begins_with("maze-rim")
			if not is_deck and not is_rim: continue
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces := (batch.transforms[index] as Transform3D)*piece.local_transform*piece.mesh.get_faces()
				if is_deck: deck_faces.append_array(faces)
				else: grass_faces.append_array(faces)
	assert_gt(deck_faces.size(),0)
	var checked: Dictionary = {}
	for point: Vector3 in soil.vertices:
		var key := Vector2(point.x,point.z)
		if checked.has(key): continue
		checked[key] = true
		var hits := _vertical_hits(grass_faces,point+Vector3(0.00001,0,0.000013))
		assert_gt(hits.size(),0,"Soil stays inside the actual grass/lip silhouette")
		if not hits.is_empty(): assert_lte(point.y,hits[-1]+0.0001,"No soil corner can pierce the native grass")
	for cell: Vector3i in transaction.suspended_plaza:
		var point := Vector3(cell)*FabricRecipe.CELL_SIZE+Vector3(0.13,0,0.17)
		var soil_hits := _vertical_hits(soil_faces,point)
		var deck_hits := _vertical_hits(deck_faces,point)
		assert_gte(soil_hits.size(),2,"Actual soil closes above and below each lawn cell")
		assert_gte(deck_hits.size(),2,"Actual native timber supports each lawn cell")
		if soil_hits.size()<2 or deck_hits.size()<2: continue
		assert_lte(soil_hits[0],deck_hits[-1],"Soil enters the real deck instead of hovering above it")
		assert_almost_eq(soil_hits[-1],float(cell.y+1)*FabricRecipe.CELL_SIZE+A.GREEN_CAP_LIFT-0.004,0.00001)

func test_inset_closes_concave_and_disconnected_lawns_without_degenerate_faces() -> void:
	for quarter in 4:
		var cells: Dictionary = {}
		for xz: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(4,4)]:
			var rotated := Vector2(xz).rotated(quarter*PI*0.5).round()
			cells[Vector3i(rotated.x,3,rotated.y)] = true
		var region := A.maze_terrain_surface_region(cells)
		var turf := TerrainChunkMesher.field_ground_surface(cells,region,1.5,A.GREEN_CAP_LIFT,&"test",true,2)
		var soil := A.suspended_soil_bed(turf,cells)
		_assert_closed(soil)
		for index in range(0,(soil.indices as PackedInt32Array).size(),3):
			var a: Vector3 = soil.vertices[soil.indices[index]]
			var b: Vector3 = soil.vertices[soil.indices[index+1]]
			var c: Vector3 = soil.vertices[soil.indices[index+2]]
			assert_gt((b-a).cross(c-a).length_squared(),0.00000001)

func test_border_closes_the_deck_to_lawn_layer_inside_the_existing_footprint() -> void:
	for quarter in 4:
		var cells: Dictionary = {}
		for xz: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1)]:
			var rotated := xz.rotated(quarter*PI*0.5).round()
			cells[Vector3i(rotated.x,3,rotated.y)] = true
		var border := A.suspended_lawn_border(cells)
		var region := A.maze_terrain_surface_region(cells)
		var lawn := TerrainChunkMesher.field_ground_surface(cells,region,1.5,A.GREEN_CAP_LIFT,&"lawn",true,2)
		var collision: PackedVector3Array = lawn.collision_faces.duplicate()
		A.inset_suspended_lawn(lawn,cells)
		assert_eq(lawn.collision_faces,collision)
		assert_almost_eq(_top_area(lawn,6.0+A.GREEN_CAP_LIFT)+_top_area(border,6.0+A.GREEN_CAP_LIFT+0.002),float(cells.size())*1.5*1.5,0.00001,"Grass and timber cover the original footprint without a missing corner")
		assert_true(EnvironmentInstancePayload._surface_mesh_is_valid(border))
		assert_true((border.collision_faces as PackedVector3Array).is_empty())
		for index in range(0,(border.indices as PackedInt32Array).size(),3):
			var ia: int = border.indices[index]
			var a: Vector3 = border.vertices[ia]
			var b: Vector3 = border.vertices[border.indices[index+1]]
			var c: Vector3 = border.vertices[border.indices[index+2]]
			var normal: Vector3 = border.normals[ia]
			assert_gt(normal.dot(-(b-a).cross(c-a).normalized()),0.99)
			if absf(a.y-6.007)<0.00001 and absf(b.y-6.007)<0.00001 and absf(c.y-6.007)<0.00001:
				assert_gt(normal.y,0.99,"The visible timber top faces outward")
		for point: Vector3 in border.vertices:
			var inside := false
			for cell: Vector3i in cells:
				inside = inside or (absf(point.x-cell.x*1.5)<=0.750001 and absf(point.z-cell.z*1.5)<=0.750001)
			assert_true(inside,"The new frame cannot consume neighboring space")
			assert_lte(point.y,6.0+A.GREEN_RIM_LIFT,"The native lip remains the highest visual edge")
		var low := INF
		var high := -INF
		for point: Vector3 in border.vertices:
			low = minf(low,point.y)
			high = maxf(high,point.y)
		assert_lte(low,6.0-0.20+A.PLANK_Y_OFFSET+A.PLANK_TERRACE_THICKNESS)
		assert_gte(high,6.0+A.GREEN_CAP_LIFT)

func _top_area(mesh: Dictionary, height: float) -> float:
	var area := 0.0
	for index in range(0,(mesh.indices as PackedInt32Array).size(),3):
		var a: Vector3 = mesh.vertices[mesh.indices[index]]
		var b: Vector3 = mesh.vertices[mesh.indices[index+1]]
		var c: Vector3 = mesh.vertices[mesh.indices[index+2]]
		if absf(a.y-height)>0.00001 or absf(b.y-height)>0.00001 or absf(c.y-height)>0.00001: continue
		area += absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))*0.5
	return area


func _vertical_hits(faces: PackedVector3Array, point: Vector3) -> Array[float]:
	var hits: Array[float] = []
	for index in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(point+Vector3.UP*4,point+Vector3.DOWN*4,faces[index],faces[index+1],faces[index+2])
		if hit != null: hits.append((hit as Vector3).y)
	hits.sort()
	return hits

func _assert_closed(mesh: Dictionary) -> void:
	var edges: Dictionary = {}
	for index in range(0,(mesh.indices as PackedInt32Array).size(),3):
		for edge in 3:
			var a: Vector3 = mesh.vertices[mesh.indices[index+edge]]
			var b: Vector3 = mesh.vertices[mesh.indices[index+(edge+1)%3]]
			var keys: Array[String] = [str(a.snapped(Vector3.ONE*0.000001)),str(b.snapped(Vector3.ONE*0.000001))]
			keys.sort()
			var key := keys[0]+"/"+keys[1]
			edges[key] = int(edges.get(key,0))+1
	for count: int in edges.values(): assert_eq(count,2,"Every soil boundary is closed exactly once")
