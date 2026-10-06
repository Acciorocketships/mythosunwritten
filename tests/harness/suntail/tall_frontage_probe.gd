extends SceneTree
## Exposed repeated wall columns, after footprint variation and projections.
## Uses finished native masses and structural occupancy; hidden party walls do not count.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := args[args.find("--cities")+1] if args.has("--cities") else "31:large,63:grand,103:grand"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var result := {}
	for city: String in cities.split(","):
		var key := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(key[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(key[1])))
		if spatial == null:
			result[city] = {"failure": WarrenVolumetricSolver.last_failure}
			continue
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
		var occupied := {}
		for other: BuildingMass in built.masses:
			for floor: Dictionary in other.storeys:
				for cell: Vector2i in floor.cells:
					for rise in int(floor.get("bands",2)):
						occupied[Vector3i(cell.x,int(floor.floor_band)+rise,cell.y)] = other.stable_id
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var source_plots := {}
		var source_heights := {}
		for plot: Dictionary in source.plots:
			source_plots[String(plot.id)] = plot
		for record: Dictionary in WarrenPlotPlanner.outcomes(source).get("buildings", []):
			source_heights[String(record.id)] = record
		var rows := []
		for mass: BuildingMass in built.houses:
			if mass.storeys.size() < 4: continue
			var assembler := BuildingKitAssembler.new(built.house_kits.get(StringName(String(mass.stable_id).trim_prefix("kit.")), SuntailBuildingKit.create()))
			assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
				var at := Vector3i(cell.x,band,cell.y)
				if occupied.has(at): return occupied[at] != mass.stable_id
				return spatial.grid.use_at(at) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME
			var columns := {}
			var floors := []
			for storey: Dictionary in mass.storeys:
				var rect := BuildingDesigner._bounds(storey.cells)
				floors.append({"band": storey.floor_band, "bounds": rect, "cells": storey.cells.size(), "inset": storey.get("inset", false), "balcony": storey.get("bears_balcony", false), "abutted": storey.get("abutted", false), "projections": storey.get("projections", []), "openings": storey.openings})
				for slot: Dictionary in BuildingKitAssembler.storey_slots(storey,assembler._edge_exposure(mass,int(storey.floor_band),int(storey.get("bands",2)))):
					if not assembler._slot_exposed(mass,slot,int(storey.floor_band),int(storey.get("bands",2))): continue
					var edge: Vector3i = slot.edge
					var offset := float((storey.get("wall_offsets", {}) as Dictionary).get(edge, 0))
					var at := str([slot.centre, slot.dir, offset])
					if not columns.has(at): columns[at] = []
					columns[at].append(int(storey.floor_band))
			var longest := 0
			for column: String in columns:
				var bands: Array = columns[column]
				bands.sort()
				var run := 0
				var last := -100
				for band: int in bands:
					run = run+1 if band==last+2 else 1
					longest = maxi(longest,run)
					last = band
			if longest >= 4:
				rows.append({"host": mass.stable_id, "seed": mass.seed, "longest": longest, "floors": floors, "columns": columns,
					"source_plot": source_plots.get(String(mass.stable_id).trim_prefix("kit.spatial.parcel.maze."), {}),
					"height_decision": source_heights.get(String(mass.stable_id).trim_prefix("kit.spatial.parcel.maze."), {})})
		result[city] = rows
		print("TALL_FRONTAGES ", city, " ", rows.size())
	if args.has("--output"):
		FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit()
