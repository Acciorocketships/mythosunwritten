extends SceneTree
var _field_only := false
var _share_flat_streets := false
var _cut_depth := WarrenPlotReservations.PLAZA_LEVEL_BANDS
## Broad courts need buildable same-level frontages, not merely high rock.
## --cut-depth N and --share-flat-streets are study overrides only.
## Shared floors still need support, a level street and no higher street bearing.
## --field searches all supported datums before boring; it proves geometric
## capacity only, without a reachable entry. No option changes production rules.
## Rejection counts record the first failed rule per candidate, not all causes.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_share_flat_streets = args.has("--share-flat-streets")
	_field_only = args.has("--field")
	if args.has("--cut-depth"): _cut_depth = int(args[args.find("--cut-depth")+1])
	var cities := "31:large,53:grand,63:grand,83:grand,103:grand,301:grand"
	if args.has("--cities"): cities = args[args.find("--cities")+1]
	var out := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var profile := WarrenVillageScaleProfile.for_id(StringName(fields[1]))
		var seed_value := int(fields[0])
		var plan: WarrenMazeSourcePlan
		if _field_only:
			plan = WarrenMazeSourcePlan.new(seed_value,profile,WarrenMassifBuilder.build(seed_value,{},profile),WarrenExcavation.new(seed_value))
		else:
			plan = WarrenMazeSitePlanner.plan(seed_value,{},profile,&"carve",false)
		if plan == null:
			out[city] = {"failure":WarrenMazeSitePlanner.last_failure}
			continue
		var streets := WarrenPlotPlanner.street_bands(plan)
		var landings := WarrenPlotPlanner.street_bands(plan,true)
		var blocked := WarrenPlotPlanner.blocked_columns(plan)
		var sites := []
		var rejected := {}
		var supported := 0
		for shape: Vector2i in WarrenPlotReservations._plaza_shapes(plan.scale_profile.scaled(WarrenPlotReservations.DECK_MAX)):
			if mini(shape.x,shape.y)<3: continue
			for anchor: Vector2i in plan.massif.columns:
				var cells := WarrenPlotReservations._plaza_footprint(plan,anchor,shape,blocked)
				if cells.is_empty():
					_count(rejected,"outside_or_blocked")
					continue
				var doors := WarrenPlotReservations._fronting_doors(cells,landings)
				if _field_only:
					var low := 0
					var high := 1 << 20
					for member: Vector2i in cells:
						low = maxi(low,plan.massif.bearing_at(member))
						high = mini(high,plan.massif.top_at(member))
					for datum: int in range(low,high+1): doors[datum] = true
				if doors.is_empty(): _count(rejected,"no_level_threshold")
				for datum: int in doors:
					var cost := 0
					var fits := true
					for member: Vector2i in cells:
						if not _refusal(plan,member,datum,streets,blocked).is_empty():
							fits = false
							_count(rejected,_refusal(plan,member,datum,streets,blocked))
							break
						cost += absi(plan.massif.top_at(member)-datum)
					if not fits: continue
					if cost>cells.size()*WarrenPlotReservations.PLAZA_CUT_BUDGET_BANDS:
						_count(rejected,"total_cut_budget")
						continue
					supported += 1
					var sides := []
					for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
						var edge := 0
						var fronts := 0
						var reasons := {}
						for member: Vector2i in cells:
							var next := member+direction
							if cells.has(next): continue
							edge += 1
							var join := WarrenPlotPlanner._join(plan,next,datum,streets,blocked,{},-1,false)
							var reason := String(join.reason)
							if reason == "support rule refuses this floor": reason = _support_refusal(plan,next,datum)
							if reason.is_empty() and WarrenPlotPlanner._edge_envelope_top(plan,next)<datum+WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
								reason = "edge envelope cannot host a room"
							if reason.is_empty(): fronts += 1
							else: reasons[reason] = int(reasons.get(reason,0))+1
						sides.append({"direction":direction,"fronts":fronts,"edge":edge,"reasons":reasons})
					sites.append({"anchor":anchor,"shape":shape,"floor":datum,"cost":cost,"sides":sides,"minimum_ring":_minimum_ring(plan,cells)})
		out[city] = {"sites":sites,"rejections":rejected,"supported":supported}
		print("COURT_SUPPLY ",city," ",sites.size())
	if args.has("--output"):
		FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	quit()


func _count(counts: Dictionary, reason: String) -> void:
	counts[reason] = int(counts.get(reason,0))+1


func _refusal(plan: WarrenMazeSourcePlan, cell: Vector2i, datum: int, streets: Dictionary, blocked: Dictionary) -> String:
	if blocked.has(cell): return "blocked"
	if WarrenPlotPlanner._asset_clearance_blocks(plan,cell,datum): return "asset_clearance"
	if not plan.massif.has_column(cell): return "outside"
	if absi(plan.massif.top_at(cell)-datum)>_cut_depth: return "column_cut_depth"
	if not plan.plot_support_ok(cell,datum):
		if not _share_flat_streets: return _support_refusal(plan,cell,datum)
		if datum < plan.massif.bearing_at(cell): return "below_bearing"
		if not plan.solid_at(Vector3i(cell.x,datum-1,cell.y)): return "missing_floor_support"
		if plan.excavation.flight_cells().has(Vector3i(cell.x,datum,cell.y)): return "flight"
		if not streets.has(cell) or not (streets[cell] as Array).has(datum): return "unaddressed_air"
	if not WarrenPlotReservations._no_street_left_hanging(streets,cell,datum,datum): return "upper_street_bearing"
	return ""


func _support_refusal(plan: WarrenMazeSourcePlan, cell: Vector2i, datum: int) -> String:
	if datum < plan.massif.bearing_at(cell): return "below_bearing"
	if not plan.solid_at(Vector3i(cell.x,datum-1,cell.y)): return "missing_floor_support"
	if plan.first_carved_band(cell,datum,datum+WarrenMazeSourcePlan.MIN_HOUSE_BANDS)>=0:
		return "carved_headroom"
	return "support_rule"


func _minimum_ring(plan: WarrenMazeSourcePlan, cells: Array[Vector2i]) -> int:
	var depth := 1 << 20
	for cell: Vector2i in cells: depth = mini(depth,plan.massif.ring_depth(cell))
	return depth
