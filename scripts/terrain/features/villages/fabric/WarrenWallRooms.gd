extends RefCounted
## Addressed rooms replace platform faces or retained support below existing plots. Their
## complete plot reaches its bearing datum, retaining a structural roof cap.
## Natural terrain, existing passage air and upper plots remain immutable.
static func place(plan: WarrenMazeSourcePlan, terraces_only := false) -> void:
	var flights := plan.excavation.flight_cells()
	var claimed := {}
	var count := 0
	for existing: Dictionary in plan.plots:
		if not existing.get("wall_room",false): continue
		count += 1
		for column: Vector2i in existing.cells: claimed[column] = true
	for door: Vector3i in plan.passage_cells():
		if flights.has(door): continue
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(door.x,door.z)+direction
			if claimed.has(column) or not plan.massif.has_column(column): continue
			if WarrenPlotPlanner._asset_clearance_blocks(plan,column,door.y): continue
			# Keep some solid piers and stretches of masonry between homes.
			if plan.massif.is_platform(column) and posmod(WarrenPassageLatticeRules.hash_key(plan.world_seed,0x57a11,
				Vector3i(column.x,door.y,column.y),0),3)==0: continue
			var top := plan.wall_room_top(column)
			if terraces_only:
				if plan.massif.is_platform(column): continue
				top = 1 << 20
				for walk: Vector3i in plan.passage_cells():
					if walk.x==column.x and walk.z==column.y and not flights.has(walk):
						top = mini(top,walk.y)
				if top==1 << 20: continue
			var id := StringName("house.wall-room.%03d" % count)
			var plot := {"id":id,"kind":WarrenMazeSourcePlan.PLOT_HOUSE,
				"cells":[column] as Array[Vector2i],"floor":door.y,
				"top":top,"door_walk":door,
				"building_id":id,"wall_room":true}
			if not plan.wall_room_support_ok(plot,column): continue
			if plan.add_plot(plot):
				claimed[column] = true
				(WarrenPlotPlanner.outcomes(plan)["buildings"] as Array).append({
					"id":id,"cells":1,"floor":door.y,"top":int(plot.top),
					"tiered":bool(plan.plot_facts(plot).tiered),"skyline_peak":false,
					"reason":"","wall_room":true})
				count += 1
	plan.audit["wall_room_count"] = count
