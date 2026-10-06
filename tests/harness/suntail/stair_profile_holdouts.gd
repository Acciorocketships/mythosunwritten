extends SceneTree
## Holdout roof audits and admitted physical stair profiles.
const P = preload("res://scripts/terrain/features/villages/fabric/WarrenStairEdgeProfiles.gd")


func _init():
	call_deferred("run")


func run():
	var program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output = []
	for seed_value in [53, 103, 301, 83]:
		var source = WarrenMazeSitePlanner.plan(
			seed_value, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false
		)
		var spatial = load("res://tests/fixtures/frozen_maze_source.gd").spatial(source, program)
		var fabric = spatial.compiled_fabric_cache()
		var roofs = P.roof_bounds(fabric)
		var fits = []
		for t in spatial.source_volume.transitions:
			if not t.is_vertical():
				continue
			var profile = P.choose(t, roofs, fabric.surface_plan)
			if profile != Vector2.ZERO:
				fits.append(
					{"from": str(t.from_cell), "to": str(t.to_cell), "profile": str(profile)}
				)
		var kit = SuntailBuildingKit.create()
		var built = KitVillageBuildings.build(spatial, fabric, kit)
		var audit = load("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit)
		output.append({"seed": seed_value, "fits": fits, "audit": audit})
		print("HOLDOUT ", output.back())
	FileAccess.open("/tmp/stair-profile-holdouts.json", FileAccess.WRITE).store_string(
		JSON.stringify(output, "  ")
	)
	quit()
