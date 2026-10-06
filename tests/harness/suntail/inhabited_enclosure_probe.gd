extends SceneTree
const NativeFacades = preload("res://tests/fixtures/native_facade_enclosure.gd")
## Finished inhabited room coverage, including separately emitted enclosed skywalks.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "13:large,31:large,43:grand,101:large,103:grand"
	if args.has("--cities"): cities = args[args.find("--cities") + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(fields[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(fields[1])))
		if spatial == null:
			output[city] = {"failure": WarrenVolumetricSolver.last_failure}
			continue
		var fabric := spatial.compiled_fabric_cache()
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var inhabited: Array = built.houses.duplicate()
		for mass: BuildingMass in built.masses:
			if String(mass.stable_id).begins_with("kit.skywalk.") and not mass.storeys.is_empty():
				inhabited.append(mass)
		var native_facades := NativeFacades.build(fabric, EnvironmentCatalog.load_default())
		var native_flanks := 0
		var rooms := {}
		var occupied := {}
		var inhabited_ids := []
		for mass: BuildingMass in inhabited:
			inhabited_ids.append(String(mass.stable_id))
			for floor: Dictionary in mass.storeys:
				for column: Vector2i in floor.cells:
					if not rooms.has(column): rooms[column] = []
					rooms[column].append(int(floor.floor_band))
					for band in range(int(floor.floor_band), int(floor.floor_band) + 2):
						occupied[Vector3i(column.x, band, column.y)] = true
		var walks := {}
		var enclosure := {}
		var open_sides := {"ground": [0,0,0,0,0], "raised": [0,0,0,0,0]}
		var open_structural_sides := {"ground": [0,0,0,0,0], "raised": [0,0,0,0,0]}
		var covered := 0
		var full := 0
		var ceiling_bands := {}
		var full_ceiling_bands := {}
		for walk: Vector3i in source.passage_kinds:
			var heights: Array[int] = []
			var sides: Array[int] = []
			var structural_sides: Array[int] = []
			var elevation := "ground"
			if walk.y > source.massif.bearing_at(Vector2i(walk.x, walk.z)): elevation = "raised"
			var count := 0
			for dx in 2:
				for dz in 2:
					var column := Vector2i(walk.x * 2 + dx, walk.z * 2 + dz)
					var ceiling := 99999
					for floor: int in rooms.get(column, []):
						if floor > walk.y: ceiling = mini(ceiling, floor - walk.y)
					heights.append(ceiling if ceiling < 99999 else -1)
					if ceiling < 99999: count += 1
					var flank_count := 0
					var structural_count := 0
					for step: Vector2i in BuildingMass.DIRS:
						if spatial.grid.use_at(Vector3i(column.x + step.x, walk.y, column.y + step.y)) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
							structural_count += 1
						if occupied.has(Vector3i(column.x + step.x, walk.y, column.y + step.y)):
							flank_count += 1
						else:
							var eye := Vector3(column.x * FabricRecipe.CELL_SIZE, walk.y * FabricRecipe.CELL_SIZE + .8, column.y * FabricRecipe.CELL_SIZE)
							var end := eye + Vector3(step.x,0,step.y) * FabricRecipe.CELL_SIZE
							if NativeFacades.blocks_ray(native_facades,eye,end):
								flank_count += 1
								native_flanks += 1
					sides.append(flank_count)
					structural_sides.append(structural_count)
					if ceiling == 99999: open_structural_sides[elevation][structural_count] += 1
					if ceiling == 99999: open_sides[elevation][flank_count] += 1
			for height: int in heights:
				if height > 0: ceiling_bands[height] = int(ceiling_bands.get(height,0))+1
			if count == 4:
				var highest: int = heights.max()
				full_ceiling_bands[highest] = int(full_ceiling_bands.get(highest,0))+1
			covered += count
			full += int(count == 4)
			walks[str(walk)] = heights
			enclosure[str(walk)] = {"elevation": elevation, "inhabited_flanks": sides, "structural_flanks": structural_sides, "ceiling_bands": heights}
		var refusals := []
		for p: Dictionary in source.excavation.bridge_span_audit.get("refused", []):
			refusals.append({"cells": p.get("cells", []), "reason": p.get("reason", "")})
		var towers := []
		for t: Dictionary in built.towers:
			towers.append({"host": t.host.stable_id, "attachment": t.attachment, "pose": t.pose})
		var stepped := []
		var broad := []
		for mass: BuildingMass in built.houses:
			if mass.storeys.size()>=2:
				var crown: Dictionary = mass.storeys[-1]
				var bounds := BuildingDesigner._bounds(crown.cells)
				if mini(bounds.size.x,bounds.size.y)>=4:
					broad.append({"host":mass.stable_id,"cells":crown.cells.size(),"bounds":bounds,"floors":mass.storeys.size()})
			for floor: Dictionary in mass.storeys:
				if floor.get("stepped_wing",false):
					var box := BuildingDesigner._bounds(floor.cells)
					stepped.append({"host":mass.stable_id,"band":floor.floor_band,"cells":floor.cells.size(),"bounds":box,"nonrectangular":floor.cells.size()<box.size.x*box.size.y})
		var tunnel_limits := []
		for outcome: Dictionary in WarrenPlotPlanner.outcomes(source).get("tunnel_roofs", []):
			var walk: Vector3i = outcome.walk
			var column := Vector2i(walk.x, walk.z)
			var crown := source.passage_headroom_top(walk)
			var host := WarrenPlotPlanner._tunnel_host(source, column, crown)
			var detail := outcome.duplicate()
			detail["crown"] = crown
			detail["huddle_top"] = WarrenTownPlatform.huddle_top(source.massif, column)
			if host.x >= 0:
				detail["host_floor"] = host.y
				detail["host_top"] = source.plots[host.x].top
				detail["minimum_top"] = host.y + WarrenBuildingParcel.STOREY_BANDS + WarrenBuildingParcel.ROOF_RESERVATION_BANDS
				detail["edge_top"] = WarrenPlotPlanner._edge_limit(source, column, host.y, WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
			tunnel_limits.append(detail)
		var record := {
			"tunnel_limits": tunnel_limits,
			"native_facade_flanks": native_flanks,
			"walks": walks, "public_cells": walks.size(), "covered_quarters": covered,
			"fully_covered": full, "inhabited_ids": inhabited_ids,
			"ceiling_band_histogram": ceiling_bands, "full_cover_max_ceiling_band_histogram": full_ceiling_bands,
			"plot_outcomes": WarrenPlotPlanner.outcomes(source), "source_plots": source.plots,
			"source_bridge_proofs": source.excavation.bridge_span_audit.get("seeded", []),
			"source_bridge_cells": source.excavation.bridge_directions.size(),
			"source_tunnels": source.excavation.tunnel_cells.size(),
			"tower_audit": built.roof_audit.get("towers", {}), "towers": towers,
			"room_projections": built.room_projections, "stepped_wings": stepped, "broad_stacks": broad,
			"enclosure": enclosure, "open_quarters_by_inhabited_flanks": open_sides,
			"open_quarters_by_structural_flanks": open_structural_sides,
			"bridge_refusals": refusals,
			"floating": KitFloatingMassAudit.audit(spatial, fabric, built.masses).count,
			"air_intrusions": preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions}
		output[city] = record
		var brief := record.duplicate()
		for key: String in ["walks", "enclosure", "bridge_refusals", "inhabited_ids", "plot_outcomes", "source_plots", "source_bridge_proofs"]:
			brief[key] = "omitted"
		print("ENCLOSURE ", city, " ", brief)
	if args.has("--output"):
		FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(output, "\t"))
	quit()
