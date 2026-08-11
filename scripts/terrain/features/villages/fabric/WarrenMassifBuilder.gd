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
const RADIUS_CELLS := 12

## Gaussian amplitude for both the bounded footprint and its inhabited height.
## Keeping existence and height on the same monotone field gives the town one
## legible bell-shaped silhouette without introducing detached outer buildings.
const FOOTPRINT_CORE_MIN_BANDS := 16
const FOOTPRINT_CORE_MAX_BANDS := 18

## Authored inhabited depth. The Gaussian supplies the full 2..18-band bell;
## these are real building storeys above terrain, never hidden substrate.
const MIN_LAYER_BANDS := 2
const MAX_LAYER_BANDS := WarrenMassif.BUILDABLE_LAYER_BANDS

## The core must carry eight complete inhabited storeys. This is the minimum
## depth that lets the carver cut a four-storey public journey while preserving
## full headroom and occupied construction above it. Terrain relief may add
## composition, but flat valid terrain still produces a town mountain.
const MIN_CORE_BANDS := 16

## A town must expose at least five inhabited height terraces. Fewer terraces
## read as a single block; the reviewed corpus normally produces far more.
const MIN_TERRACE_LEVELS := 5
## The assignment flood uses smaller districts than the final plateau gate.
## Two independently grown districts may settle on one height and merge in the
## audit, but changing this growth cap also changes the whole deterministic
## silhouette. Keep the reviewed six-cell rhythm independent of how much of an
## already-inhabited equal-height neighborhood acceptance permits.
const MAX_TERRACE_DISTRICT_CELLS := 6
## Largest 4-connected run of one relative height. A deep inhabited massif can
## tolerate a three-by-three same-datum cluster: parcelization breaks it into
## roofs and party walls rather than rendering one bare terrace slab. Larger
## equal-height districts flatten the skyline and remain a hard failure.
const MAX_PLATEAU_CELLS := 9
const MIN_COLUMN_BANDS := 2
## A neighbouring pair of columns may step by at most this many bands OF
## AUTHORED LAYER (see WarrenMassif.layer_at -- pre-existing terrain relief
## between the pair belongs to the terrain, which renders it as slope or as a
## dressed cliff), and EMPTY GROUND COUNTS AS A NEIGHBOUR OF HEIGHT ZERO.
## Riser steps are 1-2 bands, so this comfortably allows a normal riser, an
## occasional doubled riser, or a fresh district settling one step away from
## two different neighbours -- it forbids the multi-riser cliffs per-cell
## noise produced.
##
## Applying it at the boundary is what makes the whole silhouette a stepped
## hill rather than a terraced dome standing on a cliff. While boundary
## columns were exempt the rim was a legal 7-16 band face (measured over seeds
## 0-39), and re-materialising it -- timber, then retained stone -- only ever
## changed what the cliff was made of. Four bands is two storeys, so the
## tallest continuous vertical face anywhere in the solid is now two storeys
## followed by a setback, whatever later dresses it.
const MAX_NEIGHBOR_STEP_BANDS := 4

static var last_failure := ""


static func build(world_seed: int, ground_bands: Dictionary = {},
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenMassif:
	last_failure = ""
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	if not profile.validate():
		last_failure = "invalid village scale profile"
		return null
	var radius_cells := profile.radius_cells
	var massif := WarrenMassif.new(world_seed)
	var footprint_core := profile.minimum_core_bands \
		+ posmod(_hash(world_seed, 5, 0, 0),
			profile.maximum_core_bands - profile.minimum_core_bands + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18

	# Pass 1: existence only, from the smooth field. `raw` is monotonic along
	# every ray from the centre (the angular warp only rescales the radius
	# fed into the Gaussian; it never makes height increase outward), so
	# thresholding it alone yields one star-shaped, simply-connected,
	# hole-free footprint regardless of how terrace levels are later chosen.
	var raw_at: Dictionary = {}
	for z in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var radius := Vector2(float(x), float(z)).length()
			var angle := atan2(float(z), float(x))
			var warped := radius * (1.0 + warp_strength \
				* sin(angle * 3.0 + warp_phase))
			var gaussian := exp(-pow(warped / float(radius_cells) * 1.9,
				2.0))
			var raw := float(footprint_core) * gaussian
			if raw < float(MIN_COLUMN_BANDS):
				continue
			# The field is both footprint and inhabited height.  Keeping the
			# unscaled Gaussian restores the strong bell: low one-storey rim
			# buildings step toward six-to-eight-storey centre stacks.
			raw_at[Vector2i(x, z)] = raw

	# Pass 2: capacity-limited flood fill assigns the actual terrace bands,
	# under a per-column ceiling derived from how far that column stands from
	# the empty ground outside the footprint.
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
	# Already relief-relative before this wave, and stated through the shared
	# accessor now so the whole gate battery reads one definition of "mass this
	# builder authored".
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.layer_at(column))
	if massif.core_top_bands > MAX_LAYER_BANDS:
		last_failure = "layer of %d bands exceeds the buildable %d" % [
			massif.core_top_bands, MAX_LAYER_BANDS]
		return null
	if massif.core_top_bands < profile.minimum_core_bands:
		last_failure = "core reaches %d bands; %d required" % [
			massif.core_top_bands, profile.minimum_core_bands]
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
	if not massif.seal():
		last_failure = massif.last_rejection
		return null
	return massif


static func _worst_neighbor_step(massif: WarrenMassif) -> int:
	## The tallest continuous vertical face THIS BUILDER authored. A MISSING
	## neighbour is not skipped: it is ground, so the face it exposes is the
	## column's whole layer above its own base. All four directions are visited
	## because the empty side of a boundary column has no column of its own to
	## visit it back.
	##
	## Between two present columns the step measured is the difference in LAYER,
	## not in absolute top. The absolute difference also contains the step the
	## GROUND took between those same two columns, and that step is the
	## terrain's to render -- as a walkable slope or as a dressed cliff -- not a
	## cliff the massif must forbid. Charging it here is what made a terraced
	## input frame report an 8-band cliff before a single band of mass had been
	## placed (terrain audit, ledger line 208). The two happen to coincide on
	## flat ground, which is why this went unnoticed for the whole build.
	var worst := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if not massif.has_column(neighbor):
				worst = maxi(worst, massif.layer_at(column))
				continue
			worst = maxi(worst, absi(massif.layer_at(column)
				- massif.layer_at(neighbor)))
	return worst


static func _step_ceilings(raw_at: Dictionary) -> Dictionary:
	## MAX_NEIGHBOR_STEP_BANDS per step of 4-connected distance from the empty
	## ground outside the footprint. A column one cell from the edge may stand
	## four bands, two cells from the edge eight, and so on -- the tightest
	## height assignment that can still descend to zero in legal steps.
	##
	## Necessary: a column d cells from open ground has a chain of d-1 columns
	## between it and the outside, and each link may drop at most
	## MAX_NEIGHBOR_STEP_BANDS. Sufficient in practice because adjacent
	## distances differ by at most one, so a neighbour's ceiling never forces a
	## level above this one's -- see _new_district_level's clamp.
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
		ceilings[column] = int(distance.get(column, 1)) \
			* MAX_NEIGHBOR_STEP_BANDS
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
			if total_size > MAX_TERRACE_DISTRICT_CELLS:
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
			chosen_level = _new_district_level(cell, raw_at, world_seed,
				neighbor_levels, ceiling)

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
		world_seed: int, neighbor_levels: Array, ceiling: int) -> int:
	## Starts a fresh district a riser away from its neighbours. The riser
	## rhythm (1 or 2 bands) is seed-and-cell-varied so terraces do not
	## repeat one global step size.
	##
	## `ceiling` is the rim step limit and outranks every other consideration:
	## a column that cannot descend to open ground in legal steps is the cliff
	## this builder exists to forbid, whereas a district one band off its
	## preferred riser is only a slightly different terrace.
	var riser := 1 + posmod(_hash(world_seed, 17, cell.x, cell.y), 2)
	var raw_here: float = raw_at[cell]
	var lvl := mini(int(floor(raw_here / float(riser))) * riser, ceiling)
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
	# chance to size-check the merge.
	var attempts := 0
	while neighbor_levels.has(lvl) and attempts < 8:
		if lvl + riser <= hi and not neighbor_levels.has(lvl + riser):
			lvl += riser
		elif lvl - riser >= lo and not neighbor_levels.has(lvl - riser):
			lvl -= riser
		elif lvl + riser <= hi:
			lvl += riser
		elif lvl - riser >= lo:
			lvl -= riser
		else:
			break
		attempts += 1
	return lvl


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
