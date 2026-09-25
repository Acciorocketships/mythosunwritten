extends GutTest
const A = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_open_garden_bases_keep_their_actual_native_underside() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var fabric := Frozen.spatial(Frozen.read("res://tests/fixtures/september10-stone-source.txt"),program).compiled_fabric_cache()
	var tx := A.maze_ground_skin_transaction(fabric)
	var payload := A.terrace_retaining_payload(fabric)
	var faces := PackedVector3Array()
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		for index in batch.ids.size():
			if not String(batch.ids[index]).begins_with("maze-soffit/"): continue
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array((batch.transforms[index] as Transform3D)*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	for cell: Vector3i in [Vector3i(1,3,-3),Vector3i(2,3,-3)]:
		assert_true(tx.capped_ground.has(cell))
		assert_false(tx.retained.has(cell+Vector3i.DOWN))
		assert_true(tx.shell.exposed.has(Vector4i(cell.x,cell.y,cell.z,A.STONE_FACE_DIRECTIONS.find(Vector3i.DOWN))),"An open lower cell cannot be classified as buried ground")
		var point := Vector3(cell)*1.5+Vector3(.13,0,.17)
		var hits: Array[float] = []
		for i in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(point+Vector3.DOWN*.3,point+Vector3.UP*.3,faces[i],faces[i+1],faces[i+2])
			if hit != null: hits.append(hit.y)
		hits.sort()
		assert_gte(hits.size(),2,"Actual timber must close the underside, not merely a logical solid cell")
		if hits.size()>=2: assert_gt(hits[-1]-hits[0],.15)

func test_ground_level_gardens_do_not_grow_an_exposed_timber_base() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var fabric := Frozen.spatial(Frozen.read("res://tests/fixtures/september10-prefab-base-source.txt"),program).compiled_fabric_cache()
	var tx := A.maze_ground_skin_transaction(fabric)
	var checked := 0
	for cell: Vector3i in tx.capped_ground:
		if cell.y != 0: continue
		checked += 1
		assert_false(tx.shell.exposed.has(Vector4i(cell.x,cell.y,cell.z,A.STONE_FACE_DIRECTIONS.find(Vector3i.DOWN))),"The natural ground owns the base of a ground-level garden")
	assert_gt(checked,0)
