extends GutTest

func test_photographed_partial_course_keeps_retaining_masonry() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program)
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(spatial.compiled_fabric_cache())
	var key := Vector4i(-6,1,4,0)
	var shell: Dictionary = transaction.shell
	assert_eq(int(shell.treatments[key]),SettlementFabricAssembler.SkinTreatment.MASONRY,
		"The half-height patch in P27 belongs to the surrounding retaining wall")
	var payload := SettlementFabricAssembler.payload(spatial.compiled_fabric_cache())
	payload.append_from(SettlementFabricAssembler.structural_support_payload(spatial.compiled_fabric_cache()))
	var catalog := EnvironmentCatalog.load_default()
	var found := false
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		var index := (batch.ids as Array).find(&"maze-stone/-6/1/4/0")
		if index < 0: continue
		found = true
		assert_eq(asset,SettlementFabricAssembler.MAZE_STONE_MODULE)
		var bounds: AABB = batch.transforms[index] * catalog.descriptor(asset).measured_aabb
		assert_almost_eq(bounds.position.y,1.5,.001,"Native stock starts at the exposed lower band")
		assert_almost_eq(bounds.end.y,3.0,.001,"Native stock closes the upper course seam")
	assert_true(found,"Keep a physical native wall at the reported panel")

func test_partial_and_complete_storeys_in_all_orientations() -> void:
	for side in 4:
		var exposed := {}
		var faces := {}
		for band in range(1,6): exposed[Vector4i(0,band,0,side)] = true
		for band in [1,3,5]: faces[Vector4i(0,band,0,side)] = Vector3i.ZERO
		var treatments := SettlementFabricAssembler.maze_skin_treatments(exposed,faces)
		assert_eq(int(treatments[Vector4i(0,1,0,side)]),SettlementFabricAssembler.SkinTreatment.MASONRY,
			"A single exposed band cannot wear a complete house storey")
		assert_eq(int(treatments[Vector4i(0,5,0,side)]),SettlementFabricAssembler.SkinTreatment.FACADE,
			"Keep the complete upper facade")
		exposed[Vector4i(0,0,0,side)] = true
		treatments = SettlementFabricAssembler.maze_skin_treatments(exposed,faces)
		assert_eq(int(treatments[Vector4i(0,1,0,side)]),SettlementFabricAssembler.SkinTreatment.FACADE,
			"A complete lower storey retains the alternating facade vocabulary")
