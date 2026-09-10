extends GutTest

func test_photographed_ledge_cap_is_a_fitted_horizontal_finish() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var plan:=frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.terrace_retaining_payload(plan)
	var found:=false
	for asset:StringName in payload.batches:
		var batch:Dictionary=payload.batches[asset]
		for i in batch.ids.size():
			if String(batch.ids[i])!="maze-stone/-3/2/8/4": continue
			found=true
			assert_true(asset in [SettlementFabricAssembler.PLANK_SINGLE,SettlementFabricAssembler.PLANK_GALLERY],
				"The photographed ledge needs a horizontal finish rather than a wall lying on its back")
			var bounds:AABB=batch.transforms[i]*catalog.descriptor(asset).measured_aabb
			assert_lt(bounds.size.y,0.17,"The cap must not expose a deep wall end beneath the ledge")
			assert_almost_eq(bounds.end.y,4.5,0.0001)
	assert_true(found)
