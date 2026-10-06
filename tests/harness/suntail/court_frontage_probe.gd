extends SceneTree
const NativeFacades = preload("res://tests/fixtures/native_facade_enclosure.gd")


## Measure court enclosure using finished rooms, not the uncarved massif.
## Distances are fine building modules; each court column contains 2x2 modules.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "31:large,53:grand,63:grand,83:grand,103:grand,301:grand"
	if args.has("--cities"):
		cities = args[args.find("--cities") + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(
			int(fields[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(fields[1]))
		)
		if spatial == null:
			output[city] = {"failure": WarrenVolumetricSolver.last_failure}
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var native_facades := NativeFacades.build(fabric, EnvironmentCatalog.load_default())
		var rooms := {}
		for mass: BuildingMass in built.houses:
			for floor: Dictionary in mass.storeys:
				for cell: Vector2i in floor.cells:
					for band in range(int(floor.floor_band), int(floor.floor_band) + 2):
						rooms[Vector3i(cell.x, band, cell.y)] = String(mass.stable_id)
		var courts := []
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_DECK:
				continue
			var footprint := {}
			for macro: Vector2i in plot.cells:
				for dx in 2:
					for dz in 2:
						footprint[Vector2i(macro.x * 2 + dx, macro.y * 2 + dz)] = true
			var sides := []
			for step: Vector2i in BuildingMass.DIRS:
				var samples := []
				for cell: Vector2i in footprint:
					if footprint.has(cell + step):
						continue
					var hit := {}
					for distance in range(1, 7):
						var target := cell + step * distance
						var key := Vector3i(target.x, int(plot.floor), target.y)
						if rooms.has(key):
							hit = {"distance": distance, "host": rooms[key]}
							break
					var eye := (
						Vector3(cell.x, float(plot.floor), cell.y) * FabricRecipe.CELL_SIZE
						+ Vector3.UP * 0.8
					)
					var native_distance := 0
					for distance in range(1, 7):
						var end := (
							eye + Vector3(step.x, 0, step.y) * FabricRecipe.CELL_SIZE * distance
						)
						if NativeFacades.blocks_ray(native_facades, eye, end):
							native_distance = distance
							break
					var adjacent := cell + step
					var macro := Vector2i(
						floori(float(adjacent.x) / 2), floori(float(adjacent.y) / 2)
					)
					samples.append(
						{
							"cell": cell,
							"room": hit,
							"native_distance": native_distance,
							"raw_top": source.massif.top_at(macro),
							"plots": _plots_at(source, macro),
							"walk_bands": _walks_at(source, macro)
						}
					)
				sides.append({"direction": step, "samples": samples})
			# Frontage alone cannot distinguish an open square from a hall
			# completely covered by upper rooms. Count finished room floors,
			# including separately emitted enclosed skywalks, over its footprint.
			var overhead := {}
			for mass: BuildingMass in built.masses:
				for storey: Dictionary in mass.storeys:
					var floor_band := int(storey.floor_band)
					if floor_band <= int(plot.floor): continue
					for column: Vector2i in storey.cells:
						if not footprint.has(column): continue
						if not overhead.has(column) or floor_band < int(overhead[column].floor):
							overhead[column] = {"floor":floor_band,"host":mass.stable_id}
			courts.append({"id": plot.id, "floor": plot.floor, "cells": plot.cells, "sides": sides,
				"floor_quarters":footprint.size(), "room_covered_quarters":overhead.size(),
				"overhead_rooms":overhead})
		output[city] = courts
		print("COURTS ", city, " ", courts.size())
	if args.has("--output"):
		FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(
			JSON.stringify(output, "\t")
		)
	quit()


func _plots_at(source: WarrenMazeSourcePlan, cell: Vector2i) -> Array:
	var out := []
	for plot: Dictionary in source.plots:
		if cell in plot.cells:
			out.append({"id": plot.id, "kind": plot.kind, "floor": plot.floor, "top": plot.top})
	return out


func _walks_at(source: WarrenMazeSourcePlan, cell: Vector2i) -> Array:
	var out := []
	for walk: Vector3i in source.passage_kinds:
		if walk.x == cell.x and walk.z == cell.y:
			out.append(walk.y)
	return out
