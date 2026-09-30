extends SceneTree
## Town 2695877283924445960/compact (tests/test_town_closures.gd): kit storey
## cells over public air, over outside air, and the released crowns there.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const USE := ["OUT", "ALLOC", "PUB_AIR", "DAY_AIR", "PRIV", "STRUCT", "SERVICE"]
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(2695877283924445960, {}, WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
	var counts := {}
	for mass: BuildingMass in built.masses:
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			var below := mass.cells_at_band(floor - 1)
			for cell: Vector2i in storey.cells:
				if below.has(cell): continue
				var under := Vector3i(cell.x, floor - 1, cell.y)
				var u: String = USE[spatial.grid.use_at(under)] if spatial.grid.contains(under) else "NOGRID"
				if u in ["PUB_AIR", "DAY_AIR", "OUT"] and floor > mass.ground_band:
					print("OVER ", mass.stable_id, " band=", floor, " cell=", cell, " under=", u, "/", spatial.grid.owner_name_at(under))
				counts[u] = int(counts.get(u, 0)) + 1
	for mass: BuildingMass in built.masses:
		if String(mass.stable_id).contains("skywalk"):
			print("SKY ", mass.stable_id, " storeys=", mass.storeys.map(func(st): return [st.floor_band, st.cells.keys()]), " decks=", mass.decks.map(func(d): return [d.band, d.cells.keys()]))
	print("SPANS ", SettlementFabricAssembler.maze_skywalk_spans(spatial.compiled_fabric_cache()))
	print("COUNTS ", counts, " released=", spatial.audit.get("maze_released_unborne_crown_cells", -1), " tunnels=", source.excavation.tunnel_cells.keys(), " roofs=", source.audit.get("plot_outcomes", {}).get("tunnel_roofs", []))
	quit()
