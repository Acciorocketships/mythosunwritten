# tests/test_slope_cliff_integration.gd
extends GutTest

func test_cliff_variants_resolve_to_slope_scenes() -> void:
	# TerrainModule stores `scene: PackedScene` (path via scene.resource_path)
	# and `tags: TagList` (TagList.has(tag) -> bool).
	var mods := TerrainModuleDefinitions.load_cliff_variants()
	assert_gt(mods.size(), 0)
	var found_side := false
	for m in mods:
		var path: String = m.scene.resource_path
		if path.findn("CliffSide") != -1:
			found_side = true
			assert_true(path.findn("/slope/") != -1, path)
			assert_true(m.tags.has("24x24x4"))
			assert_true(m.tags.has("cliff"))
	assert_true(found_side, "CliffSide variant not found")

func test_stacked_cliff_variants_registered() -> void:
	var mods := TerrainModuleDefinitions.load_cliff_variants()
	var found := {}
	for m in mods:
		for t in ["cliff-corner-stacked", "cliff-inner-corner-stacked"]:
			if m.tags.has(t):
				found[t] = m.scene.resource_path
	assert_true(found.has("cliff-corner-stacked"), "outer stacked module missing")
	assert_true(found.has("cliff-inner-corner-stacked"), "inner stacked module missing")
	assert_true(String(found.get("cliff-corner-stacked", "")).findn("CliffCornerStacked") != -1, "wrong scene for outer stacked")
	assert_true(String(found.get("cliff-inner-corner-stacked", "")).findn("CliffInCornerStacked") != -1, "wrong scene for inner stacked")
