extends SceneTree
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var total := 0
	var kept := 0
	var failures := 0
	for scale: StringName in [&"compact", &"standard", &"large", &"grand"]:
		for seed_value in range(1, 13):
			var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(scale), &"", false)
			if source == null:
				print("SOURCE_FAIL ", seed_value, " ", scale)
				failures += 1
				continue
			var count := source.excavation.tunnel_cells.size()
			total += count
			for cell: Vector3i in source.excavation.tunnel_cells:
				if bool(source.excavation.covered.get(cell, false)): kept += 1
			print("SOURCE ", seed_value, " ", scale, " tunnels=", count, " bridges=", source.excavation.bridge_spans.size())
			if OS.get_cmdline_user_args().has("--compile"):
				var spatial := FROZEN.spatial(source, program)
				if spatial == null:
					failures += 1
					continue
				var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
				if not built.payload.validate(): failures += 1
				print("COMPILED ", seed_value, " ", scale, " ", built.roof_audit)
	print("SURVEY total_tunnel_cells=", total, " covered=", kept, " failures=", failures)
	quit(0 if failures == 0 and total == kept else 1)
