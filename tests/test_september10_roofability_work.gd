extends GutTest
const Reference = preload("res://tests/fixtures/september10_roofability_reference.gd")

func test_band_index_retains_complete_original_roofability_queries() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(3,{},program,
		WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		rooms.append_array(building.room_records)
	var occupied: Dictionary = {}
	var checked := 0
	for room: WarrenRoomStamp in rooms:
		for cell: Vector3i in room.private_cells: occupied[cell] = true
		if checked % 4 == 0:
			assert_eq(WarrenVolumetricSolver._roofability_defect_count(rooms,occupied),
				Reference.count(rooms,occupied), "partial construction %d" % checked)
		checked += 1
	assert_eq(WarrenVolumetricSolver._roofability_defect_count(rooms,occupied),
		Reference.count(rooms,occupied), "completed native city")
	assert_gt(checked,20)

func test_native_cap_cache_preserves_order_isolation_and_bounded_eviction() -> void:
	var compiler = WarrenSpatialFabricCompiler
	compiler._cap_piece_mutex.lock()
	compiler._cap_piece_cache.clear()
	compiler._cap_piece_mutex.unlock()
	var source: Array[Vector3i] = [Vector3i(0,3,0),Vector3i(1,3,0),
		Vector3i(0,3,1),Vector3i(1,3,1),Vector3i(0,3,2)]
	var original := compiler._compute_cap_pieces(source)
	assert_eq(compiler._cap_pieces(source),original)
	var poisoned := compiler._cap_pieces(source)
	poisoned[0].cells.clear()
	assert_eq(compiler._cap_pieces(source),original, "caller mutation cannot change cached native ownership")
	for offset in range(1,compiler.CAP_PIECE_CACHE_LIMIT+3):
		var translated: Array[Vector3i] = []
		for cell: Vector3i in source: translated.append(cell+Vector3i(offset*10,0,0))
		if offset % 2 == 0: translated.reverse()
		assert_eq(compiler._cap_pieces(translated),compiler._compute_cap_pieces(translated))
	assert_lte(compiler._cap_piece_cache.size(),compiler.CAP_PIECE_CACHE_LIMIT)
	assert_false(compiler._cap_piece_cache.has(var_to_bytes(source)), "individual oldest entry is evicted")
	assert_eq(compiler._cap_pieces(source),original, "cold recomputation retains exact native partition")
