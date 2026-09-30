extends SceneTree
## Road/grade invariant probe (September 27 dead-end road): for every sealed
## town grade, list accepted country-road lattice edges that are walkable on
## the natural field but not on the final graded field.
##   Godot --headless --path . -s res://tests/harness/road_grade_walkability_probe.gd -- --seed S --radius R [--only sx,sz]
func _init() -> void:
	var seed_value := 2697992464
	var radius := 1
	var only := Vector2i(9999, 9999)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed": seed_value = int(args[i + 1])
		if args[i] == "--radius": radius = int(args[i + 1])
		if args[i] == "--only":
			var p := args[i + 1].split(",")
			only = Vector2i(int(p[0]), int(p[1]))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		SettlementPlan.new(seed_value, water))
	var total_bad := 0
	var towns := 0
	for sx in range(-radius, radius + 1):
		for sz in range(-radius, radius + 1):
			var sc := Vector2i(sx, sz)
			if only.x != 9999 and sc != only: continue
			var t0 := Time.get_ticks_msec()
			var frame := world.frame_for(sc)
			if frame == null: continue
			var record := world.village_plan().record_for(frame)
			if record == null or record.urban_fabric == null or record.urban_fabric.terrain_grade == null:
				continue
			towns += 1
			var grade := record.urban_fabric.terrain_grade
			var bad := audit(grade, heightfield, world)
			total_bad += bad.size() - 1
			print("TOWN super=%s id=%s ms=%d bad=%d %s" % [sc, frame.settlement_id,
				Time.get_ticks_msec() - t0, bad.size() - 1, str(bad)])
	print("SUMMARY towns=%d bad_edges=%d" % [towns, total_bad])
	quit()


static func audit(grade: TerrainGradePatch, heightfield: HeightfieldPlan,
		world: WorldFeaturePlan) -> Array:
	var tile := HeightfieldPlan.CELL
	var area := grade.bounds.grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN + tile)
	var lo := Vector2i(floori(area.position.x / tile), floori(area.position.y / tile))
	var hi := Vector2i(ceili(area.end.x / tile), ceili(area.end.y / tile))
	var mid := (lo + hi) / 2
	var natural := heightfield.compute_region(mid.x, mid.y, maxi(hi.x - lo.x, hi.y - lo.y) / 2 + 3)
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	var masks: Dictionary = {}
	var blocks: Dictionary = {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			blocks[WorldFieldBlockCache.key_of(Vector2(x, z) * tile)] = true
	for block: Vector2i in blocks:
		var ground := world.path_plan().context_for(block).ground_field()
		for cell: Vector2i in ground._connection_masks:
			if cell.x >= lo.x and cell.x <= hi.x and cell.y >= lo.y and cell.y <= hi.y:
				masks[cell] = ground._connection_masks[cell]
	var out := []
	# Roads the town did not seal (not its incident routes) inside its grade reach.
	var unsealed := 0
	for cell: Vector2i in masks:
		if grade.bounds.grow(tile).has_point(Vector2(cell) * tile) and not grade.road_masks.has(cell):
			unsealed += 1
	# Terrain the road ramp changed: controls with versus without sealed roads.
	var bare := TerrainGradePatch.new(grade.stable_id, grade._claims, grade._origin, grade._targets.pitch)
	bare._continuous_source = grade._continuous_source
	bare._continuous_cells = grade._continuous_cells
	bare._continuous_datum = grade._continuous_datum
	var without := natural.with_terrain_grades([bare] as Array[TerrainGradePatch])
	var ramped := []
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if graded.surface_height(x, z) != without.surface_height(x, z):
				ramped.append("%s %.0f->%.0f" % [Vector2i(x, z), without.surface_height(x, z), graded.surface_height(x, z)])
	out.append("sealed=%d unsealed_in_reach=%d ramped=%s" % [grade.road_masks.size(), unsealed, str(ramped)])
	for cell: Vector2i in masks:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(masks[cell]) & int(arm[0])) == 0: continue
			var d: Vector2i = arm[1]
			var nat := TerrainSurfaceField.is_walkable_edge(natural, cell, d, PathProgram.PATH_HALF_WIDTH)
			var fin := TerrainSurfaceField.is_walkable_edge(graded, cell, d, PathProgram.PATH_HALF_WIDTH)
			if nat and not fin:
				if OS.get_cmdline_user_args().has("--dump"):
					var rows := []
					for z in range(cell.y - 3, cell.y + 4):
						var row := "z%d:" % z
						for x in range(cell.x - 4, cell.x + 5):
							row += " %2d%s%2d%s" % [natural.storey_at(x, z),
								"/" , graded.storey_at(x, z),
								"*" if masks.has(Vector2i(x, z)) else " "]
						rows.append(row)
					print("DUMP around %s (x %d..%d) natural/graded storeys, * road\n%s" % [
						cell, cell.x - 4, cell.x + 4, "\n".join(rows)])
				out.append("%s->%s nat %.0f/%.0f fin %.0f/%.0f" % [cell, cell + d,
					natural.surface_height(cell.x, cell.y), natural.surface_height(cell.x + d.x, cell.y + d.y),
					graded.surface_height(cell.x, cell.y), graded.surface_height(cell.x + d.x, cell.y + d.y)])
	return out
