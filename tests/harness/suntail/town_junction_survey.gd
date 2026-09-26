extends SceneTree
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only := args[args.find("--only") + 1] if args.has("--only") else ""
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var total := 0
	var kept := 0
	var failures := 0
	for scale: StringName in [&"compact", &"standard", &"large", &"grand"]:
		for seed_value in range(1, 13):
			if not only.is_empty() and only != "%d:%s" % [seed_value, scale]: continue
			if OS.get_cmdline_user_args().has("--markets") and (scale != &"grand" or seed_value not in [6, 8]): continue
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
				var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
				if volume == null:
					print("VOLUME_FAIL ", seed_value, " ", scale, " ", WarrenMazeVolumeAdapter.last_failure)
					failures += 1
					continue
				var spatial := WarrenVolumetricSolver.from_volume(volume, -1, program, false, true)
				if spatial != null:
					var fabric := WarrenSpatialFabricCompiler.generate(spatial, program, true)
					if fabric == null:
						print("FABRIC_FAIL ", seed_value, " ", scale, " ", WarrenSpatialFabricCompiler.last_failure)
						failures += 1
						continue
					spatial.cache_compiled_fabric(fabric)
				if spatial == null:
					print("SPATIAL_FAIL ", seed_value, " ", scale, " ", WarrenVolumetricSolver.last_failure)
					failures += 1
					continue
				var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
				if not built.payload.validate(): failures += 1
				print("COMPILED ", seed_value, " ", scale, " ", built.roof_audit)
	print("SURVEY total_tunnel_cells=", total, " covered=", kept, " failures=", failures)
	quit(0 if failures == 0 and total == kept else 1)
