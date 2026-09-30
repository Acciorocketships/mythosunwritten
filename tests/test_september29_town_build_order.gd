extends GutTest
## September 29 review: a kit-built town must be a pure function of (city
## seed, profile), whatever the process built before it (streaming builds
## towns in arbitrary order). `Array.sort()` orders StringNames by interned
## pointer, not text, so house ids sorted that way changed order with the
## process history, and with it every order-dependent choice (lot merging,
## shared canopy claims, roof joins). Town A built alone and after Town B
## differed (roofline minority axis 0.33 vs 0.375).
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")


func _signature(city: int, profile: StringName, program: SettlementFabricProgram) -> String:
	var source := WarrenMazeSitePlanner.plan(city, {},
		WarrenVillageScaleProfile.for_id(profile), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
		SuntailBuildingKit.create())
	var payload := built.payload as EnvironmentInstancePayload
	var parts: Array[String] = []
	for asset_id: Variant in KitVillageBuildings.sorted_ids(payload.asset_ids()):
		var batch: Dictionary = payload.batches[asset_id]
		var rows: Array[String] = []
		for index in batch.transforms.size():
			rows.append("%s %s" % [batch.ids[index] if not batch.ids.is_empty() else "",
				batch.transforms[index]])
		rows.sort()
		parts.append("%s:%s" % [asset_id, "|".join(rows)])
	return "\n".join(parts)


func test_town_is_independent_of_build_order() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var first := _signature(1260018864828801968, &"compact", program)
	# Interns many new StringNames (another town's ids) before rebuilding.
	_signature(1998423929946073270, &"compact", program)
	_signature(3, &"standard", program)
	var again := _signature(1260018864828801968, &"compact", program)
	assert_eq(first.length(), again.length(), "same payload size")
	assert_true(first == again, "Town A rebuilt after other towns is identical")


func test_sorted_ids_is_lexicographic() -> void:
	var ids := [&"zz_order_test_b", &"zz_order_test_c", &"zz_order_test_a"]
	assert_eq(KitVillageBuildings.sorted_ids(ids),
		[&"zz_order_test_a", &"zz_order_test_b", &"zz_order_test_c"])
