extends GutTest

func test_photographed_outcrop_has_a_bottom_plate_bearing_into_its_parent_wall() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.structural_support_payload(fabric)
	var prefix := "maze-outcrop/-4/3/-6/1"
	# Frozen local geometry: the parent face is x=-5.25; its jetty reaches 0.75 m.
	var parent_x := -5.25
	var floor_y := 3.0
	var bearing := false
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for i in batch.ids.size():
			if not String(batch.ids[i]).begins_with(prefix): continue
			var bounds: AABB = batch.transforms[i]*catalog.descriptor(asset).measured_aabb
			if bounds.size.y > 0.4 or absf(bounds.end.y-floor_y)>0.001: continue
			bearing = bearing or (bounds.position.x < parent_x-0.05 and bounds.end.x >= parent_x+0.75-0.002 \
				and bounds.size.z >= 3.0-0.002)
	assert_true(bearing,"The photographed jetty needs a continuous bottom plate from inside its parent wall to its projecting face")
