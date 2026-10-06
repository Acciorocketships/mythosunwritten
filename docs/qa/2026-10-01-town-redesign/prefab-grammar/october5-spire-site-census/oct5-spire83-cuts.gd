extends SceneTree


## Separate field capacity from space lost to public carving. This does not
## alter the field, placement preference, or a finished reservation.
func _init() -> void:
	var rows: Array[Dictionary] = []
	for seed_value in [83]:
		var plan := WarrenMazeSitePlanner.plan(
			seed_value, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"carve"
		)
		assert(plan != null)
		var field := WarrenMazeSourcePlan.new(
			seed_value, plan.scale_profile, plan.massif, WarrenExcavation.new(seed_value)
		)
		var row := {"seed": seed_value, "field": count(field), "carved": count(plan)}
		rows.append(row)
		print("TURRET_SPACE ", row)
	FileAccess.open("/tmp/oct5-spire83-cuts.json", FileAccess.WRITE).store_string(
		JSON.stringify(rows, "  ")
	)
	quit()


func count(plan: WarrenMazeSourcePlan) -> Dictionary:
	print("PREFERENCE ", plan.world_seed, " ", WarrenPlotReservations._prefers_corner_turret(plan.world_seed, {}))
	var stats := {
		"rectangles": 0,
		"ground_bearing": 0,
		"clear_body": 0,
		"fronted": 0,
		"fits": 0,
		"failures": {}, "body_cuts": []
	}
	var template: Dictionary
	for candidate: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		if candidate.kind_id == &"anchor.z_native.turret.00":
			template = candidate
	assert(not template.is_empty())
	var blocked := WarrenPlotPlanner.blocked_columns(plan)
	for column: Vector2i in plan.massif.columns:
		if plan.massif.columns[column].has("house_site"):
			blocked[column] = true
	var streets := WarrenPlotPlanner.street_bands(plan)
	var landings := WarrenPlotPlanner.street_bands(plan, true)
	var access := WarrenPlotReservations.door_access_for(plan) if not streets.is_empty() else {}
	for flip in [false, true]:
		for anchor: Vector2i in plan.massif.columns:
			var cells := WarrenPlotReservations._footprint(
				plan,
				anchor,
				template.depth if flip else template.width,
				template.width if flip else template.depth,
				blocked
			)
			if cells.is_empty():
				continue
			stats.rectangles += 1
			var datum := plan.massif.base_at(anchor)
			var supported := true
			for cell in cells:
				if (
					plan.massif.base_at(cell) != datum
					or plan.massif.bearing_at(cell) != datum
					or (
						datum + template.height_bands
						> WarrenTownPlatform.huddle_top(plan.massif, cell)
					)
				):
					supported = false
			if not supported:
				continue
			stats.ground_bearing += 1
			for cell in cells:
				if (
					not plan.plot_support_ok(cell, datum)
					or plan.first_carved_band(cell, datum, datum + template.height_bands) >= 0
				):
					supported = false
					var cuts: Array = stats.body_cuts
					if true:
						var at_band := plan.first_carved_band(cell, datum, datum + template.height_bands)
						var cut_cell := Vector3i(cell.x, at_band, cell.y)
						cuts.append({"anchor":anchor,"flip":flip,"cell":cell,"datum":datum,
							"lanes":lane_kinds(plan,cut_cell),"first_carved":at_band,"passage":plan.passage_kinds.get(cut_cell,&""),
							"in_route":plan.excavation.route.has(cut_cell),"in_market":plan.market_square_cells.has(cut_cell)})
			if not supported:
				continue
			stats.clear_body += 1
			var doors := WarrenPlotReservations._fronting_door_candidates(cells, landings)
			if not doors.has(datum):
				continue
			stats.fronted += 1
			for door: Vector3i in doors[datum]:
				var mirror := WarrenPlotReservations._new_mirror_tally()
				if WarrenPlotReservations._site_realises(
					plan, streets, template, cells, door, datum, mirror, blocked, {}, access
				):
					stats.fits += 1
					break
				for reason in mirror.get("lane_refusals", {}):
					stats.failures[reason] = (
						int(stats.failures.get(reason, 0)) + int(mirror.lane_refusals[reason])
					)
	return stats

func lane_kinds(plan: WarrenMazeSourcePlan, at: Vector3i) -> Array:
	var kinds := []
	for lane: Dictionary in plan.excavation.lanes:
		if lane.cells.has(at):
			var kind: StringName = lane.get("feature_kind", &"unlabelled")
			if not kinds.has(kind): kinds.append(kind)
	return kinds
