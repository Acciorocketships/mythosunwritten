extends GutTest

## The massif is the primary object of the mass-first pipeline: a deep,
## completely inhabited construction envelope grounded on terrain. It supplies
## the small-mountain silhouette; parcelization turns that mass into rooms and
## roofs, so no hidden stone substrate is permitted.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func _hill(world_seed: int = 0) -> Dictionary:
	return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 1, world_seed)


func test_massif_builds_a_terraced_layer_and_is_deterministic() -> void:
	var a := WarrenMassifBuilder.build(1, _hill())
	var b := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(a, WarrenMassifBuilder.last_failure)
	assert_true(a.is_sealed())
	assert_gte(a.vertical_development_bands(),
		WarrenVillageScaleProfile.review_fixture().minimum_core_bands,
		"the inhabited bell must reach its vertical-development floor")
	assert_lte(a.core_top_bands, WarrenMassif.BUILDABLE_LAYER_BANDS,
		"the compiler supports a finite eight-storey-plus-roof envelope")
	assert_gte(a.terrace_levels().size(), 5,
		"a smooth dome is not a terraced town silhouette")
	assert_lte(a.widest_plateau_cells(),
		WarrenMassifBuilder.plateau_cap(a.columns.size()),
		"wide flat plateaus read as empty platforms, not terraces")
	var worst_step := 0
	for column: Vector2i in a.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := column + direction
			if a.has_column(neighbor):
				worst_step = maxi(worst_step,
					absi(a.layer_at(column) - a.layer_at(neighbor)))
	assert_lte(worst_step, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"neighbouring columns must step like terraces, not cliffs")
	assert_eq(a.columns.size(), b.columns.size())
	for column: Vector2i in a.columns:
		assert_eq(a.top_at(column), b.top_at(column),
			"same seed must give identical column heights")


func test_massif_seeds_differ_and_respect_ground_bands() -> void:
	var hill := _hill()
	var base := WarrenMassifBuilder.build(1, hill)
	var raised_bands: Dictionary = {}
	for column: Vector2i in hill:
		raised_bands[column] = int(hill[column]) + 2
	var raised := WarrenMassifBuilder.build(1, raised_bands)
	assert_not_null(base, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(4, hill)
	for column: Vector2i in base.columns:
		if other.has_column(column) \
				and base.layer_at(column) != other.layer_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_eq(raised.base_at(column), int(hill[column]) + 2,
			"terrain ground bands lift the massif base")


func test_a_flat_site_still_builds_an_inhabited_town_mountain() \
		-> void:
	## Terrain decides where the town stands, not whether its architecture has a
	## silhouette. The inhabited envelope must create the mountain even on level
	## ground; natural relief then shifts each column's base without becoming
	## hidden structural mass.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var flat := WarrenMassifBuilder.build(world_seed,
			StampedGround.flat(WarrenMassifBuilder.RADIUS_CELLS + 1))
		assert_not_null(flat, "seed %d: %s" % [world_seed,
			WarrenMassifBuilder.last_failure])
		if flat == null:
			continue
		# TASK F1 RULING 4. The floor is the size profile's own
		# `minimum_core_bands`, which is what `_shape_gate_failure` enforces on
		# every built massif; the retired `MIN_CORE_BANDS := 16` described the
		# searched bore's requirement and nothing read it.
		assert_gte(flat.core_top_bands,
			WarrenVillageScaleProfile.review_fixture().minimum_core_bands)
		assert_eq(flat.bearing_at(Vector2i.ZERO), flat.base_at(Vector2i.ZERO),
			"the mountain is inhabited down to terrain")


func test_the_vertical_development_floor_is_the_profile_contract() -> void:
	## TASK F1 RULING 4. This test used to pin `MIN_CORE_BANDS := 16` against
	## the storey budget and against the searched bore's `MIN_SPAN_BANDS`.
	## Both are gone: the floor a massif is really held to is its size
	## profile's `minimum_core_bands`, and the ceiling is the buildable layer.
	## Every profile's floor must sit inside that envelope, which is the
	## property the retired constant was standing in for.
	for scale_id: StringName in WarrenVillageScaleProfile.IDS:
		var profile := WarrenVillageScaleProfile.for_id(scale_id)
		assert_gt(profile.minimum_core_bands, 0,
			"%s must state a vertical-development floor" % scale_id)
		assert_lte(profile.maximum_core_bands, WarrenMassif.BUILDABLE_LAYER_BANDS,
			"%s may not ask for more mass than the compiler builds" % scale_id)
		assert_lte(profile.minimum_core_bands, profile.maximum_core_bands,
			"%s has an inverted core-band range" % scale_id)


func _ground_frame(kind: String) -> Dictionary:
	## The input frames the retired searched-pipeline terrain report used, so the
	## suite and the measuring instrument describe the same ground.
	##
	## Every variation is laid ON the stamped hill rather than on band zero,
	## because the vertical-development gate is deliberately NOT ground-neutral
	## (it measures lowest ground to highest roof) while the SHAPE gates are --
	## and it is the shape gates this frame family exists to interrogate.
	var span := WarrenMassifBuilder.RADIUS_CELLS + 4
	var hill := StampedGround.hill(span)
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var column := Vector2i(x, z)
			var floor_band := int(hill.get(column, 0))
			match kind:
				"hill":
					bands[column] = floor_band
				"slope":
					bands[column] = floor_band + clampi((x + span) / 4, 0, 8)
				"steep":
					bands[column] = floor_band + x + span
				"terrace":
					bands[column] = floor_band \
						+ (0 if x <= -1 else (2 if x == 0 else 6))
				_:
					bands[column] = floor_band
	return bands


func test_gate_verdicts_are_invariant_under_the_ground_the_massif_stands_on() \
		-> void:
	## THE property this wave exists to pin. The massif authors a LAYER of mass
	## above whatever ground it is handed; the ground itself is the terrain's,
	## and the terrain renders it as slope or as dressed cliff. So a shape gate
	## that scores absolute column tops is charging the builder for the
	## landscape -- which is exactly why a smooth slope read as a 10-14 cell
	## plateau and a terraced frame as a 6-band cliff (terrain audit).
	##
	## Stamped on four inputs that differ by up to 44 bands of relief, including
	## one steeper than any terrain can legally produce: identical verdicts,
	## identical relative structure, cell for cell.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var flat := WarrenMassifBuilder.build(world_seed,
			_ground_frame("hill"))
		var flat_failure := WarrenMassifBuilder.last_failure
		for kind: String in ["slope", "steep", "terrace"]:
			var bands := _ground_frame(kind)
			var relief := WarrenMassifBuilder.build(world_seed, bands)
			assert_eq(relief == null, flat == null,
				("seed %d on %s ground: the verdict moved (%s vs flat %s); a " \
				+ "constant-thickness layer draped over relief must be " \
				+ "gate-neutral") % [world_seed, kind,
					WarrenMassifBuilder.last_failure, flat_failure])
			if flat == null or relief == null:
				continue
			assert_eq(relief.columns.size(), flat.columns.size(),
				"seed %d on %s ground: footprint changed" % [world_seed, kind])
			assert_eq(relief.core_top_bands, flat.core_top_bands,
				"seed %d on %s ground: core bands are relief-relative already, "
				% [world_seed, kind] + "so they must not move")
			assert_eq(relief.terrace_levels(), flat.terrace_levels(),
				"seed %d on %s ground: terrace levels moved" \
				% [world_seed, kind])
			assert_eq(relief.widest_plateau_cells(),
				flat.widest_plateau_cells(),
				"seed %d on %s ground: widest plateau moved" \
				% [world_seed, kind])
			for column: Vector2i in flat.columns:
				assert_true(relief.has_column(column),
					"seed %d on %s ground: column %s vanished" \
					% [world_seed, kind, column])
				assert_eq(relief.layer_at(column), flat.layer_at(column),
					"seed %d on %s ground: the layer at %s changed thickness" \
					% [world_seed, kind, column])
				assert_eq(relief.base_at(column), int(bands[column]),
					"seed %d on %s ground: column %s did not take its own " \
					% [world_seed, kind, column] + "input ground as its base")


func test_a_real_layer_cliff_still_fails_the_neighbour_step_gate() -> void:
	## Sabotage-proof for the neighbour-step gate: relief-relativity must not
	## have turned it off. Hand-built because the builder cannot produce an
	## illegal step by construction -- the point is that the GATE still sees one
	## when the layer, not the ground, is what steps.
	##
	## The fixture is a 5x5 pad of one-band rim with a tall column dead centre,
	## so the centre has all four neighbours and the missing-neighbour branch
	## cannot mask the result, while the rim contributes only one band. Run
	## twice: on flat ground, and with the tall column's ground sunk by exactly
	## its extra layer so every absolute top in the pad is equal. The old
	## absolute measure scored that second pad as perfectly level; the
	## relief-relative one still sees the cliff.
	var step := WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS + 2
	for cancelled: bool in [false, true]:
		var massif := WarrenMassif.new(7)
		for z in range(5):
			for x in range(5):
				var centre := x == 2 and z == 2
				var layer := 1 + step if centre else 1
				# `cancelled` sinks the tall column's ground by exactly its extra
				# layer, so every absolute top in the pad is 1 and the OLD
				# absolute measure scored the whole thing as flat.
				var base := -step if centre and cancelled else 0
				massif.columns[Vector2i(x, z)] = {
					"base": base, "top": base + layer, "terrace": layer,
				}
		var tallest_absolute_step := 0
		for column: Vector2i in massif.columns:
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				if massif.has_column(column + direction):
					tallest_absolute_step = maxi(tallest_absolute_step,
						absi(massif.top_at(column)
							- massif.top_at(column + direction)))
		if cancelled:
			assert_eq(tallest_absolute_step, 0,
				"the fixture must be flat in ABSOLUTE terms, or it proves "
				+ "nothing about relief-relativity")
		var worst := WarrenMassifBuilder._worst_neighbor_step(massif)
		assert_eq(worst, step,
			("a %d-band step in the authored layer is a cliff whether or not " \
			+ "the ground cancels it in absolute terms (cancelled=%s)") \
			% [step, cancelled])
		assert_gt(worst, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"the neighbour-step gate must still have teeth (cancelled=%s)" \
			% cancelled)


func test_a_real_layer_plateau_still_fails_the_plateau_gate() -> void:
	## The plateau gate's counterpart sabotage-proof, and its converse: a
	## constant-thickness layer laid on a STAIRCASE of ground is not a plateau
	## even though its absolute tops rise in lockstep, while a genuine
	## constant-LAYER slab is one however the ground beneath it moves.
	var wide := WarrenMassifBuilder.MAZE_MAX_PLATEAU_CELLS + 3
	var slab := WarrenMassif.new(8)
	for x in range(wide):
		slab.columns[Vector2i(x, 0)] = {"base": x, "top": x + 5, "terrace": 5}
	assert_eq(slab.widest_plateau_cells(), wide,
		"%d columns of identical layer thickness are one plateau however " \
		% wide + "much the ground under them climbs")
	assert_gt(slab.widest_plateau_cells(),
		WarrenMassifBuilder.MAZE_MAX_PLATEAU_CELLS,
		"the plateau gate must still have teeth")

	var terraced := WarrenMassif.new(9)
	for x in range(wide):
		# Layer thins by one band per column exactly as the ground rises by one:
		# every absolute top is 10, which the old measure scored as one wide
		# plateau and the audit observed on every slope.
		terraced.columns[Vector2i(x, 0)] = {
			"base": x, "top": 10, "terrace": 10 - x,
		}
	assert_eq(terraced.widest_plateau_cells(), 1,
		"columns of differing layer thickness are separate terraces even " \
		+ "when a rising ground makes their absolute tops equal")
	assert_eq(terraced.terrace_levels().size(), wide,
		"each distinct layer thickness is its own terrace level")


func test_the_layer_cap_bounds_the_inhabited_mountain() -> void:
	## Every addressed flank is real building mass from its own terrain base.
	## The finite recipe stack still caps the tallest possible house.
	var measured := 0
	for world_seed in [7, 11]:
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		assert_not_null(massif, WarrenMassifBuilder.last_failure)
		if massif == null:
			continue
		for column: Vector2i in massif.columns:
			measured += 1
			assert_eq(massif.bearing_at(column), massif.base_at(column),
				"seed %d: bearing must be the terrain datum" % world_seed)
			var storeys := maxi(0, (massif.layer_at(column)
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
				/ WarrenBuildingParcel.STOREY_BANDS)
			assert_lte(storeys, WarrenMassif.MAX_TERRACE_STOREYS,
				"seed %d: column %s exceeds the inhabited stack cap" % [
					world_seed, column])
	assert_gt(measured, 0, "the fixtures did not contain any massif columns")


func test_the_buildable_layer_is_derived_from_the_parcel_contract() -> void:
	## WarrenMassif deliberately restates the layer rather than importing the
	## parcel vocabulary, so this is the only thing stopping the two drifting.
	assert_eq(WarrenMassif.BUILDABLE_LAYER_BANDS,
		WarrenMassif.MAX_TERRACE_STOREYS * WarrenBuildingParcel.STOREY_BANDS
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
		"the buildable layer must be exactly MAX_TERRACE_STOREYS storeys "
		+ "plus one roof reservation")
	assert_eq(WarrenMassifBuilder.MAX_LAYER_BANDS,
		WarrenMassif.BUILDABLE_LAYER_BANDS,
		"the builder may not author a column taller than one buildable layer")
	assert_lte(WarrenMassifBuilder.MIN_LAYER_BANDS,
		WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"the rim must taper within one ordinary terrace riser")
	assert_eq(WarrenMassif.ADDRESS_BANDS,
		WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS,
		"the massif and the common public-realm contract must agree on "
		+ "what constitutes an inhabited street wall")
	assert_eq(WarrenVolumeEnvelope.DEFAULT_ADDRESS_BANDS,
		WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS,
		"envelopes must keep the published frontage bar exactly")
	var massif := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	for column: Vector2i in massif.columns:
		assert_lte(massif.layer_at(column), WarrenMassif.BUILDABLE_LAYER_BANDS,
			"the layer at %s is thicker than one buildable layer" % column)
		# No second construction datum: every authored band is inhabitable.
		assert_eq(massif.bearing_at(column), massif.base_at(column),
			"the bearing datum must be natural ground at %s: nothing the "
			% column + "fabric authors stands below the buildable layer")


func test_the_rim_steps_down_to_the_ground_like_every_other_terrace() -> void:
	## Empty ground beside a boundary column IS height zero, and the neighbour
	## step limit applies to it. Without that the rim was a legal 7-16 band
	## cliff (measured over seeds 0-39) which every remedy so far re-skinned --
	## timber, then stone -- rather than removed. With it the tallest continuous
	## vertical face anywhere in the solid is one riser, so a viewer never sees
	## more than MAX_NEIGHBOR_STEP_BANDS of unbroken wall before a setback,
	## whatever material later dresses it.
	for world_seed: int in [0, 1, 3, 5, 11, 18]:
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		assert_not_null(massif, "seed %d: %s" % [world_seed,
			WarrenMassifBuilder.last_failure])
		if massif == null:
			continue
		var tallest_rim := 0
		var tallest_face := 0
		for column: Vector2i in massif.columns:
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := column + direction
				# LAYER, not absolute top: the ground step between two columns
				# is the terrain's face to render, and charging it here is what
				# the relief-relative wave removed.
				var exposed := massif.layer_at(column) \
					if not massif.has_column(neighbor) \
					else massif.layer_at(column) - massif.layer_at(neighbor)
				if not massif.has_column(neighbor):
					tallest_rim = maxi(tallest_rim, exposed)
				tallest_face = maxi(tallest_face, exposed)
		assert_lte(tallest_rim, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"seed %d presents a %d-band cliff to the empty ground beside it" \
			% [world_seed, tallest_rim])
		assert_lte(tallest_face, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
			"seed %d has a %d-band continuous face" % [world_seed, tallest_face])


func test_seal_requires_single_connected_component_and_no_holes() -> void:
	var built := WarrenMassifBuilder.build(1, _hill())
	assert_not_null(built, WarrenMassifBuilder.last_failure)
	if built == null:
		return
	assert_true(built.is_sealed())
	assert_true(built._is_single_component(),
		"a solid massif must not be a scattered archipelago of columns")
	assert_eq(built._find_interior_hole(), null,
		"a solid massif must not have a puncture through its middle")


func test_seal_rejects_a_hand_built_disjoint_massif() -> void:
	var massif := WarrenMassif.new(99)
	for column: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		massif.columns[column] = {"base": 0, "top": 5, "terrace": 5}
	for column: Vector2i in [Vector2i(10, 10), Vector2i(11, 10)]:
		massif.columns[column] = {"base": 0, "top": 5, "terrace": 5}
	assert_false(massif.seal(),
		"two disjoint clusters must not seal as one solid massif")
	assert_ne(massif.last_rejection, "",
		"a rejected seal must explain why, like the sibling envelope class")


func test_seal_rejects_a_solid_block_with_a_multi_cell_interior_void() -> void:
	var massif := WarrenMassif.new(100)
	for z in range(5):
		for x in range(5):
			massif.columns[Vector2i(x, z)] = {"base": 0, "top": 5, "terrace": 5}
	# Two ADJACENT interior cells removed: every single missing cell still
	# has at least one missing neighbour, so a 4-neighbour-presence
	# heuristic never flags either of them, even though the pair together
	# forms one fully enclosed void with no path to the outside.
	massif.columns.erase(Vector2i(2, 2))
	massif.columns.erase(Vector2i(2, 3))
	assert_true(massif._is_single_component(),
		"the ring surrounding the void is still one connected component")
	assert_false(massif.seal(),
		"a fully enclosed multi-cell void must not seal as solid")
	assert_ne(massif.last_rejection, "",
		"a rejected seal must explain why, like the sibling envelope class")


# --- Phase E: the noise massif's clustered descent -------------------------
# The user's binding visual direction (2026-08-24): "the sides of the city are
# sheer multi-storey flat walls; I want it to naturally get lower towards the
# edges (while preventing it from being too noisy -- we still want clusters)".
# Three facts express it, measured on the four planner towns the plot and
# composition suites already solve, on the same FLAT frame those suites use.

## The four towns `test_warren_maze_plots` and `test_warren_maze_composition`
## solve. Same seeds, same profiles, so a silhouette measured here is the
## silhouette those suites' plots stand on.
const PLANNER_TOWNS: Array[Dictionary] = [
	{"seed": 12, "scale": &"compact"},
	{"seed": 4, "scale": &"compact"},
	{"seed": 3, "scale": &"standard"},
	{"seed": 9, "scale": &"standard"},
]

## A boundary column may present at most two storeys and one band of authored
## layer to the empty ground beside it. HARD pin (Phase E exit metric 1): this
## is the "sheer multi-storey wall" the direction names, and one band of slack
## above two storeys is there so a quantized terrace plus a parity band is not
## a violation while a third storey is.
const RIM_WALL_CEILING_BANDS := 2 * WarrenBuildingParcel.STOREY_BANDS + 1

## Equal-layer 4-connected regions per town, and their mean size. Mean cluster
## size is what separates "clusters" from "per-column noise": a dithered field
## scores near 1, a terraced one scores its terrace arcs.
##
## MEASURED, planner towns, before the noise massif -> after:
## 12/compact 2.59 -> 2.52, 4/compact 2.67 -> 3.47, 3/standard 3.65 -> 3.65,
## 9/standard 3.32 -> 4.85; over the whole 24-town corpus the mean of the means
## goes 3.12 -> 3.83, the best town 3.69 -> 5.41 and the worst 2.59 -> 2.52.
##
## The FLOOR is pinned at the measured worst minus a guard step, not at the
## plan's 4.0. Two of the four planner towns clear 4.0 and the two compact ones
## do not, and the reason is geometry rather than tuning: a compact footprint is
## 8-11 columns across, so its crown is 4-5 columns from open ground while its
## scale profile demands a 12-15 band core, which is 1.7-2.0 storeys of descent
## per column -- at or against WarrenMassifBuilder.MAX_STEP_TERRACES. At that
## grade every column is a mandatory riser between the two beside it and no
## terrace can be more than one column wide. Widening the descent needs a wider
## footprint, which is WarrenVillageScaleProfile's decision. Re-pin upward when
## it is made.
## Where each planner town's WIDEST equal-layer terrace lands, measured and
## pinned two-sidedly with a guard of WIDEST_TERRACE_GUARD columns either side.
## Measured under the noise massif: 12/compact 11, 4/compact 11, 3/standard 14,
## 9/standard 21 columns. The maze plateau cap (16, or a sixth of the town) is
## the ceiling the BUILDER enforces; this is the band the field actually
## occupies, and it is the only form of the fact a test can falsify -- see the
## comment at the assertion.
const WIDEST_TERRACE_GUARD := 3
const PLANNER_WIDEST_TERRACE: Dictionary = {
	"12/compact": Vector2i(11 - WIDEST_TERRACE_GUARD,
		11 + WIDEST_TERRACE_GUARD),
	"4/compact": Vector2i(11 - WIDEST_TERRACE_GUARD,
		11 + WIDEST_TERRACE_GUARD),
	"3/standard": Vector2i(14 - WIDEST_TERRACE_GUARD,
		14 + WIDEST_TERRACE_GUARD),
	"9/standard": Vector2i(21 - WIDEST_TERRACE_GUARD,
		21 + WIDEST_TERRACE_GUARD),
}

const TERRACE_CLUSTER_COUNT_FLOOR := 2
const TERRACE_CLUSTER_MEAN_FLOOR := 2.25
## The plan's target, reported per town rather than asserted -- see the floor
## above for why it is not the gate.
const TERRACE_CLUSTER_MEAN_TARGET := 4.0

## The same measure over the WHOLE 24-town corpus rather than the four planner
## towns: the mean of every town's own mean cluster size. Measured 3.83 (the
## route-first flood fill scored 3.12 on the same corpus), pinned a guard step
## under it. A per-town floor can be held hostage by the two compact towns
## where the grade binds; this one moves when the field moves.
const CORPUS_CLUSTER_MEAN_FLOOR := 3.5


func _planner_massif(town: Dictionary,
		ground_bands: Dictionary = {}) -> WarrenMassif:
	var profile := WarrenVillageScaleProfile.for_id(StringName(town["scale"]))
	return WarrenMassifBuilder.build(int(town["seed"]), ground_bands, profile)


func _maze_plateau_cap(column_count: int) -> int:
	return WarrenMassifBuilder.plateau_cap(column_count)


func _planner_label(town: Dictionary) -> String:
	return "%d/%s" % [int(town["seed"]), String(town["scale"])]


func _layer_clusters(massif: WarrenMassif) -> Array[int]:
	## Sizes of the 4-connected regions sharing one authored LAYER thickness --
	## `widest_plateau_cells()`'s own partition, reported whole instead of only
	## at its maximum. Sorted iteration so the sizes are deterministic.
	var order: Array[Vector2i] = []
	order.assign(massif.columns.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var visited: Dictionary = {}
	var sizes: Array[int] = []
	for start: Vector2i in order:
		if visited.has(start):
			continue
		var level := massif.layer_at(start)
		var frontier: Array[Vector2i] = [start]
		visited[start] = true
		var count := 0
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			count += 1
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := cell + direction
				if visited.has(neighbor) or not massif.has_column(neighbor) \
						or massif.layer_at(neighbor) != level:
					continue
				visited[neighbor] = true
				frontier.append(neighbor)
		sizes.append(count)
	return sizes


func _step_histogram(massif: WarrenMassif) -> Dictionary:
	## Every 4-neighbour pair of present columns, counted by how many TERRACES
	## apart the two stand. Each pair once (RIGHT and DOWN only), so the shares
	## are shares of edges and not of half-edges.
	##
	## This is the observable form of the descent grade: a town whose ramp runs
	## at the neighbour-step gate's maximum spends nearly every edge on a
	## two-terrace riser and has none left over for a flat, while a gentle town
	## spends most of them at zero or one.
	var counts: Dictionary = {}
	var total := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := column + direction
			if not massif.has_column(neighbor):
				continue
			var step := absi(massif.layer_at(column)
				- massif.layer_at(neighbor)) / WarrenBuildingParcel.STOREY_BANDS
			counts[step] = int(counts.get(step, 0)) + 1
			total += 1
	counts["total"] = total
	return counts


func _terrace_ladder(massif: WarrenMassif) -> Dictionary:
	## layer thickness -> how many columns carry it. The town's silhouette as a
	## histogram, which is what "the silhouettes measurably differ" measures.
	var ladder: Dictionary = {}
	for column: Vector2i in massif.columns:
		var layer := massif.layer_at(column)
		ladder[layer] = int(ladder.get(layer, 0)) + 1
	return ladder


func test_the_rim_wall_is_never_a_sheer_multi_storey_face() -> void:
	## PHASE E EXIT METRIC 1, hard. Every column on the footprint boundary --
	## the ones a viewer standing outside the town actually sees -- stands at
	## most two storeys and a band above its own terrain. Measured as LAYER, so
	## a town on a hillside is judged on what the builder authored and not on
	## the hill it was authored over.
	for town: Dictionary in PLANNER_TOWNS:
		var massif := _planner_massif(town)
		assert_not_null(massif, "%s: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		if massif == null:
			continue
		var tallest := 0
		var offenders := 0
		for column: Vector2i in massif.columns:
			var boundary := false
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				if not massif.has_column(column + direction):
					boundary = true
					break
			if not boundary:
				continue
			tallest = maxi(tallest, massif.layer_at(column))
			if massif.layer_at(column) > RIM_WALL_CEILING_BANDS:
				offenders += 1
		gut.p("%s: tallest rim wall %d bands (%d over the ceiling)" % [
			_planner_label(town), tallest, offenders])
		assert_lte(tallest, RIM_WALL_CEILING_BANDS,
			("%s presents a %d-band rim wall; the town must step down to its " \
			+ "own edge, not stand on one") % [_planner_label(town), tallest])


func test_the_terraces_are_clusters_and_not_per_column_noise() -> void:
	## PHASE E EXIT METRIC 2. "We still want clusters": neighbouring columns
	## must mostly SHARE a terrace, so the silhouette reads as a handful of
	## stepped districts rather than as a field of individually-heighted
	## columns. Both halves are measured-first floors.
	for town: Dictionary in PLANNER_TOWNS:
		var massif := _planner_massif(town)
		assert_not_null(massif, "%s: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		if massif == null:
			continue
		var sizes := _layer_clusters(massif)
		var singles := 0
		var total := 0
		for size: int in sizes:
			total += size
			if size == 1:
				singles += 1
		var mean := float(total) / float(maxi(1, sizes.size()))
		gut.p(("%s: %d columns in %d terrace clusters, mean %.2f, %d single " \
			+ "columns, widest %d") % [_planner_label(town), total,
			sizes.size(), mean, singles, massif.widest_plateau_cells()])
		# THE DESCENT GRADE, as steps. Reported, never pinned: how steep a town
		# is allowed to look is Phase G's battery to judge, and the controller
		# ruled (2026-08-23) that compact's two-terrace risers are measured
		# here rather than changed. A share of two-terrace edges near 1.0 is a
		# town spending every column on a riser, which is exactly why its
		# terraces cannot be wider than one column.
		var steps := _step_histogram(massif)
		var edges := int(steps.get("total", 0))
		gut.p(("  steps over %d neighbour pairs: 0 terraces %.3f, " \
			+ "1 terrace %.3f, 2 terraces %.3f") % [edges,
			float(int(steps.get(0, 0))) / float(maxi(1, edges)),
			float(int(steps.get(1, 0))) / float(maxi(1, edges)),
			float(int(steps.get(2, 0))) / float(maxi(1, edges))])
		assert_gte(sizes.size(), TERRACE_CLUSTER_COUNT_FLOOR,
			"%s has %d terrace clusters; a town needs several" % [
				_planner_label(town), sizes.size()])
		assert_gte(mean, TERRACE_CLUSTER_MEAN_FLOOR,
			("%s averages %.2f columns per terrace cluster: that is " \
			+ "per-column noise, not the clustered descent the direction " \
			+ "asks for") % [_planner_label(town), mean])
		if mean < TERRACE_CLUSTER_MEAN_TARGET:
			gut.p(("%s is under the plan's %.1f target at %.2f -- expected " \
				+ "on a town whose descent grade is against the step gate") \
				% [_planner_label(town), TERRACE_CLUSTER_MEAN_TARGET, mean])
		# TWO-SIDED, AND MEASURED. Asserting the builder's own plateau CAP here
		# proves nothing: `_shape_gate_failure` refuses a field over the cap
		# before `build` ever returns one, so the assertion could only fire on a
		# massif that cannot exist. What can drift, silently and in either
		# direction, is where inside the cap the widest terrace actually lands:
		# a field that started fusing would climb towards the cap, and one that
		# started dithering would collapse towards one. Both are red here.
		var widest := massif.widest_plateau_cells()
		var band: Vector2i = PLANNER_WIDEST_TERRACE.get(_planner_label(town),
			Vector2i(1, _maze_plateau_cap(massif.columns.size())))
		assert_between(widest, band.x, band.y,
			("%s's widest terrace is %d columns, outside the measured %d-%d " \
			+ "band: the field is fusing terraces or thinning them") % [
				_planner_label(town), widest, band.x, band.y])


func test_the_planner_towns_have_measurably_different_silhouettes() -> void:
	## PHASE E EXIT METRIC 3. Four seeds, four silhouettes: the tallest layer
	## and the whole terrace ladder are compared pairwise, and at least one
	## histogram bin must differ in every pair. A field that collapsed to one
	## authored profile would pass every shape gate above and fail here.
	var ladders: Array[Dictionary] = []
	var peaks: Array[int] = []
	for town: Dictionary in PLANNER_TOWNS:
		var massif := _planner_massif(town)
		assert_not_null(massif, "%s: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		if massif == null:
			return
		var ladder := _terrace_ladder(massif)
		var levels: Array = ladder.keys()
		levels.sort()
		var printed := PackedStringArray()
		for level: int in levels:
			printed.append("%d:%d" % [level, int(ladder[level])])
		gut.p("%s: peak %d bands, ladder %s" % [_planner_label(town),
			massif.core_top_bands, " ".join(printed)])
		ladders.append(ladder)
		peaks.append(massif.core_top_bands)
	for i in range(ladders.size()):
		for j in range(i + 1, ladders.size()):
			var differs := false
			var bins: Dictionary = {}
			for level: int in ladders[i]:
				bins[level] = true
			for level: int in ladders[j]:
				bins[level] = true
			for level: int in bins:
				if int(ladders[i].get(level, 0)) \
						!= int(ladders[j].get(level, 0)):
					differs = true
					break
			assert_true(differs,
				"%s and %s carry identical terrace ladders" % [
					_planner_label(PLANNER_TOWNS[i]),
					_planner_label(PLANNER_TOWNS[j])])
	# The four planner towns happen to share a peak height (14 bands at the
	# time of writing) while carrying four different ladders: the crown is the
	# one band the scale profile pins hardest, so peak-to-peak variation lives
	# across SCALES and rolls rather than inside one planner quartet, measured
	# over the corpus -- which the massif alone is cheap enough to build whole.
	var peak_set: Dictionary = {}
	var corpus_means := 0.0
	var corpus_towns := 0
	for world_seed in range(1, 13):
		for scale: StringName in [&"compact", &"standard"]:
			var town := {"seed": world_seed, "scale": scale}
			var massif := _planner_massif(town)
			if massif == null:
				continue
			peak_set[massif.core_top_bands] = true
			var sizes := _layer_clusters(massif)
			var total := 0
			for size: int in sizes:
				total += size
			corpus_means += float(total) / float(maxi(1, sizes.size()))
			corpus_towns += 1
	var distinct_peaks: Array = peak_set.keys()
	distinct_peaks.sort()
	gut.p("planner peaks %s; corpus peaks %s" % [str(peaks),
		str(distinct_peaks)])
	assert_gte(distinct_peaks.size(), 2,
		"every town in the corpus peaks at exactly the same height (%s)" \
			% str(distinct_peaks))
	# The four planner towns are two compact and two standard, and the compact
	# pair is where the grade binds -- so a per-town floor alone can be held
	# hostage by the two hardest towns while the field quietly gets worse
	# everywhere else. This is the whole corpus's mean of means, which moves
	# when the FIELD moves rather than when one town does.
	assert_eq(corpus_towns, 24, "the corpus massif sweep lost a town")
	var corpus_mean := corpus_means / float(maxi(1, corpus_towns))
	gut.p("corpus mean of terrace-cluster means %.2f over %d towns" % [
		corpus_mean, corpus_towns])
	assert_gte(corpus_mean, CORPUS_CLUSTER_MEAN_FLOOR,
		("the corpus averages %.2f columns per terrace cluster against a " \
		+ "measured floor of %.2f") % [corpus_mean,
			CORPUS_CLUSTER_MEAN_FLOOR])


func test_the_maze_massif_is_deterministic_and_relief_neutral() -> void:
	## PHASE E, inside the mode bracket. Two promises of the interface that no
	## silhouette metric can see, so nothing else in this file would catch them
	## breaking.
	##
	## DETERMINISM. The field is a pure function of (seed, ground, profile): the
	## noise is seeded through this repository's own integer hash rather than
	## any engine noise class, and every pass over the field iterates a sorted
	## column order rather than a Dictionary's insertion order. A second build
	## must therefore agree CELL FOR CELL, not merely in aggregate -- an
	## order-dependent merge would still produce the same cluster mean.
	##
	## RELIEF NEUTRALITY. `ground_bands` relief adds UNDER the authored layer
	## exactly as it does under the route-first profile (controller ruling 2).
	## The route-first tests above pin this for the flood fill; the terraced
	## field has to earn it separately, because its ramp is driven by DEPTH and
	## an implementation that reached for the ground instead would pass every
	## other test in this file.
	var bands := _ground_frame("slope")
	for town: Dictionary in PLANNER_TOWNS:
		var flat := _planner_massif(town)
		var again := _planner_massif(town)
		var sloped := _planner_massif(town, bands)
		assert_not_null(flat, "%s: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		assert_not_null(again, "%s rebuilt: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		assert_not_null(sloped, "%s on slope: %s" % [_planner_label(town),
			WarrenMassifBuilder.last_failure])
		if flat == null or again == null or sloped == null:
			continue
		assert_eq(again.columns.size(), flat.columns.size(),
			"%s: the footprint moved between two builds" % _planner_label(town))
		assert_eq(sloped.columns.size(), flat.columns.size(),
			"%s: the ground moved the footprint" % _planner_label(town))
		var relief := sloped.relief_bands()
		assert_gt(relief, 0,
			("%s: the sloped fixture handed the massif %d bands of relief, so " \
			+ "it proves nothing") % [_planner_label(town), relief])
		gut.p("%s: rebuilt identical, %d bands of relief under the field" % [
			_planner_label(town), relief])
		for column: Vector2i in flat.columns:
			assert_eq(again.top_at(column), flat.top_at(column),
				"%s: column %s differs between two builds of one seed" % [
					_planner_label(town), column])
			assert_true(sloped.has_column(column),
				"%s: column %s vanished on sloped ground" % [
					_planner_label(town), column])
			assert_eq(sloped.layer_at(column), flat.layer_at(column),
				("%s: the layer at %s changed thickness when the ground " \
				+ "moved under it") % [_planner_label(town), column])
			assert_eq(sloped.base_at(column), int(bands[column]),
				"%s: column %s did not take its own input ground as its base" \
					% [_planner_label(town), column])
