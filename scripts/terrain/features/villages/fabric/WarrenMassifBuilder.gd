class_name WarrenMassifBuilder
extends RefCounted

## Builds the terraced solid massif. Existence is a warped Gaussian
## threshold (unchanged shape as the raw radial bump, so the footprint stays
## one simply-connected, hole-free blob -- see WarrenMassif.seal()). Terrace
## LEVELS are assigned by a capacity-limited flood fill outward from the
## peak: each terrace "district" is grown one column at a time up to
## MAX_PLATEAU_CELLS, and every new district's level is chosen within
## MAX_NEIGHBOR_STEP_BANDS of every already-assigned neighbour. This
## guarantees both the plateau gate and the neighbour-step gate by
## construction rather than by hoping randomised per-cell noise happens to
## satisfy them -- per-cell/per-district noise wide enough to break up the
## Gaussian's flat outer tail (see fix-round-1 in task-1-report.md) either
## fractured the footprint (when it also gated existence) or produced
## cliffs of up to 20 bands between neighbours (when it only touched level).
const RADIUS_CELLS := 16
const MIN_CORE_BANDS := 16
const MAX_CORE_BANDS := 20
const MIN_TERRACE_LEVELS := 5
const MAX_PLATEAU_CELLS := 6
const MIN_COLUMN_BANDS := 2
## A neighbouring pair of columns may step by at most this many bands, and
## EMPTY GROUND COUNTS AS A NEIGHBOUR OF HEIGHT ZERO. Riser steps are 1-2
## bands, so this comfortably allows a normal riser, an occasional doubled
## riser, or a fresh district settling one step away from two different
## neighbours -- it forbids the multi-riser cliffs per-cell noise produced.
##
## Applying it at the boundary is what makes the whole silhouette a stepped
## hill rather than a terraced dome standing on a cliff. While boundary
## columns were exempt the rim was a legal 7-16 band face (measured over seeds
## 0-39), and re-materialising it -- timber, then retained stone -- only ever
## changed what the cliff was made of. Four bands is two storeys, so the
## tallest continuous vertical face anywhere in the solid is now two storeys
## followed by a setback, whatever later dresses it.
const MAX_NEIGHBOR_STEP_BANDS := 4
## How tall the outermost ring -- every column with open ground beside it --
## may stand. Stated separately from MAX_NEIGHBOR_STEP_BANDS and gated
## separately so "the hem meets the grass" is a property with a number rather
## than a corollary of the interior riser rule.
##
## It is deliberately NOT the one storey the round-5 bell note asks for.
## MEASURED, seeds 0-23: at two bands the ceiling forces every rim column to
## the same level, the ring fuses into one same-level region and
## MAX_PLATEAU_CELLS rejects the seed -- supply falls 18/24 -> 13/24 (three
## bands: 16/24). The gate that actually binds there is the plateau cap, whose
## property is "no wide flat buildable platform"; whether a one-storey hem two
## cells wide is such a platform is a re-derivation this task did not run, so
## the rim keeps the bound the interior already proved.
const MAX_RIM_BANDS := MAX_NEIGHBOR_STEP_BANDS
## How far the peak may wander from the footprint centre, in cells. The
## existence field stays a warped Gaussian about THIS point, so it is still
## monotonic along every ray from it and the footprint stays star-shaped,
## simply connected and hole-free -- the property WarrenMassif.seal() checks.
## Without it every seed puts its summit within a cell and a half of dead
## centre (measured, seeds 0-20), which is a bell but not a landscape.
const MAX_PEAK_OFFSET_CELLS := 4
## Districts are biased off the pure Gaussian by up to this many bands, on a
## DISTRICT_BLOCK_CELLS lattice, so one hillside bulges and another dips. The
## bias moves terrace LEVELS only -- never existence -- because a field that
## also gates existence fractures the footprint (see fix-round-1 above). Every
## biased level still passes through the ceiling clamp and the neighbour-step
## clamp, so no gate is traded for the variation.
const MAX_DISTRICT_BIAS_BANDS := 2
const DISTRICT_BLOCK_CELLS := 4
## Ring means of column height, measured from the footprint centroid outward.
## A bell descends monotonically; a mesa does not. Checked as a gate rather
## than hoped for, because every other rule here is local and none of them
## forbids a plateau that happens to sit off centre.
const PROFILE_RING_COUNT := 5

static var last_failure := ""


static func build(world_seed: int,
		ground_bands: Dictionary = {}) -> WarrenMassif:
	last_failure = ""
	var massif := WarrenMassif.new(world_seed)
	var core := MIN_CORE_BANDS + posmod(_hash(world_seed, 5, 0, 0),
		MAX_CORE_BANDS - MIN_CORE_BANDS + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18
	# Where the summit stands. Every measurement below is taken about this
	# point, so the field remains one warped Gaussian and only its centre moves.
	var peak := Vector2i(
		posmod(_hash(world_seed, 13, 0, 0), MAX_PEAK_OFFSET_CELLS * 2 + 1)
			- MAX_PEAK_OFFSET_CELLS,
		posmod(_hash(world_seed, 23, 0, 0), MAX_PEAK_OFFSET_CELLS * 2 + 1)
			- MAX_PEAK_OFFSET_CELLS)

	# Pass 1: existence only, from the smooth field. `raw` is monotonic along
	# every ray from the peak (the angular warp only rescales the radius
	# fed into the Gaussian; it never makes height increase outward), so
	# thresholding it alone yields one star-shaped, simply-connected,
	# hole-free footprint regardless of how terrace levels are later chosen.
	var raw_at: Dictionary = {}
	var span := RADIUS_CELLS + MAX_PEAK_OFFSET_CELLS
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var offset := Vector2(float(x - peak.x), float(z - peak.y))
			var radius := offset.length()
			var angle := atan2(offset.y, offset.x)
			var warped := radius * (1.0 + warp_strength \
				* sin(angle * 3.0 + warp_phase))
			var gaussian := exp(-pow(warped / float(RADIUS_CELLS) * 1.9,
				2.0))
			var raw := float(core) * gaussian
			if raw < float(MIN_COLUMN_BANDS):
				continue
			raw_at[Vector2i(x, z)] = raw

	# Pass 2: capacity-limited flood fill assigns the actual terrace bands,
	# under a per-column ceiling derived from how far that column stands from
	# the empty ground outside the footprint, and off a district-biased field
	# so two seeds with the same core height do not build the same hill.
	var terrace_at := _assign_terraces(raw_at, world_seed,
		_step_ceilings(raw_at))

	for column: Vector2i in raw_at:
		var base := int(ground_bands.get(column, 0))
		var terrace: int = terrace_at[column]
		massif.columns[column] = {
			"base": base,
			"top": base + terrace,
			"terrace": terrace,
		}
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.top_at(column) - massif.base_at(column))
	if massif.core_top_bands < MIN_CORE_BANDS:
		last_failure = "core reaches %d bands; %d required" % [
			massif.core_top_bands, MIN_CORE_BANDS]
		return null
	if massif.terrace_levels().size() < MIN_TERRACE_LEVELS:
		last_failure = "only %d terrace levels" \
			% massif.terrace_levels().size()
		return null
	if massif.widest_plateau_cells() > MAX_PLATEAU_CELLS:
		last_failure = "plateau of %d cells exceeds %d" % [
			massif.widest_plateau_cells(), MAX_PLATEAU_CELLS]
		return null
	var worst_step := _worst_neighbor_step(massif)
	if worst_step > MAX_NEIGHBOR_STEP_BANDS:
		last_failure = "neighbour step of %d bands exceeds %d" % [
			worst_step, MAX_NEIGHBOR_STEP_BANDS]
		return null
	var worst_rim := _worst_rim_step(massif)
	if worst_rim > MAX_RIM_BANDS:
		last_failure = "rim stands %d bands over open ground, %d allowed" % [
			worst_rim, MAX_RIM_BANDS]
		return null
	var rings := profile_ring_means(massif)
	for ring in range(1, rings.size()):
		if rings[ring] > rings[ring - 1]:
			last_failure = "ring %d averages %.1f bands, above ring %d's %.1f " \
				% [ring, rings[ring], ring - 1, rings[ring - 1]] \
				+ "-- a mesa or a crater, not a bell"
			return null
	if not massif.seal():
		last_failure = massif.last_rejection
		return null
	return massif


static func _worst_neighbor_step(massif: WarrenMassif) -> int:
	## The tallest continuous vertical face in the solid. A MISSING neighbour is
	## not skipped: it is ground, so the face it exposes is the column's whole
	## height above its own base. All four directions are visited because the
	## empty side of a boundary column has no column of its own to visit it back.
	var worst := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if not massif.has_column(neighbor):
				worst = maxi(worst, massif.top_at(column)
					- massif.base_at(column))
				continue
			worst = maxi(worst, absi(massif.top_at(column)
				- massif.top_at(neighbor)))
	return worst


static func _worst_rim_step(massif: WarrenMassif) -> int:
	## The tallest face the hill turns to the grass. Separated from
	## _worst_neighbor_step because the rim is now held to a tighter bound than
	## an interior riser, and a single combined number would hide which one
	## a seed broke.
	var worst := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			if massif.has_column(column + direction):
				continue
			worst = maxi(worst, massif.top_at(column) - massif.base_at(column))
	return worst


static func _step_ceilings(raw_at: Dictionary) -> Dictionary:
	## MAX_RIM_BANDS at the edge, then MAX_NEIGHBOR_STEP_BANDS per further step
	## of 4-connected distance from the empty ground outside the footprint. A
	## column one cell from the edge may stand MAX_RIM_BANDS bands, two cells
	## from the edge that plus one riser, and so on -- the tightest height
	## assignment that can still descend to zero in legal steps.
	##
	## Necessary: a column d cells from open ground has a chain of d-1 columns
	## between it and the outside; the last link faces empty ground and may drop
	## at most MAX_RIM_BANDS, each earlier link at most MAX_NEIGHBOR_STEP_BANDS.
	## Sufficient in practice because adjacent distances differ by at most one,
	## so a neighbour's ceiling never forces a level above this one's -- see
	## _new_district_level's clamp.
	var distance: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for column: Vector2i in raw_at:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			if raw_at.has(column + direction):
				continue
			distance[column] = 1
			frontier.append(column)
			break
	var index := 0
	while index < frontier.size():
		var column: Vector2i = frontier[index]
		index += 1
		var next_distance: int = int(distance[column]) + 1
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if not raw_at.has(neighbor) or distance.has(neighbor):
				continue
			distance[neighbor] = next_distance
			frontier.append(neighbor)
	var ceilings: Dictionary = {}
	for column: Vector2i in raw_at:
		ceilings[column] = MAX_RIM_BANDS \
			+ (int(distance.get(column, 1)) - 1) * MAX_NEIGHBOR_STEP_BANDS
	return ceilings


static func _assign_terraces(raw_at: Dictionary, world_seed: int,
		ceilings: Dictionary) -> Dictionary:
	## Processes columns from the peak outward (highest raw first, hash
	## tie-broken for determinism). Each column either joins an adjacent
	## district whose resulting size stays within MAX_PLATEAU_CELLS and
	## whose level is within MAX_NEIGHBOR_STEP_BANDS of every other
	## neighbouring district, or starts a new district one riser away from
	## its neighbours. Districts are tracked with a union-find so that two
	## districts discovered to share a level (e.g. a later column bridges
	## them) are merged immediately -- capping each union-find set, not each
	## column group in isolation, is what actually keeps same-level
	## connected regions small; capping in isolation lets two same-level
	## districts merge past the cap the moment a column touches both.
	##
	## Every choice is additionally bounded by `ceilings`, the rim step limit,
	## which is tracked per district as the minimum over its members so that a
	## merge can never lift a near-edge column above what it may carry.
	var order: Array = raw_at.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ra: float = raw_at[a]
		var rb: float = raw_at[b]
		if not is_equal_approx(ra, rb):
			return ra > rb
		return _hash(world_seed, 301, a.x, a.y) < _hash(world_seed, 301, b.x, b.y))

	var dsu_parent: Dictionary = {}
	var dsu_size: Dictionary = {}
	var dsu_level: Dictionary = {}
	var next_id := 0
	var region_of: Dictionary = {}

	for cell: Vector2i in order:
		var roots_by_level: Dictionary = {}
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + direction
			if not region_of.has(n):
				continue
			var root := _dsu_find(dsu_parent, int(region_of[n]))
			var lvl := int(dsu_level[root])
			if not roots_by_level.has(lvl):
				roots_by_level[lvl] = []
			var arr: Array = roots_by_level[lvl]
			if not arr.has(root):
				arr.append(root)
		var neighbor_levels: Array = roots_by_level.keys()

		var ceiling: int = int(ceilings.get(cell, MAX_NEIGHBOR_STEP_BANDS))
		var chosen_level: Variant = null
		for lvl_key: Variant in roots_by_level.keys():
			var lvl: int = lvl_key
			if lvl > ceiling:
				continue
			var roots: Array = roots_by_level[lvl]
			var total_size := 1
			for r: int in roots:
				total_size += int(dsu_size[r])
			if total_size > MAX_PLATEAU_CELLS:
				continue
			var ok := true
			for other_key: Variant in neighbor_levels:
				var other: int = other_key
				if other == lvl:
					continue
				if absi(lvl - other) > MAX_NEIGHBOR_STEP_BANDS:
					ok = false
					break
			if ok:
				chosen_level = lvl
				break

		if chosen_level == null:
			# The size a merge onto each occupied level would produce, so the
			# last-resort branch below can pick the cheapest one instead of
			# whichever level the riser rhythm happened to land on.
			var merged_size: Dictionary = {}
			for lvl_key: Variant in roots_by_level.keys():
				var total := 1
				for r: int in roots_by_level[lvl_key] as Array:
					total += int(dsu_size[r])
				merged_size[int(lvl_key)] = total
			chosen_level = _new_district_level(cell, raw_at, world_seed,
				neighbor_levels, ceiling, merged_size)

		var cl: int = chosen_level
		var cur_root: int
		if roots_by_level.has(cl):
			var roots: Array = roots_by_level[cl]
			cur_root = roots[0]
			for i in range(1, roots.size()):
				cur_root = _dsu_union(dsu_parent, dsu_size, cur_root, roots[i])
			cur_root = _dsu_find(dsu_parent, cur_root)
			dsu_size[cur_root] = int(dsu_size[cur_root]) + 1
		else:
			var rid := next_id
			next_id += 1
			dsu_parent[rid] = rid
			dsu_size[rid] = 1
			dsu_level[rid] = cl
			cur_root = rid

		region_of[cell] = cur_root

	var level_of: Dictionary = {}
	for cell: Vector2i in region_of:
		level_of[cell] = int(dsu_level[_dsu_find(dsu_parent, int(region_of[cell]))])
	return level_of


static func _new_district_level(cell: Vector2i, raw_at: Dictionary,
		world_seed: int, neighbor_levels: Array, ceiling: int,
		merged_size: Dictionary = {}) -> int:
	## Starts a fresh district a riser away from its neighbours. The riser
	## rhythm (1 or 2 bands) is seed-and-cell-varied so terraces do not
	## repeat one global step size.
	##
	## `ceiling` is the rim step limit and outranks every other consideration:
	## a column that cannot descend to open ground in legal steps is the cliff
	## this builder exists to forbid, whereas a district one band off its
	## preferred riser is only a slightly different terrace.
	var riser := 1 + posmod(_hash(world_seed, 17, cell.x, cell.y), 2)
	var raw_here: float = float(raw_at[cell]) + float(_district_bias(cell,
		world_seed))
	var lvl := mini(int(floor(maxf(0.0, raw_here) / float(riser))) * riser,
		ceiling)
	if neighbor_levels.is_empty():
		return lvl
	var lo := -2147483648
	var hi := 2147483647
	for other_key: Variant in neighbor_levels:
		var other: int = other_key
		lo = maxi(lo, other - MAX_NEIGHBOR_STEP_BANDS)
		hi = mini(hi, other + MAX_NEIGHBOR_STEP_BANDS)
	if lo > hi:
		# Two already-assigned neighbours are themselves more than
		# 2*MAX_NEIGHBOR_STEP_BANDS apart (rare: two flood-fill fronts
		# meeting on opposite sides of a warped lobe with different
		# accumulated step counts). No single level satisfies both; centre
		# on whichever is closest to minimise the unavoidable violation
		# rather than leaving the raw value unclamped against neither.
		var closest: int = int(neighbor_levels[0])
		for other_key2: Variant in neighbor_levels:
			var other2: int = other_key2
			if absi(lvl - other2) < absi(lvl - closest):
				closest = other2
		lo = closest - MAX_NEIGHBOR_STEP_BANDS
		hi = closest + MAX_NEIGHBOR_STEP_BANDS
	# The ceiling is applied last and wins outright: a neighbour pulling this
	# column up is exactly how the rim used to become a cliff.
	hi = mini(hi, ceiling)
	lo = mini(lo, hi)
	lvl = clampi(lvl, lo, hi)
	# Nudge away from exactly matching a neighbour's level: an exact match
	# here would silently bridge two districts before the union-find has a
	# chance to size-check the merge. The whole window is scanned outward from
	# the preferred level rather than only the two adjacent risers, because a
	# tight window -- which is what a low ceiling near the rim produces -- often
	# has the only free level three or four bands away, and taking the match
	# instead is exactly how a ring of rim columns fuses into one plateau.
	if not neighbor_levels.has(lvl):
		return lvl
	for distance in range(1, hi - lo + 1):
		if lvl + distance <= hi and not neighbor_levels.has(lvl + distance):
			return lvl + distance
		if lvl - distance >= lo and not neighbor_levels.has(lvl - distance):
			return lvl - distance
	# Every legal level is already a neighbour's, so this column must join one.
	# Join the SMALLEST, since the plateau gate counts the merged region: taking
	# the riser's preference here is how a window with no free level turns two
	# capped districts into one over-cap plateau.
	var best := lvl
	var best_size := int(merged_size.get(lvl, 1 << 30))
	for level_key: Variant in merged_size.keys():
		var level: int = level_key
		if level < lo or level > hi:
			continue
		var size := int(merged_size[level_key])
		if size < best_size or (size == best_size and level < best):
			best = level
			best_size = size
	return best


static func _district_bias(cell: Vector2i, world_seed: int) -> int:
	## Bumps and dips at district scale, in bands. One integer hash per
	## DISTRICT_BLOCK_CELLS block, so a whole hillside leans the same way rather
	## than each column jittering independently -- per-cell noise is what
	## produced the cliffs that made this class a flood fill in the first place.
	##
	## Deliberately applied AFTER existence and BEFORE both clamps: it changes
	## which terrace a district prefers and nothing else, so no seed can gain a
	## hole, a plateau or a cliff from it.
	var block := Vector2i(floori(float(cell.x) / float(DISTRICT_BLOCK_CELLS)),
		floori(float(cell.y) / float(DISTRICT_BLOCK_CELLS)))
	return posmod(_hash(world_seed, 29, block.x, block.y),
		MAX_DISTRICT_BIAS_BANDS * 2 + 1) - MAX_DISTRICT_BIAS_BANDS


static func profile_ring_means(massif: WarrenMassif) -> PackedFloat64Array:
	## Mean column height per concentric ring, core ring first, measured from
	## the footprint centroid and normalised by the widest radius. This is the
	## bell the review asked for, stated as a number a gate can read.
	var centroid := Vector2.ZERO
	for column: Vector2i in massif.columns:
		centroid += Vector2(column)
	centroid /= float(maxi(1, massif.columns.size()))
	var widest := 0.0
	for column: Vector2i in massif.columns:
		widest = maxf(widest, (Vector2(column) - centroid).length())
	var sums := PackedFloat64Array()
	var counts := PackedInt32Array()
	for _index in PROFILE_RING_COUNT:
		sums.append(0.0)
		counts.append(0)
	for column: Vector2i in massif.columns:
		var ring := clampi(int((Vector2(column) - centroid).length()
			/ maxf(0.001, widest) * float(PROFILE_RING_COUNT)), 0,
			PROFILE_RING_COUNT - 1)
		sums[ring] += float(massif.top_at(column) - massif.base_at(column))
		counts[ring] += 1
	var out := PackedFloat64Array()
	for ring in PROFILE_RING_COUNT:
		out.append(sums[ring] / float(maxi(1, counts[ring])))
	return out


static func _dsu_find(parent: Dictionary, rid: int) -> int:
	var root := rid
	while int(parent[root]) != root:
		root = int(parent[root])
	var cur := rid
	while int(parent[cur]) != root:
		var next_cur: int = int(parent[cur])
		parent[cur] = root
		cur = next_cur
	return root


static func _dsu_union(parent: Dictionary, size: Dictionary, a: int, b: int) -> int:
	var ra := _dsu_find(parent, a)
	var rb := _dsu_find(parent, b)
	if ra == rb:
		return ra
	if int(size[ra]) < int(size[rb]):
		var tmp := ra
		ra = rb
		rb = tmp
	parent[rb] = ra
	size[ra] = int(size[ra]) + int(size[rb])
	return ra


static func _hash(world_seed: int, salt: int, x: int, z: int) -> int:
	var value := world_seed * 73856093 ^ salt * 19349663 \
		^ x * 83492791 ^ z * 2971215073
	value = posmod(value, 2147483647)
	return value
