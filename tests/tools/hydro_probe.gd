# Phase 0 hydrology diagnostics: fix-independent evidence for H1-H6
# (.superpowers/sdd/h-task-0-brief.md). Prints four evidence sections
# (A profile-vs-terrain, B claimant dump, C lip-coverage, D volume
# containment) against the pinned seed at the owner's exact issue sites.
# This tool DOCUMENTS current WaterField/WaterMesher/WaterSurfaceBuilder
# behaviour — it must not "fix" anything it observes.
# Run: Godot --headless --path . -s tests/tools/hydro_probe.gd
extends SceneTree

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

var _region  # HeightfieldRegion for SITE_CHUNK, built once in _init


func _init() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	_region = plan.compute_region(SITE_CHUNK.x * 8 + 4, SITE_CHUNK.y * 8 + 4, 8)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, _region)

	print("=== HYDRO PROBE seed=%d site_chunk=%s ===" % [SEED, SITE_CHUNK])
	_probe_a(ctx)
	_probe_b(ctx)
	_probe_c(water)
	_probe_d(water)
	print("=== HYDRO PROBE done ===")
	quit()


## ---------------------------------------------------------------------
## A: profile-vs-terrain dump along the trace through (57.7, -1082.5).
## H1 evidence: bed window-drop > 4m where surface_y never drops > 4m in
## any 24m (2-sample) window.
## ---------------------------------------------------------------------
func _probe_a(ctx: Dictionary) -> void:
	print("\n--- PROBE A: profile-vs-terrain (H1) ---")
	var target := Vector2(57.7, -1082.5)
	var tr: RiverTrace = _nearest_trace(ctx, target)
	if tr == null:
		print("H1: NO TRACE FOUND near %s" % target)
		return
	print("H1: trace=%s samples=%d (nearest to target: dist=%.2f)" % [
		tr.source_cell, tr.points.size(), tr.points[_nearest_index(tr, target)].distance_to(target)])
	var prof: Dictionary = WaterField.profile(tr)
	print("H1: per-sample bed/level/surface_y —")
	for i in tr.points.size():
		var p: Vector2 = tr.points[i]
		var sy: float = TerrainSurfaceField.surface_y(_region, p.x, p.y)
		print("H1:  i=%d p=(%.1f,%.1f) bed=%.2f level=%.2f surface_y=%.2f cut=%s" % [
			i, p.x, p.y, tr.beds[i], prof.levels[i], sy, prof.cuts.has(i)])
	print("H1: 24m-window drops (sample i vs i+2; ~12m spacing x2) —")
	var max_bed_drop := -INF
	var max_bed_drop_i := -1
	var max_surface_drop_in_that_window := -INF
	for i in range(0, tr.points.size() - 2):
		var p0: Vector2 = tr.points[i]
		var p2: Vector2 = tr.points[i + 2]
		var s0: float = TerrainSurfaceField.surface_y(_region, p0.x, p0.y)
		var s2: float = TerrainSurfaceField.surface_y(_region, p2.x, p2.y)
		var bed_drop: float = tr.beds[i] - tr.beds[i + 2]
		var surf_drop: float = s0 - s2
		print("H1:  i=%d bed_drop=%.2f surface_drop=%.2f" % [i, bed_drop, surf_drop])
		if bed_drop > max_bed_drop:
			max_bed_drop = bed_drop
			max_bed_drop_i = i
			max_surface_drop_in_that_window = surf_drop
	print("H1: MAX bed window-drop=%.2f at i=%d, surface window-drop THERE=%.2f (surface max-in-window computed at same i)" % [
		max_bed_drop, max_bed_drop_i, max_surface_drop_in_that_window])
	var surf_max := -INF
	for i in range(0, tr.points.size() - 2):
		var p0: Vector2 = tr.points[i]
		var p2: Vector2 = tr.points[i + 2]
		var s0: float = TerrainSurfaceField.surface_y(_region, p0.x, p0.y)
		var s2: float = TerrainSurfaceField.surface_y(_region, p2.x, p2.y)
		surf_max = maxf(surf_max, s0 - s2)
	print("H1: MAX surface_y window-drop over ALL windows on this trace=%.2f" % surf_max)
	print("H1: PREDICTION CHECK: bed window-drop > 4.0 AND surface never drops > 4.0 in any window => %s" % [
		str(max_bed_drop > 4.0 and surf_max <= 4.0 + 0.02)])


## ---------------------------------------------------------------------
## B: claimant dump on a 1m grid over each owner rectangle.
## H2/H3/H4 evidence: wrong-sample claims, -INF holes with low ground,
## dual-claim gaps.
## ---------------------------------------------------------------------
func _probe_b(ctx: Dictionary) -> void:
	print("\n--- PROBE B: claimant dump (H2/H3/H4) ---")
	_probe_b_i2(ctx)
	_probe_b_i3(ctx)
	_probe_b_i4(ctx)


## I2: (58..84, -1152..-1128). H2 — the claimant at the player's exact spot
## vs. the hydraulically NEAREST channel sample; then the straight claim-
## radius boundary (not a terrain contour) along the player's z line.
func _probe_b_i2(ctx: Dictionary) -> void:
	var target := Vector2(70.1, -1140.5)
	print("H2: I2 rectangle (58..84, -1152..-1128), player=%s" % target)
	var info: Dictionary = _claim_info(ctx, target)
	print("H2: claim AT PLAYER: kind=%s id=%s si=%d level=%.2f margin=%.2f ground=%.2f wet=%s" % [
		info.kind, info.id, info.si, info.lvl, info.m,
		TerrainSurfaceField.surface_y(_region, target.x, target.y),
		str(info.lvl > TerrainSurfaceField.surface_y(_region, target.x, target.y) + 0.05)])
	var tr: RiverTrace = null
	for t: RiverTrace in ctx.rivers:
		if str(t.source_cell) == info.id:
			tr = t
			break
	if tr != null:
		var near_i: int = _nearest_index(tr, target)
		var prof: Dictionary = WaterField.profile(tr)
		var near_d: float = tr.points[near_i].distance_to(target)
		print("H2: hydraulically NEAREST channel sample on the SAME trace: si=%d pt=%s dist=%.2f level=%.2f" % [
			near_i, tr.points[near_i], near_d, prof.levels[near_i]])
		print("H2: PREDICTION CHECK: claimant si(%d)!=nearest si(%d) AND claimant level(%.2f) > nearest-sample level(%.2f) => %s" % [
			info.si, near_i, info.lvl, prof.levels[near_i],
			str(info.si != near_i and info.lvl > prof.levels[near_i] + 0.01)])
	print("H2: boundary walk along z=-1140.5, x=60..86 (claim-radius cut vs terrain contour) —")
	var prev_key := ""
	for xi100 in range(6000, 8600, 20):
		var xi: float = float(xi100) / 100.0
		var p := Vector2(xi, -1140.5)
		var info2: Dictionary = _claim_info(ctx, p)
		var key: String = "%s:%s:%d" % [info2.kind, info2.id, info2.si]
		if key != prev_key:
			print("H2:  x=%.2f claim-change kind=%s id=%s si=%d level=%.2f margin=%.2f" % [
				xi, info2.kind, info2.id, info2.si, info2.lvl, info2.m])
			prev_key = key


## I3: (0..24, -1132..-1108). H3 — level_at returns -INF while ground sits
## well below the surrounding claimed level (a dry hole inside a lake).
func _probe_b_i3(ctx: Dictionary) -> void:
	var target := Vector2(9.3, -1120.6)
	print("H3: I3 rectangle (0..24, -1132..-1108), player=%s" % target)
	var lvl: float = WaterField.level_at(ctx, target)
	var g: float = TerrainSurfaceField.surface_y(_region, target.x, target.y)
	print("H3: AT PLAYER: level_at=%s ground=%.2f" % [
		"-INF" if lvl == -INF else "%.2f" % lvl, g])
	# Neighbouring wet level for context (nearest claimed sample within 8m).
	var best_lvl := -INF
	var best_d := INF
	for dz100 in range(-800, 801, 100):
		for dx100 in range(-800, 801, 100):
			var p: Vector2 = target + Vector2(float(dx100) / 100.0, float(dz100) / 100.0)
			var l2: float = WaterField.level_at(ctx, p)
			if l2 > -INF:
				var d: float = p.distance_to(target)
				if d < best_d:
					best_d = d
					best_lvl = l2
	print("H3: nearest claimed level within 8m = %.2f at dist=%.2f" % [best_lvl, best_d])
	print("H3: PREDICTION CHECK: level_at==-INF AND ground(%.2f) is ~%.2fm below surrounding level(%.2f) => %s" % [
		g, best_lvl - g, best_lvl, str(lvl == -INF and best_lvl - g > 1.0)])
	print("H3: coarse wet/dry map around I3 (W=wet, .=claimed-dry, x=unclaimed) —")
	for zi in range(-1128, -1112, 2):
		var row := ""
		for xi in range(0, 22, 2):
			var p := Vector2(float(xi), float(zi))
			var l2: float = WaterField.level_at(ctx, p)
			var g2: float = TerrainSurfaceField.surface_y(_region, p.x, p.y)
			if l2 == -INF:
				row += "x"
			elif l2 > g2 + 0.05:
				row += "W"
			else:
				row += "."
		print("H3:  z=%d: %s" % [zi, row])


## I4: (24..48, -1120..-1096). H4 — two claimants with different levels
## bracket a -INF gap (junction-continuity: tributary never pinned to the
## main stem).
func _probe_b_i4(ctx: Dictionary) -> void:
	var target := Vector2(36.4, -1108.7)
	print("H4: I4 rectangle (24..48, -1120..-1096), player=%s" % target)
	var lvl: float = WaterField.level_at(ctx, target)
	print("H4: AT PLAYER: level_at=%s ground=%.2f" % [
		"-INF" if lvl == -INF else "%.2f" % lvl,
		TerrainSurfaceField.surface_y(_region, target.x, target.y)])
	print("H4: fine claimant dump (32..40 x, -1110..-1104 z), 1m grid —")
	var claimants_seen: Dictionary = {}
	var gap_found := false
	for zi in range(-1110, -1103):
		for xi in range(32, 41):
			var p := Vector2(float(xi), float(zi))
			var info: Dictionary = _claim_info(ctx, p)
			var g: float = TerrainSurfaceField.surface_y(_region, p.x, p.y)
			print("H4:  (%d,%d) ground=%.2f claim=%s id=%s si=%d level=%s" % [
				xi, zi, g, info.kind, info.id, info.si,
				"-INF" if info.lvl == -INF else "%.2f" % info.lvl])
			if info.kind != "none":
				claimants_seen["%s:%s:%d:%.2f" % [info.kind, info.id, info.si, info.lvl]] = true
			else:
				gap_found = true
	print("H4: distinct claimant/level combos seen in this window: %d" % claimants_seen.size())
	for k in claimants_seen:
		print("H4:   %s" % k)
	print("H4: PREDICTION CHECK: >=2 distinct claimant levels AND an unclaimed (-INF) gap present in the window => %s" % [
		str(claimants_seen.size() >= 2 and gap_found)])


## ---------------------------------------------------------------------
## C: lip-coverage check per cut record — distance from each lip end to
## the nearest upstream boundary-contour vertex ON THE CUT LINE.
## H5 evidence.
## ---------------------------------------------------------------------
func _probe_c(water: WaterPlan) -> void:
	print("\n--- PROBE C: lip-coverage (H5) ---")
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, _region)
	if m.is_empty():
		print("H5: chunk is dry, no mesh built")
		return
	var verts: PackedVector3Array = m.verts
	var idx: PackedInt32Array = m.idx
	var hem_start: int = m.hem_start
	# Free edges among non-hem (sheet/cut) triangles only — hem faces are
	# deliberate buried folds, not waterline contour.
	var idx_nohem := PackedInt32Array()
	for i in hem_start:
		idx_nohem.append(idx[i])
	var fe: Array = WaterMesher.free_edges(verts, idx_nohem)
	print("H5: cut records=%d, free edges (non-hem)=%d" % [m.cuts.size(), fe.size()])
	for reci in m.cuts.size():
		var rec: Dictionary = m.cuts[reci]
		var cut: Dictionary = rec.cut
		var lip: PackedVector3Array = rec.lip
		print("H5: cut %d p=%s dir=%s half=%.2f top=%.2f bottom=%.2f lip_verts=%d base_verts=%d" % [
			reci, cut.p, cut.dir, cut.half, cut.top, cut.bottom, lip.size(), rec.base.size()])
		if lip.is_empty():
			print("H5:  NO LIP VERTS registered for this cut")
			continue
		for end_label in ["end0", "end1"]:
			var ep: Vector3 = lip[0] if end_label == "end0" else lip[lip.size() - 1]
			var ep_across: float = (Vector2(ep.x, ep.z) - cut.p).dot(cut.across)
			# Nearest free-edge vertex AT THE LIP'S OWN LEVEL, further out
			# along `across` than this end (i.e. the contour continuing past
			# where the recorded lip stopped) — this is the "gap" H5 predicts.
			var best_d := INF
			var best_v: Vector3 = Vector3.ZERO
			var found := false
			for edge in fe:
				for v: Vector3 in edge:
					if absf(v.y - cut.top) > 0.5:
						continue
					if v.distance_to(ep) < 0.01:
						continue
					var v_across: float = (Vector2(v.x, v.z) - cut.p).dot(cut.across)
					var beyond: bool = v_across > ep_across if end_label == "end1" else v_across < ep_across
					if not beyond:
						continue
					var d: float = v.distance_to(ep)
					if d < best_d:
						best_d = d
						best_v = v
						found = true
			if found:
				print("H5:  %s=%s (across=%.2f) -> next contour vert BEYOND it=%s dist=%.2f (S=%.1f, ratio=%.2f)" % [
					end_label, ep, ep_across, best_v, best_d, WaterMesher.S, best_d / WaterMesher.S])
				print("H5:  PREDICTION CHECK (%s): gap > 1 lattice step (S=%.1f) => %s" % [
					end_label, WaterMesher.S, str(best_d > WaterMesher.S)])
			else:
				print("H5:  %s=%s -> no further contour vertex found beyond it (lip reaches the true edge)" % [end_label, ep])


## ---------------------------------------------------------------------
## D: volume containment math at the two player positions via build_chunk
## output — the SAME math character.gd._update_in_water uses
## (characters/character.gd lines 187-216):
##   probe_y = global_position.y + 0.3
##   sy = c.y + g.dot(Vector2(gp.x - c.x, gp.z - c.z))
##   in-water gate: probe_y <= sy + swell + 0.45  (swell=0: static field probe)
##   best = maxf over every containing volume that passes the gate
## H6 evidence.
## ---------------------------------------------------------------------
func _probe_d(water: WaterPlan) -> void:
	print("\n--- PROBE D: volume containment (H6) ---")
	var builder := WaterSurfaceBuilder.new()
	var node: Node3D = builder.build_chunk(water, SITE_CHUNK, _region)
	if node == null:
		print("H6: build_chunk returned null (dry chunk)")
		return
	var areas: Array = []
	for child in node.get_children():
		if child is Area3D:
			areas.append(child)
	print("H6: Area3D swim-volume count in chunk %s: %d" % [SITE_CHUNK, areas.size()])

	var cases := [
		{"label": "I2", "pos": Vector3(70.1, 4.0, -1140.5), "expect_post_fix": true},
		{"label": "I5", "pos": Vector3(33.9, 10.8, -1099.0), "expect_post_fix": false},
	]
	for case: Dictionary in cases:
		var label: String = case.label
		var gp: Vector3 = case.pos
		var probe_y: float = gp.y + 0.3   # character.gd line 189
		var probe_pos: Vector3 = gp + Vector3(0.0, 0.3, 0.0)   # line 190
		var best: float = -INF
		var hit_count := 0
		for area: Area3D in areas:
			var box: BoxShape3D = area.get_child(0).shape
			var half: Vector3 = box.size * 0.5
			var apos: Vector3 = area.position
			var lo: Vector3 = apos - half
			var hi: Vector3 = apos + half
			var contains: bool = probe_pos.x >= lo.x and probe_pos.x <= hi.x \
				and probe_pos.y >= lo.y and probe_pos.y <= hi.y \
				and probe_pos.z >= lo.z and probe_pos.z <= hi.z
			if not contains:
				continue
			hit_count += 1
			var c: Vector3 = area.get_meta("surface_c")
			var g: Vector2 = area.get_meta("surface_g")
			var sy: float = c.y + g.dot(Vector2(gp.x - c.x, gp.z - c.z))   # line 205
			var gate: bool = probe_y <= sy + 0.45   # line 206 (swell=0 for a static probe)
			print("H6:  %s HIT volume c=%s g=%s box=[%s..%s] sy=%.2f gate(probe_y=%.2f<=sy+0.45=%.2f)=%s" % [
				label, c, g, lo, hi, sy, probe_y, sy + 0.45, gate])
			if gate:
				best = maxf(best, sy)
		var in_water: bool = best > -INF
		print("H6: %s pos=%s contains=%d in_water=%s (expect_post_fix=%s) surface=%s" % [
			label, gp, hit_count, in_water, case.expect_post_fix,
			"-INF" if best == -INF else "%.2f" % best])
		print("H6: PREDICTION CHECK (%s): current in_water(%s) contradicts post-fix expectation(%s) => currently BROKEN=%s" % [
			label, in_water, case.expect_post_fix, str(in_water != case.expect_post_fix)])
	# build_chunk allocates real RenderingServer/PhysicsServer resources
	# (MeshInstance3D meshes, Area3D/CollisionShape3D bodies); this node was
	# never parented into the tree, so free it explicitly or the engine
	# reports leaked RIDs at exit.
	node.free()


## ---------------------------------------------------------------------
## Shared claimant helper: re-derives WHICH claimant level_at picked
## (level_at itself only returns the winning level, not its identity) by
## running the identical selection logic against WaterField's own
## constants. Kept in lockstep with WaterField.level_at's structure —
## any change there must be mirrored here.
## ---------------------------------------------------------------------
func _claim_info(c: Dictionary, p: Vector2) -> Dictionary:
	var best_m: float = INF
	var best_lvl: float = -INF
	var best_kind := "none"
	var best_id := ""
	var best_si := -1
	var gy: float = INF
	var have_gy := false
	var region = c.get("region")
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m >= best_m:
			continue
		var ok: bool = m < WaterField.CLAIM_FEATHER
		var lvl: float = pond.surface_y()
		if not ok and region != null and m <= WaterField.CLAIM_FEATHER + WaterField.FLOOD_EXT:
			if not have_gy:
				gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
				have_gy = true
			ok = gy < lvl - WaterField.EPS and gy > lvl - WaterField.FLOOD_DEPTH_MAX
		if ok:
			best_m = m
			best_lvl = lvl
			best_kind = "pond"
			best_id = str(pond.center)
			best_si = -1
	var cell := Vector2i(int(floor(p.x / WaterField.TILE)), int(floor(p.y / WaterField.TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = c.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var tr: RiverTrace = c.rivers[ref.x]
				var si: int = ref.y
				var d: float = p.distance_to(tr.points[si])
				var m: float = d - tr.widths[si]
				if m >= best_m:
					continue
				var ok: bool = m < WaterField.CLAIM_FEATHER
				if not ok and (region == null or m > WaterField.CLAIM_FEATHER + WaterField.FLOOD_EXT):
					continue
				var lvl: float = WaterField._sample_level(tr, si, p)
				if not ok:
					if not have_gy:
						gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
						have_gy = true
					ok = gy < lvl - WaterField.EPS and gy > lvl - WaterField.FLOOD_DEPTH_MAX
				if ok:
					best_m = m
					best_lvl = lvl
					best_kind = "river"
					best_id = str(tr.source_cell)
					best_si = si
	return {"kind": best_kind, "id": best_id, "si": best_si, "lvl": best_lvl, "m": best_m}


func _nearest_index(tr: RiverTrace, target: Vector2) -> int:
	var best_d := INF
	var best_i := -1
	for i in tr.points.size():
		var d: float = tr.points[i].distance_to(target)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _nearest_trace(ctx: Dictionary, target: Vector2) -> RiverTrace:
	var best_tr: RiverTrace = null
	var best_d := INF
	for tr: RiverTrace in ctx.rivers:
		var i: int = _nearest_index(tr, target)
		if i < 0:
			continue
		var d: float = tr.points[i].distance_to(target)
		if d < best_d:
			best_d = d
			best_tr = tr
	return best_tr
