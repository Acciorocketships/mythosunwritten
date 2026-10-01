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
	# Terrain on 12 m lattice points; roads on 24 m route cells (cell c = point 2c).
	var point := HeightfieldPlan.POINT
	var tile := PathProgram.ROUTE_CELL
	var area := grade.bounds.grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN + tile)
	var lo := Vector2i(floori(area.position.x / tile), floori(area.position.y / tile))
	var hi := Vector2i(ceili(area.end.x / tile), ceili(area.end.y / tile))
	var mid := lo + hi   # (lo + hi) / 2 in cells = lo + hi in points
	var natural := heightfield.compute_region(mid.x, mid.y, maxi(hi.x - lo.x, hi.y - lo.y) + 6)
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
	for z in range(lo.y * 2, hi.y * 2 + 1):
		for x in range(lo.x * 2, hi.x * 2 + 1):
			if graded.surface_height(x, z) != without.surface_height(x, z):
				ramped.append("%s %.0f->%.0f" % [Vector2i(x, z), without.surface_height(x, z), graded.surface_height(x, z)])
	# Road edges the bare town grade (no road grading) would break: the
	# September 27 defect class, used to pin equivalent current sites.
	var bare_broken := []
	for cell: Vector2i in masks:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(masks[cell]) & int(arm[0])) == 0: continue
			var d: Vector2i = arm[1]
			if PathProgram.is_route_edge_walkable(natural, cell, d) \
					and not PathProgram.is_route_edge_walkable(without, cell, d):
				bare_broken.append("%s->%s" % [cell, cell + d])
	out.append("sealed=%d unsealed_in_reach=%d bare_broken=%s ramped=%s" % [grade.road_masks.size(),
		unsealed, str(bare_broken), str(ramped)])
	for cell: Vector2i in masks:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(masks[cell]) & int(arm[0])) == 0: continue
			var d: Vector2i = arm[1]
			var nat := PathProgram.is_route_edge_walkable(natural, cell, d)
			var fin := PathProgram.is_route_edge_walkable(graded, cell, d)
			if nat and not fin:
				var heights := []
				for k in 3:
					var p: Vector2i = cell * PathProgram.POINTS_PER_ROUTE_CELL + d * k
					heights.append("%.0f/%.0f" % [natural.surface_height(p.x, p.y), graded.surface_height(p.x, p.y)])
				out.append("%s->%s natural/graded points %s" % [cell, cell + d, str(heights)])
	return out
