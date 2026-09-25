extends "res://scripts/terrain/water/WaterPlan.gd"
## Detached native adapter. Never loaded by production. Rejected routes make
## the entire study invalid; the harness must stop before publishing a capture.
const STUDY = preload("res://tests/fixtures/september19/hillside-reach-corpus/terminal_reach_study.gd")
const STUDY_RADIUS := MAX_STEPS * TRACE_STEP + POND_R_MAX * (1.0+PondStamp.WOBBLE) + ALLUVIAL_HALF_WIDTH + BANK_FEATHER
const STUDY_REACH_SUPERS := int(ceil((ASCEND_MAX_STEPS*ASCEND_STEP+STUDY_RADIUS)/SUPER))
var rejected_routes: Dictionary = {}
var route_audits: Dictionary = {}
var _study: RefCounted

func _make_study() -> RefCounted:
	return STUDY.new(self)

func _study_radius() -> float:
	return STUDY_RADIUS

func _study_halo() -> int:
	return int(ceil((ASCEND_MAX_STEPS*ASCEND_STEP+_study_radius())/SUPER))

func _joined_trace(sc: Vector2i, _depth: int, _progress_start: float, _progress_end: float) -> RiverTrace:
	if _study == null: _study = _make_study()
	var route: Dictionary = _study.route(sc)
	var audit: Dictionary = route.duplicate()
	audit.erase("nodes")
	audit["stations"] = route.nodes.size()
	route_audits[str(sc)] = audit
	if route.termination != "native_terminal":
		rejected_routes[str(sc)] = route
		push_error("REACH_STUDY_REJECTED "+str(sc)+" "+route.termination)
		return null
	var raw := river_for(sc,0)
	var trace := RiverTrace.new()
	trace.source_cell = sc
	trace.priority = raw.priority
	trace.source_pool = raw.source_pool
	var retained: Dictionary = {}
	for node: Dictionary in route.nodes:
		var owner := _owner(node.owner)
		var original := river_for(owner,0)
		var station := int(node.station)
		trace.points.append(original.points[station])
		trace.beds.append(original.beds[station])
		trace.widths.append(original.widths[station])
		if not retained.has(owner): retained[owner] = {}
		retained[owner][station] = trace.points.size()-1
	trace.pond = river_for(_owner(route.terminal_owner),0).pond
	# A native depositional bar keeps its original geometry only when all
	# adjacent raw channel segments remain supplied by this composed route.
	var omitted_bars := 0
	for owner: Vector2i in retained:
		var original := river_for(owner,0)
		for bar: Dictionary in original.land_bars:
			var radius: float = maxf(bar.half_length,bar.half_width)+ALLUVIAL_HALF_WIDTH+TRACE_STEP
			var complete := true
			for station in original.points.size():
				if original.points[station].distance_to(bar.center)<=radius and not retained[owner].has(station):
					complete=false
					break
			if complete:
				var copy: Dictionary = bar.duplicate()
				copy.last_station = int(retained[owner].get(int(bar.last_station),trace.points.size()-1))
				trace.land_bars.append(copy)
			else: omitted_bars+=1
	audit["omitted_partial_bars"] = omitted_bars
	return trace

func _owner(value: String) -> Vector2i:
	var parts := value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector2i(int(parts[0]),int(parts[1]))

func _region_for(rc: Vector2i) -> Dictionary:
	if _region_cache.has(rc):
		return _region_cache[rc]
	var study_radius := _study_radius()
	var study_halo := _study_halo()
	var region_rect: Rect2 = Rect2(
		Vector2(float(rc.x), float(rc.y)) * SUPER, Vector2(SUPER, SUPER)).grow(BANK_FEATHER + W_MAX)
	var rivers: Array = []
	var buckets: Dictionary = {}
	# carve_at_cell chooses exactly one half-open super-cell owner before
	# querying this index. Keep complete river records for discovery, but
	# index only the terrain cells this owner can ever be asked to carve.
	var first_cell := rc * int(SUPER / TILE)
	var last_cell := first_cell + Vector2i.ONE * (int(SUPER / TILE) - 1)
	# +1 ring: a source within REACH of a cell inside this super-cell can sit
	# up to REACH + SUPER·√2 from the super-cell's own corner.
	var candidate_side := (study_halo + 1) * 2 + 1
	var candidate_total := candidate_side * candidate_side
	var candidate_done := 0
	_planning_progress_last = -1.0
	_report_planning_progress(0.0, true)
	for dz in range(-(study_halo + 1), study_halo + 2):
		for dx in range(-(study_halo + 1), study_halo + 2):
			var candidate_start := float(candidate_done) / float(candidate_total)
			candidate_done += 1
			var candidate_end := float(candidate_done) / float(candidate_total)
			var sc := rc + Vector2i(dx, dz)
			# Composed routes may leave raw bounds. The source-centred arc
			# envelope includes all possible stations and terminal pond influence.
			var raw := river_for(sc, 0)
			if raw == null or not Rect2(raw.points[0]-Vector2.ONE*study_radius,Vector2.ONE*study_radius*2).intersects(region_rect):
				_report_planning_progress(candidate_end)
				continue
			var t: RiverTrace = river_for(sc, JOIN_DEPTH, candidate_start, candidate_end)
			if t == null or not _bounds_for(t).grow(BANK_FEATHER).intersects(region_rect):
				continue
			rivers.append(t)
			for i in t.points.size():
				var infl: float = t.widths[i] + BANK_FEATHER
				var lo_x := maxi(first_cell.x, floori((t.points[i].x - infl) / TILE + 0.5))
				var hi_x := mini(last_cell.x, floori((t.points[i].x + infl) / TILE + 0.5))
				var lo_z := maxi(first_cell.y, floori((t.points[i].y - infl) / TILE + 0.5))
				var hi_z := mini(last_cell.y, floori((t.points[i].y + infl) / TILE + 0.5))
				for bz in range(lo_z, hi_z + 1):
					for bx in range(lo_x, hi_x + 1):
						var key: Vector2i = Vector2i(bx, bz)
						if not buckets.has(key):
							buckets[key] = []
						buckets[key].append([t, i])
	# Flat pond index (source pools + terminal ponds) so carve_at_cell can
	# distance-gate without re-walking every river per cell.
	var ponds: Array = []
	for t in rivers:
		if t.source_pool != null:
			ponds.append(t.source_pool)
		if t.pond != null:
			ponds.append(t.pond)
	var out: Dictionary = {"rivers": rivers, "buckets": buckets, "ponds": ponds}
	_memo_insert(_region_cache, rc, out, CARVE_REGION_CACHE_LIMIT)
	_report_planning_progress(1.0, true)
	return out
