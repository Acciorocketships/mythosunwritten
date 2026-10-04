extends GutTest

## Water on the dual-grid terrain (docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md):
## ground heights live on 12 m lattice points, walls stand on the dual-cell
## borders x = 12 i + 6, and every water consumer reads that ground through
## TerrainTileField. These tests pin the water/terrain contract.

const Tile := preload("res://scripts/terrain/field/TerrainTileField.gd")
const SEED := 991177


## Synthetic terrain with cliffs, one-storey slopes and level steps in every
## direction, including negative coordinates.
func _plan() -> HeightfieldPlan:
	var plan := HeightfieldPlan.new(4242, 40.0, 8, "mean", 3)
	plan.set_raw_height_override(func(i: int, j: int) -> float:
		return float(posmod(i * 7 + j * 13, 5)) * 4.0 + float(posmod(i * 3 + j, 4)) + 0.4)
	return plan


func test_ground_lattice_matches_the_tile_kernel_at_every_sample() -> void:
	var plan := _plan()
	var region := plan.compute_rect_region(Rect2i(-12, -12, 25, 25))
	# 6 m samples starting on a wall line (x = -66 = 12 * -6 + 6): every other
	# column and row sits exactly on a dual-cell border, where the owner is
	# decided by TerrainTileField.point_of, not by rounding half away from zero.
	var base := Vector2(-66.0, -54.0)
	var side := 20
	var rows := 19
	var ground := WaterField._sample_ground_lattice(region, base, side, 6.0, rows)
	var walls := 0
	for j in rows:
		for i in side:
			var p := base + Vector2(i, j) * 6.0
			var expect := Tile.surface_y(region, p.x, p.y)
			assert_almost_eq(ground[j * side + i], expect, 0.00001, "6 m sample %s" % p)
			if posmod(int(p.x) - 6, 12) == 0 and absf(Tile.surface_y_on_side(region, p.x, p.y,
					Vector2i(Tile.point_of(p.x) - 1, Tile.point_of(p.y))) - expect) > 1.0:
				walls += 1
	assert_gt(walls, 10, "the sweep crosses real walls exactly on their border")
	# The fine rescue lattice memoizes per-point bakes through _ground_at.
	var sub_side := 39
	var sub := PackedFloat32Array(); sub.resize(sub_side * sub_side); sub.fill(INF)
	var bakes := {}
	for j in sub_side:
		for i in sub_side:
			var p := base + Vector2(i, j) * 3.0
			assert_almost_eq(WaterField._ground_at(region, base, sub_side, sub, i, j, 3.0, bakes),
				Tile.surface_y(region, p.x, p.y), 0.00001, "3 m sample %s" % p)


func test_trace_owned_region_certifies_every_point_a_profile_reads() -> void:
	var plan := _plan()
	var tr := RiverTrace.new()
	tr.source_cell = Vector2i(9101, 9101)
	tr.points = PackedVector2Array([Vector2(-150.0, -40.0), Vector2(-40.0, 10.0), Vector2(90.0, 130.0)])
	tr.beds = PackedFloat32Array([10.0, 8.0, 6.0])
	tr.widths = PackedFloat32Array([20.0, 20.0, 20.0])
	WaterField._trace_regions.clear()
	var region: HeightfieldRegion = WaterField._trace_owned_region(tr, plan)
	# A surface sample at (x, z) reads the four corners of the tile under it:
	# points floor(x / 12) .. floor(x / 12) + 1.
	var need := Rect2i(Vector2i(floori(-150.0 / 12.0), floori(-40.0 / 12.0)), Vector2i.ONE)
	need = need.expand(Vector2i(floori(90.0 / 12.0) + 1, floori(130.0 / 12.0) + 1) + Vector2i.ONE)
	assert_true(region.certified_points.encloses(need),
		"certified %s must enclose the sampled points %s" % [region.certified_points, need])
	WaterField._trace_regions.clear()


func test_source_fill_control_domain_is_in_points() -> void:
	var base := Vector2(-66.0, 300.0)
	var last := base + Vector2(40, 25) * WaterField.FILL_STEP
	var domain := WaterField._point_domain(Rect2(base, last - base))
	for p: Vector2 in [base, last, Vector2(base.x, last.y), Vector2(last.x, base.y)]:
		for d: Vector2i in [Vector2i.ZERO, Vector2i.ONE]:
			var point := Vector2i(floori(p.x / 12.0), floori(p.y / 12.0)) + d
			assert_true(domain.has_point(point), "domain %s holds tile corner %s of %s" % [domain, point, p])


## Fill nodes sit off every discontinuity: at 12 i +- 3, midway between a
## lattice point and a dual-cell border, in chunk windows and source solves.
func test_fill_nodes_sit_off_walls_and_points() -> void:
	for chunk: Vector2i in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(7, -11)]:
		var base: Vector2 = Vector2(chunk) * WaterField.CHUNK \
			- Vector2.ONE * (WaterField.FILL_MARGIN * WaterField.FILL_STEP + WaterField.FILL_OFFSET)
		var water := WaterPlan.new(1, 22.0, 8)
		var c: Dictionary = WaterField.ctx(water, chunk, HeightfieldRegion.new({}, {}))
		assert_eq(c.fill_base, base, "chunk %s window origin" % chunk)
		for axis in 2:
			assert_almost_eq(fposmod(base[axis], 12.0), 3.0, 0.0001, "node phase 12 i + 3")
		# The window keeps its full margin on both sides of the chunk.
		var rect := Rect2(base, Vector2.ONE * WaterField.FILL_M * WaterField.FILL_STEP)
		assert_true(rect.encloses(Rect2(Vector2(chunk) * WaterField.CHUNK, Vector2.ONE * WaterField.CHUNK)
			.grow(WaterField.FILL_MARGIN * WaterField.FILL_STEP)), "window keeps FILL_MARGIN")


## A supplied upper pool spilling over a cliff into supplied water below stays
## wet up to the lip -- the wall on the dual border between two fill nodes --
## and falls from there: the fill is evaluated per side of the wall, toward a
## crest held on the wall at crown + DESCENT_CLAMP, with no node lifted. Every
## orientation (high side at -x, +x, -z, +z) behaves identically. The lattice
## is the offset fill lattice (nodes at 12 i +- 3), 6 x 6 nodes around a wall
## on the border at -6 * high, cliff top storey 3 (12 m) over storey 0.
func test_wet_crest_spill_reaches_the_lip_in_every_orientation() -> void:
	var lips: Array[float] = []
	for high: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var storeys := {}
		var levels_map := {}
		for j in range(-6, 7):
			for i in range(-6, 7):
				var along := i * high.x + j * high.y
				storeys[Vector2i(i, j)] = 3 if along >= 0 else 0
				levels_map[Vector2i(i, j)] = 0
		var region := HeightfieldRegion.new(storeys, levels_map)
		var base := Vector2(-15.0, -15.0)
		var n := 6
		var ground := WaterField._sample_ground_lattice(region, base, n, 6.0)
		var water := PackedFloat32Array(); water.resize(n * n)
		for k in n * n:
			water[k] = 12.5 if ground[k] >= 12.0 else 0.5
		var ctx := {"fill_base": base, "fill_size": n, "fill": {"levels": water}, "region": region}
		var wall := -Vector2(high) * 6.0
		for k in 25:
			# The high side from 3 m inside up to 1 cm before the wall.
			var p := wall + Vector2(high) * maxf(3.0 - k * 0.12, 0.01)
			var depth: float = WaterField._fill_bilinear_coarse(ctx, p) - TerrainTileField.surface_y(region, p.x, p.y)
			assert_gt(depth, WaterField.EPS, "high side %s stays wet to the lip at %s" % [high, p])
		# The fall starts at the lip: 2 m past the wall the water is already
		# below the 12 m crown (no shelf hanging in front of the cliff).
		var past := wall - Vector2(high) * 2.0
		assert_lt(WaterField._fill_bilinear_coarse(ctx, past), 12.0,
			"low side %s falls below the crown within 2 m of the wall" % high)
		lips.append(WaterField._fill_bilinear_coarse(ctx, wall - Vector2(high) * 0.01))
	for lip: float in lips:
		assert_almost_eq(lip, lips[0], 0.0001, "the lip is identical in every orientation")


## Where a cliff ends (E2: its drop tapers into a slope inside one tile) the
## water surface stays continuous: the spill/linear switch is a smooth weight
## of the drop, not a threshold. Fixture: an x-wall on x = 6 between an 8 m
## top (j <= 0) and the low side, ending into a one-storey slope for j >= 1;
## an upper pool at 8.5 spills into water at 0.5. Scanned along z at 1 mm on
## both sides of the wall and on it, across the cliff end. The E2 ramp itself
## is steep here (the drop falls from 5.9 to 2.3 m within 12 cm of z), so the
## bound is per millimetre: a threshold switch jumped 0.46 m at any step.
func test_spill_surface_is_continuous_where_the_cliff_ends() -> void:
	var storeys := {}
	var levels_map := {}
	for j in range(-6, 7):
		for i in range(-6, 7):
			storeys[Vector2i(i, j)] = (2 if j <= 0 else 1) if i <= 0 else 0
			levels_map[Vector2i(i, j)] = 0
	var region := HeightfieldRegion.new(storeys, levels_map)
	var base := Vector2(-15.0, -15.0)
	var n := 6
	var ground := WaterField._sample_ground_lattice(region, base, n, 6.0)
	var water := PackedFloat32Array(); water.resize(n * n)
	for k in n * n:
		water[k] = 8.5 if ground[k] >= 3.9 else 0.5
	var ctx := {"fill_base": base, "fill_size": n, "fill": {"levels": water}, "region": region}
	for x: float in [5.5, 6.0, 6.5, 7.5]:
		var worst := 0.0
		var at := 0.0
		var prev: float = WaterField._fill_bilinear(ctx, Vector2(x, 4.0))
		var z := 4.001
		while z <= 8.0:
			var l: float = WaterField._fill_bilinear(ctx, Vector2(x, z))
			if absf(l - prev) > worst:
				worst = absf(l - prev)
				at = z
			prev = l
			z += 0.001
		assert_lt(worst, 0.05, "no tear along z at x = %.1f (%.3f m within 1 mm at z = %.3f)" % [x, worst, at])


## The 3 m rescue lattice keeps nodes on dual borders, so a fine cell's edge
## can lie on a wall line. Where that wall dies (E2: wall from the tile centre
## on, a steep ramp before it) the terrain ON the line is the ramp's midline
## before the wall end and the wall top after it: a shore-support probe read
## there switched with the terrain owner and stepped the water mid-pool.
## Fixture (the photographed site, 2026-10-01): tile (0, 0) with corners 12
## (0,0), 8 (12,0), 16 (12,12), 12 (0,12); its right edge is a two-storey
## cliff, so the wall on z = 6 runs x 6..12 and dies into the ramp at x = 6.
## Rescue water at 11.95 on the row z = 3, dry nodes on the wall line z = 6.
## Scanned along z = 3.625 across x = 6 at 1 cm.
func test_rescue_shore_is_continuous_where_its_edge_wall_dies() -> void:
	var storeys := {}
	var levels_map := {}
	for j in range(-6, 7):
		for i in range(-6, 7):
			var h := 12
			if i >= 1:
				h = 8 if j <= 0 else 16
			storeys[Vector2i(i, j)] = h / 4
			levels_map[Vector2i(i, j)] = 0
	var region := HeightfieldRegion.new(storeys, levels_map)
	assert_almost_eq(TerrainTileField.surface_y(region, 6.0, 6.0) - TerrainTileField.surface_y(region, 6.0, 5.999),
		4.0, 0.01, "fixture: the wall on z = 6 stands from x = 6 on")
	var base := Vector2(-15.0, -15.0)
	var n := 6
	var coarse := PackedFloat32Array(); coarse.resize(n * n); coarse.fill(-INF)
	var sub_n := WaterField.FILL_SUB_M + 1
	var sub := PackedFloat32Array(); sub.resize(sub_n * sub_n); sub.fill(-INF)
	var sub_ground := PackedFloat32Array(); sub_ground.resize(sub_n * sub_n); sub_ground.fill(INF)
	for x: float in [0.0, 3.0, 6.0, 9.0, 12.0]:
		var node := Vector2i(((Vector2(x, 3.0) - base) / WaterField.FILL_SUB_STEP).round())
		sub[node.y * sub_n + node.x] = 11.95
	var ctx := {"fill_base": base, "fill_size": n, "region": region,
		"fill": {"levels": coarse, "sub_levels": sub, "sub_ground": sub_ground}}
	# The row runs x 4..9 across the wall's end at x = 6. (Since the divot fix
	# of 2026-10-04 the plateau stays level beside the dying wall, so at x 3
	# the 11.95 m water meets a real shore under the 12 m top; the row starts
	# a metre clear of it.)
	var prev: float = WaterField._fill_bilinear(ctx, Vector2(4.0, 3.625))
	var worst := 0.0
	var at := 0.0
	var dry := 0
	for k in range(1, 501):
		var p := Vector2(4.0 + k * 0.01, 3.625)
		var l: float = WaterField._fill_bilinear(ctx, p)
		if not (l > TerrainTileField.surface_y(region, p.x, p.y) + WaterField.EPS):
			dry += 1
		if absf(l - prev) > worst:
			worst = absf(l - prev)
			at = p.x
		prev = l
	assert_eq(dry, 0, "the rescued row stays wet")
	assert_lte(worst, 0.01, "no step along the rescued row (%.4f m at x = %.2f)" % [worst, at])


func test_water_code_has_no_native_cliff_piece_dependency() -> void:
	var dir := DirAccess.open("res://scripts/terrain/water")
	var offenders: Array = []
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://scripts/terrain/water/" + file)
		if text.contains("CliffDressing"):
			offenders.append(file)
	assert_eq(offenders, [], "native KayKit cliff pieces are gone from world terrain")


func test_wall_face_is_the_measured_dual_border() -> void:
	# The rock skirt stands exactly on the dual border: the level shelf reaches
	# the first high-ground sample of its column and adds no recess.
	var storeys := {}
	var levels := {}
	for j in range(-6, 7):
		for i in range(-6, 7):
			storeys[Vector2i(i, j)] = 3 if i >= 1 else 0
			levels[Vector2i(i, j)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var st := {"region": region}
	var c := {"pts": PackedVector2Array([Vector2(5.0, 0.0)]),
		"levels": PackedFloat32Array([1.0]),
		"normals": PackedVector2Array([Vector2(1.0, 0.0)]),
		"wall": PackedByteArray([1])}
	var contacts: Dictionary = WaterSkin._wall_contacts(st, c)
	assert_eq(contacts.flags[0], 1, "the wall at x = 6 is confirmed")
	assert_almost_eq(contacts.face_reach[0], 1.0, WaterSkin.WALL_CONTACT_SCAN_STEP + 0.0001,
		"the face is 1 m out, on the border x = 6")


## A pond's bank storey never exceeds the pre-carve ground at any 12 m
## terrain point within its maximum wobble radius plus 24 m: a shore point's
## tile has corners up to 12 * sqrt(2) m away, and a tile never rises above
## its corners. Independent brute force over the bounding box of lattice
## points (not the code's enumeration), across every pool and pond of two
## seeds' central source windows. At seed 2697992464 (amplitude 22, super-cell
## (6, 3)) an odd point 15.6 m high lies under a storey-4 level that a 24 m-
## pitch or 12 m-ring survey allowed.
func test_pond_level_respects_every_twelve_metre_point() -> void:
	var checked := 0
	for seed_value: int in [2697992464, 991177]:
		# Production amplitude: a 22 m world has no rivers since the 2026-10-02
		# regime field (it never reaches the 15.36 m headwater floor).
		var plan := TerrainWorldTuning.make_water(seed_value)
		for sz in range(-6, 7):
			for sx in range(-6, 7):
				if not plan.has_source(Vector2i(sx, sz)):
					continue
				var t := plan.river_for(Vector2i(sx, sz), 0)
				if t == null:
					continue
				for pool: PondStamp in [t.source_pool, t.pond]:
					if pool == null:
						continue
					var bound: float = pool.radius * (1.0 + PondStamp.WOBBLE) + 24.0
					var lo := Vector2i(((pool.center - Vector2.ONE * bound) / 12.0).floor())
					var hi := Vector2i(((pool.center + Vector2.ONE * bound) / 12.0).ceil())
					var min_h := INF
					for j in range(lo.y, hi.y + 1):
						for i in range(lo.x, hi.x + 1):
							var p := Vector2(i * 12.0, j * 12.0)
							if p.distance_to(pool.center) <= bound:
								min_h = minf(min_h, plan.noise_h(p))
					checked += 1
					assert_lte(float(pool.level) * WaterPlan.STOREY, maxf(min_h, WaterPlan.STOREY) + 0.0001,
						"seed %d pool at %s: bank storey %d over the lowest 12 m point %.3f" % [
							seed_value, pool.center, pool.level, min_h])
	assert_gt(checked, 10, "enough pools checked")


## Review focus 5: at 12 m sampling, every lattice point whose dual cell the
## river centreline crosses is excavated to the channel bed, so the carved
## points along a river form one cardinally connected chain.
func test_carve_is_continuous_along_a_trace_at_twelve_metre_points() -> void:
	var w := TerrainWorldTuning.make_water(SEED)
	var traced := 0
	var checked := 0
	for sz in range(-2, 3):
		for sx in range(-2, 3):
			var t := w.river_for(Vector2i(sx, sz), WaterPlan.JOIN_DEPTH)
			if t == null:
				continue
			traced += 1
			var core := {}
			var previous := Vector2i(2147483647, 0)
			for si in t.points.size() - 1:
				var a := t.points[si]
				var b := t.points[si + 1]
				var steps := maxi(1, ceili(a.distance_to(b) / 0.5))
				for k in steps + 1:
					var q := a.lerp(b, float(k) / float(steps))
					var point := Vector2i(Tile.point_of(q.x), Tile.point_of(q.y))
					if point != previous and previous.x != 2147483647:
						var step := point - previous
						if absi(step.x) + absi(step.y) == 2:
							# A diagonal hop grazes a dual-cell corner: one of the two
							# bridging cells must be carved too.
							var bridged := _core_carved(w, t, previous + Vector2i(step.x, 0), core) \
								or _core_carved(w, t, previous + Vector2i(0, step.y), core)
							assert_true(bridged, "diagonal hop %s -> %s is bridged" % [previous, point])
						else:
							assert_eq(absi(step.x) + absi(step.y), 1, "centreline moves one dual cell at a time")
					previous = point
					if _core_carved(w, t, point, core):
						checked += 1
					else:
						assert_true(false, "river %s point %s under the centreline is not carved to its bed"
							% [t.source_cell, point])
	assert_gt(traced, 0, "window contains rivers")
	assert_gt(checked, 200, "enough centreline points checked")


## Chunk borders: two neighbouring chunks see the same shoreline through
## different MARGIN windows (and may chain it in opposite directions). The
## smoothed, resampled curve must still cross the shared border at the
## identical point, however tightly the 12 m terrain bends it there.
func test_contour_resample_welds_on_chunk_borders() -> void:
	var border := WaterField.CHUNK   # x = 192
	var centre := Vector2(border - 3.0, -1100.0)
	# One shoreline: the same presence-grid vertices in both chunks.
	var shore := PackedVector2Array()
	for k in 101:
		var a := lerpf(-2.8, 2.8, float(k) / 100.0)
		shore.append(centre + Vector2(cos(a), sin(a)) * 14.0)
	var left := Rect2(Vector2(0.0, -1152.0), Vector2(border, 192.0))
	var right := Rect2(Vector2(border, -1152.0), Vector2(192.0, 192.0))
	# Chunk A's window cuts the curve in one place, chunk B's in another, and B
	# chains it the other way round.
	var a_pts: PackedVector2Array = shore.slice(7, 90)
	var b_pts: PackedVector2Array = shore.slice(16, 97)
	b_pts.reverse()
	var got := []
	for item: Array in [[a_pts, left], [b_pts, right]]:
		var pts: PackedVector2Array = item[0]
		pts = WaterContour._chaikin(WaterContour._chaikin(pts, false), false)
		pts = WaterContour._resample(pts, false, WaterContour.SPACING)
		var on_border := []
		for piece: PackedVector2Array in WaterContour._clip_to_rect(pts, false, item[1]).pieces:
			for p: Vector2 in [piece[0], piece[piece.size() - 1]]:
				if absf(p.x - border) < 0.0001:
					on_border.append(p)
		on_border.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		got.append(on_border)
	assert_eq(got[0].size(), 2, "the arc crosses the border twice")
	assert_eq(got[1].size(), got[0].size(), "both chunks see the same crossings")
	for k in mini(got[0].size(), got[1].size()):
		assert_lt((got[0][k] as Vector2).distance_to(got[1][k]), 0.0001,
			"border crossing %d welds: %s vs %s" % [k, got[0][k], got[1][k]])


## An open contour ending on a chunk border with a LEVEL shelf (wall contact
## or still-wet column: rows 0..4 all at the water level along one normal) has
## a straight ladder end. Its end cap must still pair every band edge: found
## at the shallow border crossings (+-67.4, -1152) of the reported lake, where
## a row0-apex fan degenerated to one triangle and left a T-junction.
func test_rim_end_cap_closes_a_level_shelf_ladder() -> void:
	var st := {"verts": PackedVector3Array(), "idx": PackedInt32Array()}
	var reaches := [0.0, 0.12, 0.30, 0.48, 0.60, 0.64]
	var ids: Array[int] = []
	for k in 6:
		var y := 3.0 - (0.65 if k == 5 else 0.0)
		st.verts.append(Vector3(reaches[k], y, 0.0))
		ids.append(k)
	WaterSkin._rim_end_cap(st, ids[0], ids[1], ids[2], ids[3], ids[4], ids[5])
	var count := {}
	for t in range(0, st.idx.size(), 3):
		for k in 3:
			var a: int = st.idx[t + k]
			var b: int = st.idx[t + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = int(count.get(key, 0)) + 1
	for k in 5:
		assert_eq(int(count.get(Vector2i(k, k + 1), 0)), 1,
			"ladder edge row%d-row%d is closed by the cap" % [k, k + 1])


## A chunk's swim triggers cover only its own 24 m tiles: its frozen sampler
## answers nothing beyond the chunk, so a box built from a rim vertex that
## pokes a few centimetres past the border (the reported lake leaves chunk
## (0,-6) at (67.4,-1152) along a level shelf) classified field-wet water
## there as dry.
func test_triggers_stay_inside_their_chunk() -> void:
	var water := preload("res://tests/fixtures/ReportedWaterPlan.gd").new(2697992464)
	var plan := water.make_heightfield()
	var chunk := Vector2i(0, -6)
	var region := plan.compute_region(chunk.x * 16 + 8, chunk.y * 16 + 8, 16)
	var skin: Dictionary = WaterSkin.build(water, chunk, region)
	assert_false(skin.is_empty(), "the reported site builds water")
	var rect := Rect2(Vector2(chunk) * WaterField.CHUNK, Vector2.ONE * WaterField.CHUNK)
	for t: Dictionary in skin.get("triggers", []):
		assert_true(rect.encloses(t.rect), "trigger %s lies inside chunk %s" % [t.rect, rect])


## A shoreline crossing is one point, whichever of the two cells sharing a
## presence-grid edge refines it. A node whose depth lies in [0, _WET_EPS] is
## dry for the grid; the refinement used to call it the wet end (depth >= 0)
## and bisect from it, so the two cells emitted different crossings and the
## shoreline chain broke into fragments (19 pieces at the reported lake once
## the fill lattice left the wall lines). Here a level step rises to exactly
## the flat water level 3.0 at x = 12.
func test_contour_crossing_is_independent_of_edge_direction() -> void:
	var storeys := {}
	var levels_map := {}
	for j in range(-4, 5):
		for i in range(-4, 5):
			storeys[Vector2i(i, j)] = 0
			levels_map[Vector2i(i, j)] = 3 if i >= 1 else 0
	var region := HeightfieldRegion.new(storeys, levels_map)
	var n := 21
	var water := PackedFloat32Array(); water.resize(n * n); water.fill(3.0)
	var ctx := {"fill_base": Vector2(-60.0, -60.0), "fill_size": n, "fill": {"levels": water},
		"region": region, "ponds": [], "rivers": [], "buckets": {}}
	assert_almost_eq(WaterField.level_at(ctx, Vector2(12, 0)) - TerrainTileField.surface_y(region, 12, 0), 0.0, 0.0001,
		"precondition: the node at x = 12 sits exactly at the water level")
	var forward := WaterContour._refine_crossing(ctx, Vector2.ZERO, Vector2i(3, 0), Vector2i(4, 0))
	var backward := WaterContour._refine_crossing(ctx, Vector2.ZERO, Vector2i(4, 0), Vector2i(3, 0))
	assert_eq(forward, backward, "one crossing per edge")
	assert_lt(forward.x, 12.0, "the crossing lies before the dry node")


## Chunk-line cuts keep the contour's [1, 2] m spacing wherever a piece can:
## every arc stays within 2 m, and an arc shorter than 1 m is only ever a
## whole piece shorter than 1 m (two exact crossings, or a crossing and the
## curve's end, closer than that: both must survive for the weld).
func test_chunk_line_cuts_keep_contour_spacing() -> void:
	# Pieces of 12.0 / 2.1 / 0.5 / 7.4 m between cuts at x = 192 and z = 0.
	var cases := [
		PackedVector2Array([Vector2(180.0, 5.0), Vector2(206.0, 5.0)]),
		PackedVector2Array([Vector2(189.9, 5.0), Vector2(194.1, 5.0)]),
		PackedVector2Array([Vector2(191.5, 3.0), Vector2(199.0, 3.0)]),
		PackedVector2Array([Vector2(185.0, 1.0), Vector2(191.9, -0.5), Vector2(197.0, -6.0)]),
	]
	for pts: PackedVector2Array in cases:
		var out := WaterContour._resample(pts, false, WaterContour.SPACING)
		var cuts: Array = []
		for p: Vector2 in out:
			if fposmod(p.x, WaterField.CHUNK) == 0.0 or fposmod(p.y, WaterField.CHUNK) == 0.0:
				cuts.append(p)
		for k in range(1, out.size()):
			var arc := out[k - 1].distance_to(out[k])
			assert_lte(arc, 2.0 + 0.0001, "arc %d of %s within 2 m" % [k, pts])
			if arc < 1.0 - 0.0001:
				var whole_piece := (out[k - 1] in cuts or k - 1 == 0) and (out[k] in cuts or k == out.size() - 1)
				assert_true(whole_piece, "a short arc %.3f m is a whole piece between exact ends" % arc)


## The frozen sampler IS the field: WaterSampler runs WaterField's own fill
## evaluator (shore support, rescue, wall-aware crest) over frozen arrays and a
## point-height snapshot. Checked on a 1 m grid across the reported chunk,
## including (44.32,-1091.24) where a hand-copied evaluator without the shore
## support read 8.063 (wading) over ground 8.002 while the field read 8.030.
func test_sampler_matches_the_field_everywhere_in_the_chunk() -> void:
	var water := preload("res://tests/fixtures/ReportedWaterPlan.gd").new(2697992464)
	var plan := water.make_heightfield()
	var chunk := Vector2i(0, -6)
	var region := plan.compute_region(chunk.x * 16 + 8, chunk.y * 16 + 8, 16)
	var ctx: Dictionary = WaterField.ctx(water, chunk, region)
	var origin := Vector2(chunk) * WaterField.CHUNK
	var sampler := WaterSampler.build(ctx, region, origin, 3.0, 65, 65)
	var worst := 0.0
	var mismatched := 0
	var checked := 0
	var probes: Array[Vector2] = [Vector2(44.32, -1091.24)]
	for j in 193:
		for i in 193:
			probes.append(origin + Vector2(i, j))
	for p: Vector2 in probes:
		var truth: float = WaterField.level_at(ctx, p)
		var got: float = sampler.level_at(p)
		checked += 1
		if truth == -INF:
			if not is_nan(got):
				mismatched += 1
			continue
		if is_nan(got):
			mismatched += 1
			continue
		worst = maxf(worst, absf(got - truth))
	assert_eq(mismatched, 0, "wet/dry agree at every probe")
	assert_lt(worst, 0.00001, "levels agree (worst %.6f over %d probes)" % [worst, checked])


## Whether lattice point `point` is excavated at least to the bed of the
## nearest segment of `t` (or is exempt: spawn disk, retained bar, outside the
## core). Memoized per point.
func _core_carved(w: WaterPlan, t: RiverTrace, point: Vector2i, memo: Dictionary) -> bool:
	if memo.has(point):
		return memo[point]
	var p := Vector2(point) * HeightfieldPlan.POINT
	var ok := true
	if p.length() >= WaterPlan.SPAWN_WATER_RADIUS + 30.0 and t.retained_ground_weight(p) <= 0.0:
		var best_d := INF
		var need := 0.0
		for si in t.points.size() - 1:
			var ab := t.points[si + 1] - t.points[si]
			var along := clampf((p - t.points[si]).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
			var d := p.distance_to(t.points[si] + ab * along)
			if d < best_d:
				best_d = d
				var grade := absf(t.beds[si + 1] - t.beds[si]) / maxf(ab.length(), 0.001)
				var extra := WaterPlan.CARVE_BED_EXTRA if grade < WaterPlan.CARVE_EXTRA_MAX_GRADE else 0.0
				var bed := lerpf(t.beds[si], t.beds[si + 1], along)
				need = maxf(0.0, w.noise_h(p) - maxf(bed - extra, WaterPlan.BED_MIN))
				if d > lerpf(t.widths[si], t.widths[si + 1], along):
					need = 0.0
		ok = w.carve_at(p.x, p.y) >= need - 0.001
	memo[point] = ok
	return ok
