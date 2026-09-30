extends SceneTree
## -- CITY:PROFILE,... : kit storey cells over public air, by mass.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var source := WarrenMazeSitePlanner.plan(int(parts[0]), {}, WarrenVillageScaleProfile.for_id(StringName(parts[1])), &"", false)
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
		var by_mass := {}
		for mass: BuildingMass in built.masses:
			for storey: Dictionary in mass.storeys:
				var floor := int(storey.floor_band)
				var below := mass.cells_at_band(floor - 1)
				for cell: Vector2i in storey.cells:
					if below.has(cell): continue
					var under := Vector3i(cell.x, floor - 1, cell.y)
					if spatial.grid.contains(under) and spatial.grid.use_at(under) in [WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
						by_mass[mass.stable_id] = int(by_mass.get(mass.stable_id, 0)) + 1
		print("AIRROOMS ", job, " ", by_mass)
	quit()
