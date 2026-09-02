class_name WarrenMassifBuilder
extends RefCounted

## Builds the terraced solid massif.
##
## EXISTENCE is unchanged. A warped Gaussian threshold decides the footprint,
## and `raw` is monotonic along every ray from the centre (the angular warp
## only rescales the radius fed into the Gaussian; it never makes the field
## increase outward), so thresholding it alone yields one star-shaped,
## simply-connected, hole-free blob. Keeping the shape law separate from the
## height law is what makes WarrenMassif.seal()'s invariants a property of the
## footprint rather than a thing each new height field has to re-earn -- the
## fix-round-1 history in task-1-report.md is what happens when a noisy field
## gates existence too. Footprints are byte-identical to the flood fill this
## replaced; only heights moved.
##
## HEIGHT is a seeded terraced field (Phase E). Five steps, answering the
## user's visual direction of 2026-08-24 -- "the sides of the city are sheer
## multi-storey flat walls; I want it to naturally get lower towards the edges
## (while preventing it from being too noisy -- we still want clusters)":
##
##   1. DESCENT RAMP. A column's height starts from its DEPTH: how many cells
##      of solid stand between it and the empty ground outside, 4-connected.
##      Depth rather than radius, because the footprint is a warped star and a
##      radial ramp leaves the lobes tall and the notches short; depth hugs
##      whatever outline the warp drew, so the town gets lower towards ITS OWN
##      edges. The ramp runs from RAMP_FOOT_TERRACES at the boundary to the
##      seed's rolled core at the deepest column, at one constant grade, which
##      spends the whole available depth on the descent instead of standing the
##      town on a rim wall.
##   2. NOISE. Two octaves of deterministic lattice value noise displace the
##      ramp by up to CLUSTER_RELIEF_TERRACES storeys. The coarse octave's
##      period is CLUSTER_PERIOD_CELLS, so its features are terrace-sized: it
##      breaks each depth ring into a handful of arcs standing a storey apart
##      instead of one continuous ring, and it is what makes two seeds'
##      silhouettes differ.
##   3. QUANTIZE. To whole storeys (TERRACE_BANDS), under the rim ceiling,
##      before any consumer sees the field. Terraces are the unit of this town:
##      neighbours differ by 0 or 1 storey almost everywhere, and a house's
##      stack meets its address on a storey boundary.
##   4. REPAIR (_repair_steps). Lower anything that ended up more than one
##      riser over a neighbour. Downward only, so it terminates, and it leaves
##      the neighbour-step gate true by construction rather than by argument.
##   5. CLUSTER MERGE (_merge_small_terraces). A terrace of fewer than
##      MIN_CLUSTER_CELLS columns is the per-column dither the direction rules
##      out, so it is absorbed into the neighbouring terrace it shares the most
##      edges with -- trying every neighbouring height in contact order, not
##      just the most-contacted one, because on a steep town the best-contacted
##      height is usually the one the step gate forbids.
##
## The noise is this repository's own integer hash (WarrenPassageLatticeRules
## .hash_key over a lattice of grid corners), NOT FastNoiseLite or any other
## engine noise class: those are not seed-stable across Godot versions, so an
## engine upgrade would silently re-roll every town's silhouette while every
## pinned metric in the suites went on claiming to describe it.
##
## MEASURED (24-town corpus, flat frame). Mean columns per equal-layer terrace
## cluster, before this field -> after; the tallest rim wall was 4 bands before
## and after, on every town:
##
##   12/compact 2.59 -> 2.52   4/compact 2.67 -> 3.47
##   3/standard 3.65 -> 3.65   9/standard 3.32 -> 4.85
##   corpus mean 3.12 -> 3.83; corpus worst 2.59 -> 2.52; corpus best 3.69 ->
##   5.41; house-capable columns 0.86 -> 0.89-1.00 of the footprint; 24-town
##   corpus seal 22 -> 21, both misses inside the two gate families Phase C
##   and D already carried
##
## WHERE THE FLOOR BINDS, and it is geometry, not tuning. The ramp's grade is
## (core + SUMMIT_HEADROOM_TERRACES - RAMP_FOOT_TERRACES) / (depth - 1) storeys
## per column, clamped to MAX_STEP_TERRACES. A compact town is 8-11 columns
## across, so its deepest column is only 4-5 cells from open ground, while its
## scale profile demands a 12-15 band core: five to six storeys of descent
## spent over three or four columns. That is 1.5-2.0 storeys per column, at or
## against MAX_STEP_TERRACES -- the neighbour-step gate's own maximum. At that
## grade almost every column is a mandatory riser between the two beside it,
## and a column that is a riser cannot also be part of a terrace.
##
## MEASURED AS STEPS, which is the grade in the form a test can see -- the
## massif suite prints this per planner town and pins nothing, because how
## steep a town may look is Phase G's battery to judge (controller ruling,
## 2026-08-23: compact's two-terrace risers are measured here, not changed).
## Share of 4-neighbour pairs standing 0 / 1 / 2 terraces apart:
##
##   12/compact  0.356 / 0.172 / 0.471   <- grade at the gate's maximum
##   4/compact   0.464 / 0.268 / 0.268
##   3/standard  0.442 / 0.281 / 0.276
##   9/standard  0.514 / 0.212 / 0.275
##
## 12/compact spends nearly half its edges on a two-storey riser where the
## others spend a quarter, and has the fewest flat edges of the four -- which
## is exactly why it sits at 2.52 columns per terrace while 9/standard reaches
## 4.85. Spending more columns on the descent needs a bigger footprint, which
## is WarrenVillageScaleProfile's decision and not this builder's.
const RADIUS_CELLS := 12

## Gaussian amplitude for both the bounded footprint and its inhabited height.
## Keeping existence and height on the same monotone field gives the town one
## legible bell-shaped silhouette without introducing detached outer buildings.
const FOOTPRINT_CORE_MIN_BANDS := 16
const FOOTPRINT_CORE_MAX_BANDS := 18

## Authored inhabited depth. These are real building storeys above terrain,
## never hidden substrate.
const MIN_LAYER_BANDS := 2
const MAX_LAYER_BANDS := WarrenMassif.BUILDABLE_LAYER_BANDS

## TASK F1 RULING 4. `MIN_CORE_BANDS := 16` used to sit here: eight complete
## inhabited storeys, the depth the SEARCHED bore needed to cut a four-storey
## public journey with headroom and construction above it. No production code
## ever read it -- the floor `_shape_gate_failure` enforces, and therefore the
## floor every sealed massif satisfies by construction, is the size profile's
## own `minimum_core_bands` (compact 10, standard 10, large 12, grand 14).
## Measured on the terraced field the constant is also unreachable: the peak
## layer is a whole two-band storey. Those profile floors now name complete
## terrace counts rather than odd band values which silently round upward.
## Five terraces is the shared grammar floor; larger profiles ask for one and
## two additional terraces without making the smaller fields pretend to have
## the footprint of the old scale.

## Every production town exposes at least five inhabited height terraces. The
## selected scale profiles start at the smallest source radius proved capable
## of sealing this complete stepped silhouette.
const MIN_TERRACE_LEVELS := 5
const MIN_COLUMN_BANDS := 2
## A neighbouring pair of columns may step by at most this many bands OF
## AUTHORED LAYER (see WarrenMassif.layer_at -- pre-existing terrain relief
## between the pair belongs to the terrain, which renders it as slope or as a
## dressed cliff), and EMPTY GROUND COUNTS AS A NEIGHBOUR OF HEIGHT ZERO.
##
## Applying it at the boundary is what makes the whole silhouette a stepped
## hill rather than a terraced dome standing on a cliff. While boundary
## columns were exempt the rim was a legal 7-16 band face (measured over seeds
## 0-39), and re-materialising it -- timber, then retained stone -- only ever
## changed what the cliff was made of. Four bands is two storeys, so the
## tallest continuous vertical face anywhere in the solid is two storeys
## followed by a setback, whatever later dresses it.
const MAX_NEIGHBOR_STEP_BANDS := 4

## THE UNIT OF THE FIELD. Every authored layer is a whole number of these, so
## every terrace is a whole number of storeys and every riser is a stair rather
## than a lip. Quantizing here -- before the massif object exists -- is what
## makes "terraces" a fact about the envelope instead of a description of it.
const TERRACE_BANDS := WarrenBuildingParcel.STOREY_BANDS
const MIN_TERRACES := MIN_LAYER_BANDS / TERRACE_BANDS
const MAX_TERRACES := MAX_LAYER_BANDS / TERRACE_BANDS
const MAX_STEP_TERRACES := MAX_NEIGHBOR_STEP_BANDS / TERRACE_BANDS

## What a boundary column may STAND: two storeys, the visual ceiling the
## direction sets for the rim ("never sheer multi-storey rim walls").
const RIM_TERRACES := 2

## Where the descent ramp ENDS: on the rim ceiling itself, so the noise can
## only ever cut a boundary column BELOW it. That is what gives the rim two
## heights (one storey and its roof, or the bare roof reservation) and lets it
## read as a broken edge rather than one continuous skirt, while keeping the
## great majority of it buildable.
##
## MEASURED, and it decided the constant. Aiming the foot a storey LOWER --
## which makes the rim mostly MIN_LAYER_BANDS and breaks the skirt harder --
## raises the corpus terrace-cluster mean from 3.83 to 4.19, and costs FIVE
## towns: 21 of 24 seal with the foot here, 16 with it a storey down. A
## MIN_LAYER_BANDS column carries no storey at all
## (WarrenMazeSourcePlan.MIN_HOUSE_BANDS is two bands more than it), so a rim
## aimed low turns a third of every town into roof stubs that no house, and no
## street, can stand on: house-capable columns fall from 0.89-1.00 of the
## footprint to about 0.67. The clustered silhouette is not worth a town that
## cannot be lived in at its edge.
const RAMP_FOOT_TERRACES := RIM_TERRACES

## Half a storey of aim above the crown. The ramp is quantized by rounding and
## the summit is a handful of columns, so a ramp aimed exactly at the core
## height loses the crown to a single unlucky noise sample and the whole town
## is refused for standing a storey short of its scale.
const SUMMIT_HEADROOM_TERRACES := 0.5

## Coarse octave period, in cells: the size of a terrace cluster before the
## merge sees it. Five cells is a terrace one house-group wide -- small enough
## that a depth ring breaks into several arcs, large enough that neighbouring
## columns overwhelmingly share their arc.
const CLUSTER_PERIOD_CELLS := 5
## Fine octave: well under the coarse period, at roughly a third of its weight.
## It exists to stop the coarse lattice's own grid from showing as
## axis-aligned terrace edges; more than this and the field dithers again.
const DETAIL_PERIOD_CELLS := 2
const DETAIL_OCTAVE_WEIGHT := 0.35
## Storeys of displacement the noise may add to (or take from) the ramp. Just
## over one storey: enough that an arc of a ring lifts clear of its neighbours
## by a whole terrace, not so much that a column can jump two.
const CLUSTER_RELIEF_TERRACES := 1.10

## Terraces smaller than this are dither and get absorbed. Set to the plan's
## own target for mean cluster size, so the merge aims at the thing that is
## measured rather than at a proxy for it. Measured alternatives: 6 and 8 raise
## the corpus mean by roughly half a column but cost a town apiece to the core
## gate, because a bigger absorption target reshuffles which noise phase seals.
##
## TASK I1 RE-MEASURED IT AT VILLAGE FOOTPRINTS AND MOVED IT 4 -> 3. This and
## MIN_TERRACE_LEVELS are the two ABSOLUTE COLUMN COUNTS in this file, and both
## were calibrated on a corpus whose towns were 81-281 columns. Task I1 halves
## every footprint (compact is now 45-58 columns), and at that size a four-cell
## absorption target eats the very terraces MIN_TERRACE_LEVELS then asks for:
## the merge runs CLUSTER_MERGE_PASSES times over a field with three or four
## depth rings, and a three-column arc of one storey is a terrace on a
## fifty-column hill, not dither.
##
## MEASURED, compact at the task's new radius 5 over seeds 1-12, threshold ->
## towns sealed: 4 -> 2, 3 -> 11. Every one of the nine towns the old threshold
## cost died at `only N terrace levels`, which is the gate this constant feeds.
## Left at 3 rather than made a function of the column count: the big scales
## shrink too (grand's median falls 252 -> 124 columns), so one number still
## describes one corpus, and a scaled expression would have been fitted to four
## medians rather than measured.
const MIN_CLUSTER_CELLS := 3
## Merging changes the partition, so the merge is re-run on the result. Six
## passes is past the point where the measured corpus stops changing.
const CLUSTER_MERGE_PASSES := 6

## The field is deterministic but one noise phase can leave a town short of its
## core height or over the plateau cap. Try a small fixed family of phases
## before rejecting the settlement, exactly as the terrace flood fill this
## replaced did. All 24 corpus towns seal inside this family.
##
## TASK I1 RAISED IT 8 -> 128, and the raise is OUTPUT-NEUTRAL BY CONSTRUCTION:
## the loop breaks at the first phase that seals, and the added phases come
## AFTER the eight that were tried before, so a town that sealed inside the old
## family builds the identical massif. Only towns that were rejected can move.
## The reason is the same one MIN_CLUSTER_CELLS carries: the summit is a handful
## of columns and the field's peak is `core + SUMMIT_HEADROOM_TERRACES` plus a
## wobble of +-CLUSTER_RELIEF_TERRACES, so a small footprint has fewer summit
## columns for the noise to get right and needs more tries to get one.
## MEASURED, and the number is the corpus's worst town rather than a guess. At
## the shipped radii the only town in the 48-town matrix that still needed more
## phases was 12/compact, and it seals at exactly 96: 48 -> rejected, 64 ->
## rejected, 96 -> SEALED (52 columns, 30 buildings, the same 12-band crown as
## its neighbours). 128 is one doubling of headroom over that measurement, for
## a production seed outside the corpus. It is not a cost on a healthy town —
## the break is at the first sealing phase, and every compact town but that one
## seals inside the original eight.
const FIELD_PHASE_ATTEMPTS := 128
const FIELD_PHASE_STRIDE := 1000003

## Largest 4-connected run of one relative height, and why it is what it is.
## A boundary column may stand one storey or two and nothing
## else -- MIN_LAYER_BANDS and RIM_TERRACES are the whole alphabet the rim is
## allowed -- and a compact town has 29-48 boundary columns. Two heights over
## 36 columns means runs of about eighteen unless the field dithers the rim on
## purpose, which is the thing the direction forbids. Measured on the terraced
## field: at 9 the corpus loses SEVEN towns to this gate alone (5/compact and
## 2, 6, 7, 9, 10, 11 standard), at 12 it loses three, at 16 none -- and
## several towns then sit exactly at 16, so the cap holds them rather than
## idling (uncapped, the same corpus reaches a 40-column run).
##
## The share exists because one constant cannot mean "a terrace" for an
## 89-column village and a 281-column grand town alike. Measured natural runs
## with the cap removed -- compact 9-40, standard 9-40, large 14-31, grand
## 20-44 -- are each roughly a sixth of their own town.
const MAZE_MAX_PLATEAU_CELLS := 16
const MAZE_PLATEAU_COLUMN_SHARE := 6

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT,
	Vector2i.UP, Vector2i.DOWN]

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
	var footprint_core := profile.core_target_band_range.x \
		+ posmod(_hash(world_seed, 5, 0, 0),
			profile.core_target_band_range.y \
				- profile.core_target_band_range.x + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18

	# Pass 1: existence only, from the smooth field. See the class comment --
	# this is the whole reason the footprint cannot fracture or grow a hole
	# however the height field below is rolled.
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
			raw_at[Vector2i(x, z)] = raw

	# Pass 2: heights, from the seeded terraced field. See the class comment.
	var massif := _terraced_massif(world_seed, raw_at, ground_bands, profile,
		footprint_core)
	if massif == null:
		return null
	# Already relief-relative before this wave, and stated through the shared
	# accessor now so the whole gate battery reads one definition of "mass this
	# builder authored".
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.layer_at(column))
	if not massif.seal():
		last_failure = massif.last_rejection
		return null
	return massif


static func _terraced_massif(world_seed: int, raw_at: Dictionary,
		ground_bands: Dictionary, profile: WarrenVillageScaleProfile,
		footprint_core: int) -> WarrenMassif:
	## THE PHASE E FIELD: steps 1-5 of the class comment. Maze mode only.
	var order := _column_order(raw_at)
	var depths := _depths(raw_at)
	var ceilings := _terrace_ceilings(depths)
	var massif: WarrenMassif = null
	var valid_fallback: WarrenMassif = null
	var closest_failure := ""
	for phase_attempt in FIELD_PHASE_ATTEMPTS:
		var phase_seed := world_seed + phase_attempt * FIELD_PHASE_STRIDE
		var terraces := _terrace_field(order, depths, ceilings, phase_seed,
			footprint_core, profile.core_target_band_range.x)
		var candidate := WarrenMassif.new(world_seed)
		for column: Vector2i in order:
			var base := int(ground_bands.get(column, 0))
			var layer: int = int(terraces[column]) * TERRACE_BANDS
			candidate.columns[column] = {
				"base": base,
				"top": base + layer,
				"terrace": layer,
			}
		var failure := _shape_gate_failure(candidate, profile)
		if failure.is_empty():
			# Prefer the first field that reaches the profile's established
			# crown target. Only after exhausting that exact bounded family may
			# the generator use the first field which clears the independent
			# five-terrace validity floor. Existing target-complete towns are
			# therefore output-stable, while a smaller but still complete town is
			# accepted instead of becoming a seed-specific refusal.
			var core_top := 0
			for column: Vector2i in candidate.columns:
				core_top = maxi(core_top, candidate.layer_at(column))
			if core_top >= profile.core_target_band_range.x:
				massif = candidate
				break
			if valid_fallback == null:
				valid_fallback = candidate
			continue
		closest_failure = failure
	if massif == null:
		massif = valid_fallback
	if massif == null:
		last_failure = "no terrace field sealed after %d phases: %s" % [
			FIELD_PHASE_ATTEMPTS, closest_failure]
		return null
	return massif


static func plateau_cap(column_count: int) -> int:
	## The widest 4-connected run of one authored layer this town may carry --
	## see MAZE_MAX_PLATEAU_CELLS.
	return maxi(MAZE_MAX_PLATEAU_CELLS,
		column_count / MAZE_PLATEAU_COLUMN_SHARE)


static func _column_order(raw_at: Dictionary) -> Array[Vector2i]:
	## Row-major column order. Every pass over the field iterates this rather
	## than a Dictionary's own key order, so the result is a function of the
	## footprint and never of how the footprint happened to be inserted.
	var order: Array[Vector2i] = []
	order.assign(raw_at.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return order


static func _depths(raw_at: Dictionary) -> Dictionary:
	## 4-connected distance from the empty ground outside the footprint: 1 for a
	## boundary column, 2 for its inward neighbour, and so on. This is the
	## town's own measure of "how far in am I", and both the descent ramp and
	## the step ceiling are stated in it.
	var distance: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for column: Vector2i in _column_order(raw_at):
		for direction: Vector2i in DIRECTIONS:
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
		for direction: Vector2i in DIRECTIONS:
			var neighbor := column + direction
			if not raw_at.has(neighbor) or distance.has(neighbor):
				continue
			distance[neighbor] = next_distance
			frontier.append(neighbor)
	return distance


static func _terrace_ceilings(depths: Dictionary) -> Dictionary:
	## RIM_TERRACES at the boundary plus MAX_STEP_TERRACES per further step
	## inward -- the tallest a column may stand and still descend to open ground
	## in legal risers.
	##
	## Necessary: a column d cells from open ground has a chain of d-1 columns
	## between it and the outside, and each link may drop at most
	## MAX_STEP_TERRACES. Sufficient because adjacent depths differ by at most
	## one, so satisfying it everywhere satisfies the neighbour-step gate
	## everywhere. It is a CEILING, not the shape: the descent ramp normally
	## sits well under it and only the rim is actually held by it.
	var ceilings: Dictionary = {}
	for column: Vector2i in depths:
		ceilings[column] = mini(MAX_TERRACES,
			RIM_TERRACES + (int(depths[column]) - 1) * MAX_STEP_TERRACES)
	return ceilings


static func _terrace_field(order: Array[Vector2i], depths: Dictionary,
		ceilings: Dictionary, phase_seed: int, footprint_core: int,
		target_floor_bands: int) -> Dictionary:
	## Steps 1-5 of the class comment: ramp, noise, quantize, repair, merge.
	var max_depth := 1
	for column: Vector2i in order:
		max_depth = maxi(max_depth, int(depths.get(column, 1)))
	# Whole storeys. Preserve the preferred target distribution's authored
	# quantization exactly; the independent validity floor participates only in
	# the final shape proof. This prevents relaxing that proof floor from
	# rerolling already-valid massifs.
	var core_terraces := clampi(maxi(int(ceil(float(target_floor_bands)
		/ float(TERRACE_BANDS))), footprint_core / TERRACE_BANDS),
		MIN_TERRACES, MAX_TERRACES)
	# The whole available depth is spent on the descent: the deepest column
	# lands on the core, the boundary on the rim, and everything between falls
	# at one constant grade. Clamped to the step gate because a footprint too
	# shallow for its own core cannot legally descend faster than that, and a
	# ramp that asked it to would only be repaired back down again.
	var grade := 0.0
	if max_depth > 1:
		grade = (float(core_terraces) + SUMMIT_HEADROOM_TERRACES
			- float(RAMP_FOOT_TERRACES)) / float(max_depth - 1)
	grade = clampf(grade, 0.0, float(MAX_STEP_TERRACES))

	var field: Dictionary = {}
	for column: Vector2i in order:
		var ramp := float(RAMP_FOOT_TERRACES) \
			+ float(int(depths.get(column, 1)) - 1) * grade
		var wobble := (_field_noise(phase_seed, column) * 2.0 - 1.0) \
			* CLUSTER_RELIEF_TERRACES
		field[column] = ramp + wobble

	var terraces: Dictionary = {}
	for column: Vector2i in order:
		terraces[column] = clampi(int(round(float(field[column]))),
			MIN_TERRACES, int(ceilings.get(column, MAX_TERRACES)))
	_repair_steps(terraces, ceilings, order)
	_merge_small_terraces(terraces, ceilings, order)
	return terraces


static func _field_noise(phase_seed: int, column: Vector2i) -> float:
	## Two octaves of lattice value noise in 0..1.
	var coarse := _value_noise(phase_seed, 41, column, CLUSTER_PERIOD_CELLS)
	var detail := _value_noise(phase_seed, 43, column, DETAIL_PERIOD_CELLS)
	return (coarse + DETAIL_OCTAVE_WEIGHT * detail) \
		/ (1.0 + DETAIL_OCTAVE_WEIGHT)


static func _value_noise(phase_seed: int, salt: int, column: Vector2i,
		period: int) -> float:
	## Smoothstep-interpolated value noise on a lattice of `period` cells,
	## seeded through WarrenPassageLatticeRules.hash_key. Written out here
	## rather than taken from FastNoiseLite because engine noise classes are not
	## seed-stable across Godot versions and every pinned silhouette metric in
	## the suites would go stale on an engine upgrade without a single file
	## changing.
	var px := float(column.x) / float(period)
	var pz := float(column.y) / float(period)
	var gx := floori(px)
	var gz := floori(pz)
	var fx := px - float(gx)
	var fz := pz - float(gz)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(
		lerpf(_lattice_value(phase_seed, salt, gx, gz),
			_lattice_value(phase_seed, salt, gx + 1, gz), sx),
		lerpf(_lattice_value(phase_seed, salt, gx, gz + 1),
			_lattice_value(phase_seed, salt, gx + 1, gz + 1), sx),
		sz)


static func _lattice_value(phase_seed: int, salt: int, gx: int,
		gz: int) -> float:
	return float(WarrenPassageLatticeRules.hash_key(phase_seed, salt,
		Vector3i(gx, 0, gz))) / 2147483646.0


static func _cluster_ids(terraces: Dictionary,
		order: Array[Vector2i]) -> Array:
	## Partitions the field into 4-connected equal-terrace regions -- exactly
	## WarrenMassif.widest_plateau_cells()'s partition, kept whole instead of
	## only at its maximum. Returns [cell -> cluster id, id -> Array of cells].
	var id_of: Dictionary = {}
	var cells_of: Array = []
	for start: Vector2i in order:
		if id_of.has(start):
			continue
		var level := int(terraces[start])
		var id := cells_of.size()
		var members: Array[Vector2i] = [start]
		id_of[start] = id
		var index := 0
		while index < members.size():
			var cell: Vector2i = members[index]
			index += 1
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if id_of.has(neighbor) or not terraces.has(neighbor) \
						or int(terraces[neighbor]) != level:
					continue
				id_of[neighbor] = id
				members.append(neighbor)
		cells_of.append(members)
	return [id_of, cells_of]


static func _merge_small_terraces(terraces: Dictionary, ceilings: Dictionary,
		order: Array[Vector2i]) -> void:
	## Step 4: absorb every terrace of fewer than MIN_CLUSTER_CELLS columns into
	## the neighbouring terrace it shares the most edges with. Contact length
	## rather than height proximity decides, because the point is to make the
	## silhouette read as districts and the district a stray column belongs to
	## is the one it is most surrounded by.
	##
	## A merge is refused, and the stray terrace kept, when it would breach the
	## neighbour step, lift a column over its rim ceiling, or fuse a run wider
	## than the town's plateau cap. The last is the important one: a merge pass
	## with no upper bound turns a terraced hill into the flat-topped slab the
	## plateau gate has always refused, which is the same complaint from the
	## other side.
	var cap := plateau_cap(order.size())
	for merge_pass in CLUSTER_MERGE_PASSES:
		var partition := _cluster_ids(terraces, order)
		var id_of: Dictionary = partition[0]
		var cells_of: Array = partition[1]
		var changed := false
		for id in cells_of.size():
			var members: Array = cells_of[id]
			if members.size() >= MIN_CLUSTER_CELLS:
				continue
			var level := int(terraces[members[0]])
			var contact: Dictionary = {}
			var neighbor_ids: Dictionary = {}
			for cell: Vector2i in members:
				for direction: Vector2i in DIRECTIONS:
					var neighbor: Vector2i = cell + direction
					if not terraces.has(neighbor):
						continue
					var other := int(terraces[neighbor])
					if other == level:
						continue
					contact[other] = int(contact.get(other, 0)) + 1
					var other_id := int(id_of[neighbor])
					var by_level: Dictionary = neighbor_ids.get(other, {})
					by_level[other_id] = int(cells_of[other_id].size())
					neighbor_ids[other] = by_level
			var candidates: Array = contact.keys()
			candidates.sort_custom(func(a: int, b: int) -> bool:
				var ca := int(contact[a])
				var cb := int(contact[b])
				if ca != cb:
					return ca > cb
				return absi(a - level) < absi(b - level))
			var best := -1
			for candidate: int in candidates:
				var fused := members.size()
				for fused_id: int in (neighbor_ids.get(candidate,
						{}) as Dictionary):
					fused += int((neighbor_ids[candidate]
						as Dictionary)[fused_id])
				if fused > cap:
					continue
				var legal := true
				for cell: Vector2i in members:
					if not _terrace_is_legal(terraces, ceilings, cell,
							candidate, id_of, id):
						legal = false
						break
				if not legal:
					continue
				best = candidate
				break
			if best < 0:
				continue
			for cell: Vector2i in members:
				terraces[cell] = best
			changed = true
		if not changed:
			return


static func _terrace_is_legal(terraces: Dictionary, ceilings: Dictionary,
		cell: Vector2i, level: int, id_of: Dictionary,
		moving_id: int) -> bool:
	## May `cell` stand on `level`? Its own rim ceiling, and one step from every
	## neighbour that is NOT moving with it (a neighbour inside the same cluster
	## ends up on `level` too, so measuring against its old height would refuse
	## the merge for a step that will not exist).
	if level < MIN_TERRACES or level > int(ceilings.get(cell, MAX_TERRACES)):
		return false
	for direction: Vector2i in DIRECTIONS:
		var neighbor := cell + direction
		if not terraces.has(neighbor):
			continue
		if int(id_of.get(neighbor, -1)) == moving_id:
			continue
		if absi(level - int(terraces[neighbor])) > MAX_STEP_TERRACES:
			return false
	return true


static func _repair_steps(terraces: Dictionary, ceilings: Dictionary,
		order: Array[Vector2i]) -> void:
	## STEP 4, and it runs BEFORE the merge, not after it. Lower any column that
	## stands more than MAX_STEP_TERRACES over a neighbour or over its rim
	## ceiling, until nothing does. Only ever lowers, so it terminates, and it
	## cannot lower a column below MIN_TERRACES because every cap it computes is
	## at least RIM_TERRACES or a neighbour's own height plus a full step.
	##
	## WHY HERE AND NOT LAST. What it repairs is QUANTIZATION: rounding each
	## column of a continuous field independently can put two neighbours three
	## terraces apart even though the field between them never was. That has to
	## be true before the merge runs, because the merge decides what is legal by
	## reading its neighbours' heights -- against an unrepaired field it would
	## be reasoning from an illegal one.
	##
	## The gate then holds inductively rather than by a second sweep: the field
	## is legal when the merge starts, and `_terrace_is_legal` refuses any move
	## that would break it, so it is still legal when the merge stops.
	var changed := true
	while changed:
		changed = false
		for cell: Vector2i in order:
			var cap := int(ceilings.get(cell, MAX_TERRACES))
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if not terraces.has(neighbor):
					cap = mini(cap, RIM_TERRACES)
					continue
				cap = mini(cap, int(terraces[neighbor]) + MAX_STEP_TERRACES)
			if int(terraces[cell]) > cap:
				terraces[cell] = maxi(MIN_TERRACES, cap)
				changed = true


static func _shape_gate_failure(massif: WarrenMassif,
		profile: WarrenVillageScaleProfile) -> String:
	if massif == null:
		return "missing terrace field"
	var core_top_bands := 0
	for column: Vector2i in massif.columns:
		core_top_bands = maxi(core_top_bands, massif.layer_at(column))
	massif.core_top_bands = core_top_bands
	if core_top_bands > MAX_LAYER_BANDS:
		return "layer of %d bands exceeds the buildable %d" % [
			core_top_bands, MAX_LAYER_BANDS]
	if core_top_bands < profile.minimum_core_bands:
		return "core reaches %d bands; %d required" % [
			core_top_bands, profile.minimum_core_bands]
	if massif.terrace_levels().size() < MIN_TERRACE_LEVELS:
		return "only %d terrace levels" % massif.terrace_levels().size()
	var cap := plateau_cap(massif.columns.size())
	if massif.widest_plateau_cells() > cap:
		return "plateau of %d cells exceeds %d" % [
			massif.widest_plateau_cells(), cap]
	var worst_step := _worst_neighbor_step(massif)
	if worst_step > MAX_NEIGHBOR_STEP_BANDS:
		return "neighbour step of %d bands exceeds %d" % [
			worst_step, MAX_NEIGHBOR_STEP_BANDS]
	return ""


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
		for direction: Vector2i in DIRECTIONS:
			var neighbor := column + direction
			if not massif.has_column(neighbor):
				worst = maxi(worst, massif.layer_at(column))
				continue
			worst = maxi(worst, absi(massif.layer_at(column)
				- massif.layer_at(neighbor)))
	return worst


static func _hash(world_seed: int, salt: int, x: int, z: int) -> int:
	var value := world_seed * 73856093 ^ salt * 19349663 \
		^ x * 83492791 ^ z * 2971215073
	value = posmod(value, 2147483647)
	return value
