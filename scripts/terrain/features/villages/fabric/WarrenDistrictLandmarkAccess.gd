extends RefCounted
## Plan a native tower-house address together with a district's first street.
## Trial streets are local copies; publish only a complete, realizable pair.
const COPY_FIELDS := ["route", "transitions", "lanes", "loop_edges", "carved",
	"covered", "portals", "bridge_spans", "bridge_span_audit", "frontage_reservations",
	"tunnel_cells", "bridge_bearing_columns", "construction_reservations", "bridge_directions"]

static func propose(massif: WarrenMassif, excavation: WarrenExcavation,
		profile: WarrenVillageScaleProfile, district: Array, public: Dictionary,
		walk_nodes: Dictionary, protected_columns: Dictionary = {}, shortest_connection := false) -> Dictionary:
	if profile.landmark_range.x < 1: return {}
	if not WarrenPlotReservations._prefers_corner_turret(excavation.world_seed, {}): return {}
	for lane: Dictionary in excavation.lanes:
		if lane.has("landmark_site"): return {}
	var plan := snapshot(massif, excavation, profile)
	var blocked := WarrenPlotPlanner.blocked_columns(plan)
	blocked.merge(protected_columns, true)
	for column: Vector2i in massif.columns:
		if massif.columns[column].has("house_site"): blocked[column] = true
	var district_columns := {}
	for cell: Vector3i in district: district_columns[Vector2i(cell.x,cell.z)] = true
	var anchors: Array[Vector2i] = []
	anchors.assign(district_columns.keys())
	anchors.sort_custom(Callable(WarrenPlotPlanner,"column_less"))
	var best := {}
	for template: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		if not template.get("corner_turret",false): continue
		for flip in [false,true]:
			for anchor: Vector2i in anchors:
				var cells := WarrenPlotReservations._footprint(plan,anchor,
					template.depth if flip else template.width,
					template.width if flip else template.depth,blocked)
				if cells.is_empty(): continue
				var datum := massif.base_at(anchor)
				var top := datum + int(template.height_bands)
				var fits := true
				for cell: Vector2i in cells:
					if massif.bearing_at(cell)!=datum or massif.base_at(cell)!=datum \
						or top>WarrenTownPlatform.huddle_top(massif,cell) \
						or not plan.plot_support_ok(cell,datum) \
						or plan.first_carved_band(cell,datum,top)>=0:
						fits=false; break
				if not fits: continue
				var trial := copy_excavation(excavation)
				# The path must address the footprint, never cross through it.
				for cell: Vector2i in cells:
					for band in range(datum-1,top):
						trial.construction_reservations[Vector3i(cell.x,band,cell.y)] = true
				var members := {}
				for cell: Vector2i in cells: members[cell] = true
				var doors: Array[Vector3i] = []
				for cell: Vector2i in cells:
					for step: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
						var edge := cell+step
						var door := Vector3i(edge.x,datum,edge.y)
						if members.has(edge) or not district_columns.has(edge) or doors.has(door): continue
						doors.append(door)
				for door: Vector3i in doors:
					var connection := WarrenMazeCarver._level_gate_connection(massif,trial,public,walk_nodes,door,true)
					if connection.is_empty(): continue
					# Longer approaches cannot beat the current valid shortest address.
					if shortest_connection and not best.is_empty() and connection.cells.size() > best.connection.cells.size(): continue
					var joined := copy_excavation(trial)
					append_connection(joined,connection)
					var joined_plan := snapshot(massif,joined,profile)
					var street_bands := WarrenPlotPlanner.street_bands(joined_plan)
					var realisation := {}
					if not WarrenPlotReservations._site_realises(joined_plan,street_bands,
						template,cells,door,datum,{},blocked,realisation,
						WarrenPlotReservations.door_access_for(joined_plan)): continue
					var taken := members.duplicate()
					for column: Vector2i in realisation.get("reserved_columns",[]): taken[column]=true
					for column: Vector2i in realisation.get("support_columns",[]): taken[column]=true
					var companions := {}
					for street: Vector3i in joined.public_cells():
						if street.y != datum: continue
						for step: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
							var column := Vector2i(street.x,street.z)+step
							if not district_columns.has(column) or taken.has(column) or blocked.has(column): continue
							var near := false
							for member: Vector2i in cells:
								var delta := (column-member).abs()
								if delta.x+delta.y<=2: near=true; break
							if near and joined_plan.plot_support_ok(column,datum): companions[column]=true
					if companions.size() < WarrenPlotReservations.RAISED_COMPANION_COLUMNS: continue
					if not best.is_empty():
						if shortest_connection:
							if connection.cells.size() > best.connection.cells.size() or (connection.cells.size() == best.connection.cells.size() and companions.size() <= best.companions.size()): continue
						elif companions.size() < best.companions.size() or (companions.size() == best.companions.size() and connection.cells.size() >= best.connection.cells.size()): continue
					best = {"connection":connection,"plot":{"cells":cells,"floor":datum,
						"top":top,"kind_id":template.kind_id,"door":door},"realisation":realisation,
						"companions":companions}
	return best

static func copy_excavation(source: WarrenExcavation) -> WarrenExcavation:
	var result := WarrenExcavation.new(source.world_seed)
	for field: String in COPY_FIELDS: result.set(field,source.get(field).duplicate(true))
	return result

static func append_connection(excavation: WarrenExcavation, connection: Dictionary) -> void:
	var transitions: Array[Dictionary] = []
	var previous: Vector3i = connection.anchor
	for cell: Vector3i in connection.cells:
		transitions.append({"from":previous,"to":cell,"kind":WarrenVolumeTransition.Kind.LEVEL})
		for band in range(cell.y,cell.y+WarrenPassageLatticeRules.HEADROOM_BANDS):
			excavation.carved[Vector3i(cell.x,band,cell.z)] = true
		previous=cell
	excavation.lanes.append({"anchor":connection.anchor,"cells":connection.cells,
		"transitions":transitions,"feature_kind":&"district_access"})

static func snapshot(massif: WarrenMassif, excavation: WarrenExcavation,
		profile: WarrenVillageScaleProfile) -> WarrenMazeSourcePlan:
	var streets := copy_excavation(excavation)
	WarrenMazeCarver._finalize_excavation(massif,streets)
	streets.finish_construction()
	var plan := WarrenMazeSourcePlan.new(excavation.world_seed,profile,massif,streets)
	for cell: Vector3i in streets.route: plan.mark_passage(cell,WarrenMazeSourcePlan.PASSAGE_SPINE)
	for cell: Vector3i in streets.lane_cells(): plan.mark_passage(cell,WarrenMazeSourcePlan.PASSAGE_ALLEY)
	return plan
