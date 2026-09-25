extends SceneTree
## Corpus probe for L1: raised public levels serving a single building.
## A raised level is a route band above the entrance band; its destinations are
## the plots addressed from it. Usage: -s lone_levels_probe.gd -- --seeds=1-40
func _init() -> void:
	var first := 1; var last := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			var r := arg.trim_prefix("--seeds=").split("-")
			first = int(r[0]); last = int(r[1])
	var cities: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city="):
			var parts := arg.trim_prefix("--city=").split(":")
			cities.append([int(parts[0]), StringName(parts[1])])
	var totals := {"towns": 0, "raised_levels": 0, "lone_levels": 0, "lone_asset_levels": 0, "towns_with_lone": 0}
	var jobs: Array = cities.duplicate()
	if jobs.is_empty():
		for scale in [&"compact", &"standard", &"large", &"grand"]:
			for seed_value in range(first, last + 1): jobs.append([seed_value, scale])
	for job in jobs:
		if true:
			var seed_value: int = job[0]
			var scale: StringName = job[1]
			var profile := WarrenVillageScaleProfile.for_id(scale)
			var plan := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"partition", false)
			if plan == null: continue
			totals.towns += 1
			if not cities.is_empty():
				print("CITY ", seed_value, " route=", plan.excavation.route)
				for plot: Dictionary in plan.plots: print("  PLOT ", plot.id, " kind=", plot.kind, " floor=", plot.floor, " door=", plot.door_walk, " cells=", (plot.cells as Array).size())
			var entry: int = plan.excavation.route.front().y
			# Walk the spine from its end back to the last level change: that run of
			# route cells is the terminal platform the whole climb exists to reach.
			var route: Array = plan.excavation.route
			var top: int = (route.back() as Vector3i).y
			var section := {}
			for index in range(route.size() - 1, -1, -1):
				var cell: Vector3i = route[index]
				if cell.y != top: break
				section[cell] = true
			var dest := []
			for plot: Dictionary in plan.plots:
				if section.has(plot.get("door_walk", Vector3i(0, -99, 0))): dest.append("%s:%s" % [plot.kind, plot.id])
			for lane: Dictionary in plan.excavation.lanes:
				if section.has(lane.anchor):
					for plot: Dictionary in plan.plots:
						if (lane.cells as Array).has(plot.get("door_walk", Vector3i(0, -99, 0))): dest.append("lane:%s" % plot.id)
			totals["plots"] = int(totals.get("plots", 0)) + plan.plots.size()
			for plot: Dictionary in plan.plots:
				if plot.kind == &"asset":
					totals["assets"] = int(totals.get("assets", 0)) + 1
					if int(plot.floor) > entry: totals["raised_assets"] = int(totals.get("raised_assets", 0)) + 1
			var raised_buildings := 0
			for plot: Dictionary in plan.plots:
				if plot.kind != &"deck" and (plot.get("door_walk", Vector3i(0, -99, 0)) as Vector3i).y > entry: raised_buildings += 1
			if top > entry and raised_buildings <= 1:
				totals["purpose_poor_towns"] = int(totals.get("purpose_poor_towns", 0)) + 1
				print("POOR scale=", scale, " seed=", seed_value, " top=", top, " raised_buildings=", raised_buildings)
			if top > entry:
				totals.raised_levels += 1
				if dest.size() <= 1:
					totals.lone_levels += 1
					totals.towns_with_lone += 1
					if dest.size() == 1 and String(dest[0]).begins_with("asset"): totals.lone_asset_levels += 1
					print("LONE scale=", scale, " seed=", seed_value, " top=", top, " entry=", entry, " cells=", section.size(), " dest=", dest)
	print("TOTALS ", totals)
	quit()
