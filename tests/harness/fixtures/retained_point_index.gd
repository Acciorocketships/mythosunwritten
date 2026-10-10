# Frozen pre-change region builder for the retained-memory comparison.
# Arithmetic remains covered independently by test_water_plan.
extends WaterPlan
func _region_for(rc: Vector2i) -> Dictionary:
	var cached: Variant = _cache_get(_region_cache, rc)
	if not (cached is StringName and cached == _MISSING):
		return cached
	var region_rect: Rect2 = Rect2(
		Vector2(float(rc.x), float(rc.y)) * SUPER, Vector2(SUPER, SUPER)).grow(BANK_FEATHER + W_MAX)
	var rivers: Array = []
	var buckets: Dictionary = {}
	# carve_at chooses exactly one half-open super-cell owner (of the point's
	# 24 m cell) before querying this index. Keep complete river records for discovery, but
	# index only the terrain cells this owner can ever be asked to carve.
	var first_cell := rc * int(SUPER / TILE)
	var last_cell := first_cell + Vector2i.ONE * (int(SUPER / TILE) - 1)
	# +1 ring: a source within REACH of a cell inside this super-cell can sit
	# up to REACH + SUPER·√2 from the super-cell's own corner.
	var candidate_side := (REACH_SUPERS + 1) * 2 + 1
	var candidate_total := candidate_side * candidate_side
	var candidate_done := 0
	var candidates: Array[Vector2i] = []
	for dz in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
		for dx in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
			candidates.append(rc + Vector2i(dx, dz))
	prefetch_sources(candidates)
	_planning_progress_last = -1.0
	_report_planning_progress(0.0, true)
	for dz in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
		for dx in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
			var candidate_start := float(candidate_done) / float(candidate_total)
			candidate_done += 1
			var candidate_end := float(candidate_done) / float(candidate_total)
			var sc := rc + Vector2i(dx, dz)
			# Junctions only shorten this immutable route. Reject its raw bounds
			# before expanding neighbour dependencies for a distant source.
			var raw := river_for(sc, 0)
			if raw == null or not _bounds_for(raw).grow(BANK_FEATHER).intersects(region_rect):
				_report_planning_progress(candidate_end)
				continue
			var t: RiverTrace = river_for(sc, JOIN_DEPTH, candidate_start, candidate_end)
			if not _bounds_for(t).grow(BANK_FEATHER).intersects(region_rect):
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
	# Flat pond index (source pools + terminal ponds) so carve_at can
	# distance-gate without re-walking every river per cell.
	var ponds: Array = []
	for t in rivers:
		if t.source_pool != null:
			ponds.append(t.source_pool)
		if t.pond != null:
			ponds.append(t.pond)
	var out: Dictionary = {"rivers": rivers, "buckets": buckets, "ponds": ponds,
		"segments": segment_index(buckets)}
	_cache_put(_region_cache, rc, out, CARVE_REGION_CACHE_LIMIT)
	_report_planning_progress(1.0, true)
	return out


## Signed radial clearance from the guarded river/pond source footprint.
## Negative is inside. This is the cheap planning approximation; it never
## builds the hydrostatic fill or a shoreline contour.