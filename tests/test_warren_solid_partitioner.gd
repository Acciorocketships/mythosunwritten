extends GutTest

## Partition audits (spec §3): every carved flank face belongs to a house;
## footprints stay in the 1x1..2x3 family; tops follow the terraced massif.
##
## Building a massif and boring a route costs seconds per seed, so every town
## is built once and shared by the whole suite. The partition under test is
## rebuilt per call where a test needs a pristine (unsealed) copy.

## Every seed the report tabulates, so the table is reproducible from the
## suite. Seven towns cost roughly 15s; seeds 2 and 7 are rejected by the
## carver and seed 8 by the massif builder, so they are not in the corpus.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func _hill(world_seed: int = 0) -> Dictionary:
	## Exercise partition ownership on the shared settlement-relief fixture. The
	## massif contributes the inhabited height; terrain remains the true bearing
	## datum beneath every parcel.
	return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4, world_seed)


const CORPUS: Array[int] = [1, 3, 4, 5, 6, 9, 11]
## Seeds whose whole mass-first frontier is built, so the parcel stage can be
## audited against the volume production actually hands it -- arcade and
## gallery walk cells included. Three towns cost roughly 45s, which is why this
## is a short list rather than CORPUS.
## Kept deliberately short because each member composes the whole mass-first
## frontier. This is a seed-supply sample, not an exact output pin.
const FRONTIER_CORPUS: Array[int] = [7, 20]
## Deliberately stricter than WarrenSolidPartitioner's own admission rule and
## derived without calling it: two full storeys of unexcavated solid above the
## street floor, on unexcavated ground. Anything this obviously buildable is a
## wall the partition may not leave to nobody.
const STRICT_WALL_BANDS := 6
## Fill sites the partition may leave standing across FRONTIER_CORPUS, and only
## for the one declared reason: an optional house is never placed when its roof
## cannot join a neighbour's or when it would meet one across a corner.
## A bounded residue, not a target. An infill house is optional when its roof
## cannot join a neighbor or it would create a corner-only contact; accepted
## production frontiers must keep that residue small.
const MEASURED_UNJOINABLE_FILL_SITES := 20
## Houses across CORPUS whose street is cut BELOW their own terrace, leaving
## them nothing to descend to and more than a terrace's worth of solid above.
## A MEASURED TRIPWIRE, NOT A TARGET: shortening them means capping `_top_band`,
## which the no-straddle rule turns into stranded street walls.
const MEASURED_UNDESCENDED_TALL_HOUSES := 8
## The furthest a 2x3 footprint can reach from the walk cell that addresses it:
## three columns of depth, or two of depth and one of width. Used only as a
## generous upper bound on where a bridge over a street could be addressed from.
const BRIDGE_REACH_CELLS := 3

var _towns: Dictionary = {}
var _frontier_towns: Dictionary = {}


func _excavation(world_seed: int, massif: WarrenMassif) -> WarrenExcavation:
	## Production owns a deterministic bounded bore family. Partition tests need
	## one sealed input from that family, not a permanently privileged first bore
	## whose legality changes when the inhabited depth changes.
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var result := WarrenExcavationCarver.carve(world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if result != null:
			return result
	return null


func test_partition_owns_every_route_flank() -> void:
	var massif := WarrenMassifBuilder.build(1, _hill())
	var excavation := _excavation(1, massif)
	assert_not_null(excavation, WarrenExcavationCarver.last_failure)
	var parcels := WarrenSolidPartitioner.partition(massif, excavation)
	assert_gt(parcels.size(), 9,
		"a town needs 10+ houses: %s" % WarrenSolidPartitioner.last_failure)
	var unowned := WarrenSolidPartitioner.unowned_route_faces(parcels,
		excavation, massif)
	assert_eq(unowned, [] as Array[Vector3i],
		"route faces without an owning house: %s" % str(unowned))
	for parcel: WarrenBuildingParcel in parcels:
		assert_between(parcel.footprint.size(), 1, 6,
			"footprints stay in the 1x1..2x3 family")
		assert_gt(parcel.top_band, parcel.base_band + 1,
			"terraced houses are at least one storey")


func test_every_obviously_buildable_street_wall_is_owned_at_street_level() \
		-> void:
	## The load-bearing claim, checked WITHOUT asking the partitioner what it
	## thinks a wall is. Walls are re-derived here straight from the route and
	## the massif; each must be occupied by a house AT the street's own floor
	## band, because a house that owns the column but starts a terrace higher
	## leaves the same hole in the street wall as one that was never built.
	##
	## Where the route passes one column twice inside a single envelope's
	## height the two walls compete, and the upper house wins (it is the one
	## that can be rooted without undercutting the other). That leftover is
	## trimmed to a plinth, so the lower wall may go unhoused -- but the column
	## must still carry a house above it, never nothing at all.
	var corpus_walls := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var owned := _owned_cells(town["parcels"] as Array[WarrenBuildingParcel])
		var columns := _owned_columns(
			town["parcels"] as Array[WarrenBuildingParcel])
		var walls := _strict_walls(town["massif"] as WarrenMassif,
			town["excavation"] as WarrenExcavation)
		# Sample-size guard accumulated across the corpus. STRICT_WALL_BANDS is
		# two full storeys of unexcavated inhabited solid above a street floor;
		# the deep bell supplies many such walls, but route shape still makes a
		# per-seed minimum unnecessarily brittle.
		corpus_walls += walls.size()
		for wall: Vector3i in walls:
			if owned.has(wall):
				continue
			var column := Vector2i(wall.x, wall.z)
			assert_true(columns.has(column),
				("seed %d: wall %s is owned by nobody at any height, so the " \
				+ "street has a gap rather than a plinth") % [world_seed, wall])
			var highest := -1
			for band: int in columns.get(column, [] as Array[int]) as Array[int]:
				highest = maxi(highest, band)
			assert_gt(highest, wall.y,
				("seed %d: wall %s is unhoused but nothing stands above it " \
				+ "either") % [world_seed, wall])
	assert_gt(corpus_walls, 12,
		"only %d strictly-buildable street walls across the corpus -- too "
		% corpus_walls + "few to prove anything")


func test_street_wall_audit_classifies_every_wall_independently() -> void:
	## The audit is the gate Task 6 runs, so it has to be worth trusting. Two
	## claims here: it accounts for every raw street wall exactly once (no wall
	## quietly dropped between buckets), and its exclusions are real rather
	## than a way of agreeing with the partitioner -- the kerb bucket must be
	## substantial, because the terraced rim genuinely cannot hold houses.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var audit := WarrenSolidPartitioner.street_wall_audit(
			town["parcels"] as Array[WarrenBuildingParcel],
			town["excavation"] as WarrenExcavation,
			town["massif"] as WarrenMassif)
		var tally := int(audit["owned_count"])
		for bucket: String in ["plinth", "kerb", "undermined", "short",
				"unowned"]:
			tally += (audit[bucket] as Array[Vector3i]).size()
		assert_eq(tally, int(audit["wall_count"]),
			"seed %d: buckets must account for every wall exactly once" \
			% world_seed)
		# These are sabotage floors, not targets: the deep inhabited bell should
		# expose a substantial wall corpus and the partition must turn a useful
		# share of it into actual houses.
		assert_gt(int(audit["wall_count"]), 45,
			"seed %d: too few raw walls to prove anything" % world_seed)
		assert_gt(int(audit["owned_count"]), 12,
			"seed %d: only %d walls are housed" % [world_seed,
				int(audit["owned_count"])])
		assert_eq((audit["unowned"] as Array[Vector3i]).size(), 0,
			"seed %d: real gaps in the street wall: %s" % [world_seed,
				str((audit["unowned"] as Array[Vector3i]).slice(0, 6))])
		assert_gt((audit["kerb"] as Array[Vector3i]).size(), 0,
			("seed %d: no kerbs at all means the audit is measuring the " \
			+ "partitioner rather than the solid") % world_seed)


func test_parcels_satisfy_the_whole_downstream_parcel_contract() -> void:
	## Task 6 hands these parcels to WarrenParcelPlan, which rejects any that
	## is unsealed, whose door does not open onto its claimed walk, or that is
	## visually short. Proving that here, against the real adapted volume plan,
	## is what stops a partition bug from surfacing three stages away.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var plan := town["plan"] as WarrenVolumePlan
		var parcels := WarrenSolidPartitioner.partition(
			town["massif"] as WarrenMassif,
			town["excavation"] as WarrenExcavation, plan)
		assert_gt(parcels.size(), 9, "seed %d: %s" % [world_seed,
			WarrenSolidPartitioner.last_failure])
		for parcel: WarrenBuildingParcel in parcels:
			assert_true(parcel.is_sealed(),
				"seed %d: parcel %s did not seal" % [world_seed,
					parcel.stable_id])
			assert_true(WarrenParcelConstruction.door_serves_address(parcel),
				("seed %d: parcel %s door does not open onto walk %s") \
				% [world_seed, parcel.stable_id, parcel.address_walk_cell])
			var threshold := WarrenParcelConstruction.threshold_cell(parcel)
			var landing := threshold + Vector3i(parcel.frontage_direction.x, 0,
				parcel.frontage_direction.y)
			assert_true(plan.has_exact_route_surface(landing),
				("seed %d: parcel %s door opens into swept headroom rather than " \
				+ "onto exact public floor at %s") % [world_seed,
					parcel.stable_id, landing])
			# has_frontage(), not has_walk(): a parcel may legitimately address
			# a STAIR/RAMP intermediate stride cell, which is real excavated
			# street ground WarrenSolidPartitioner always rooted houses at, but
			# which cannot be a walk_cells graph node (its ground already
			# belongs exclusively to that transition's public-realm surface).
			# WarrenParcelPlan.seal() itself gates on has_frontage() via
			# detached_parcel_count, so this is the same downstream contract,
			# not a weaker stand-in for it.
			assert_true(plan.has_frontage(parcel.address_walk_cell),
				("seed %d: parcel %s addresses a cell with no recognised " \
				+ "frontage") % [world_seed, parcel.stable_id])
			# Production's own rule, called through production's own predicate
			# rather than restated here as a storey count. The storey form was
			# only ever a proxy for it and it counted a room the storey-parity
			# fudge had buried under the terrain, which is why it could not
			# survive honest grounding -- see
			# WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS and the
			# equivalence test in this suite.
			assert_false(WarrenParcelizer._is_visually_short(parcel),
				("seed %d: parcel %s builds as a visually short house (%d "
				+ "bands of apparent face), which production forbids")
				% [world_seed, parcel.stable_id,
				WarrenParcelConstruction.apparent_face_bands(parcel)])


func test_a_partition_that_claims_joinable_roofs_really_compiles() -> void:
	## The acceptance test for the whole junction-awareness rule, judged by the
	## REAL classifier and module table rather than this class's cheap
	## restatement of them. A partition whose roofs cannot be joined composes
	## into nothing, and before this rule existed that was nearly every seed.
	##
	## The claim checked is one-directional on purpose. `_pair_can_meet` is
	## deliberately STRICTER than the table -- it refuses every perpendicular
	## valley, including the few the table would accept -- so a partition may
	## report a conflict the table would have tolerated. What must never happen
	## is the reverse: reporting zero unjoinable roofs and then failing to
	## compile, which is what a drifted derivation would look like.
	var clean := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var proposals := _proposals(world_seed)
		assert_gt(proposals.size(), 9,
			"seed %d: no proposals to classify" % world_seed)
		var topology := FabricRoofTopologyPlan.build(proposals)
		assert_not_null(topology,
			"seed %d: roof topology could not classify the partition" \
			% world_seed)
		if topology == null:
			continue
		assert_gt(int(topology.audit.junction_count), 0,
			("seed %d: a partition whose roofs touch nothing cannot prove " \
			+ "anything about joining them") % world_seed)
		var compiles := not FabricRoofJunctionModuleTable.build(proposals,
			topology).is_empty()
		clean += int(compiles)
		if int(town["unjoinable"]) != 0:
			continue
		assert_true(compiles,
			("seed %d: partition reported every roof joinable, but the module " \
			+ "table rejects it: %s") % [world_seed,
				FabricRoofJunctionModuleTable.last_failure])
	## Raw partitions may expose a vocabulary gap; the frontier drops them. This
	## sample-size guard only proves the real table was exercised successfully at
	## least once, while the one-directional assertion above is the invariant.
	assert_gt(clean, 0,
		"no raw corpus partition compiled through the real roof module table")


func test_equal_roof_bands_never_meet_across_a_corner() -> void:
	## The rule the partitioner enforces, checked independently of the code that
	## enforces it: re-derives adjacency and the authored ridge direction from
	## the parcels and
	## asserts no two houses share a roof band across a corner, because a
	## perpendicular valley between the width-one houses the leftover solid
	## mostly yields has no recipe at all. Together with the test above this
	## pins both halves -- that the rule holds, and that holding it is what
	## makes the real module table accept the plan.
	##
	## Do not compare frontage axes directly. The broad/shallow `row` family
	## deliberately turns its ridge ninety degrees so its broad street facade is
	## an eave; two legal row contacts can therefore have perpendicular frontage
	## while their authored ridges remain parallel.
	var equal_pairs := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var parcels := town["parcels"] as Array[WarrenBuildingParcel]
		var corners := 0
		var corner_details := PackedStringArray()
		for left_index in parcels.size():
			for right_index in range(left_index + 1, parcels.size()):
				var left := parcels[left_index]
				var right := parcels[right_index]
				if left.top_band != right.top_band \
						or not _footprints_touch(left.footprint,
							right.footprint):
					continue
				equal_pairs += 1
				var left_ridge := _parcel_ridge(left)
				var right_ridge := _parcel_ridge(right)
				if (left_ridge.x == 0) != (right_ridge.x == 0):
					corners += 1
					corner_details.append("%s(%s,%s) <> %s(%s,%s)" % [
						left.stable_id,
						_parcel_shape(left), left_ridge,
						right.stable_id,
						_parcel_shape(right), right_ridge])
		if int(town["unjoinable"]) != 0:
			# One house with no joinable roof can abut two neighbours, so the
			# reported count bounds the houses involved, not the pairs. What
			# must hold is that a partition claiming success has no corners.
			continue
		assert_eq(corners, 0,
			("seed %d: %d equal-height corner pairs in a partition that " \
			+ "reported every roof joinable: %s") % [world_seed, corners,
				str(corner_details)])
	assert_gt(equal_pairs, 0,
		("no equal-height neighbours anywhere in the corpus would mean this " \
		+ "rule passes by forbidding every terrace row"))


func test_building_contact_metric_is_invariant_under_subdivision() -> void:
	## The property the construction gate's contact metric must have, pinned
	## directly rather than inferred from a seed's score.
	##
	## Splitting one wide house into two adjacent narrow ones covering the same
	## columns changes nothing about the urban mass -- the same cells stand in
	## the same connected run -- so a metric that moves under that split is
	## measuring subdivision granularity, not connectedness. That is exactly how
	## the old parcel-count ratio failed mass-first, which divides the same
	## solid into roughly twice as many houses as route-first.
	##
	## Same mass, same connectivity, two subdivisions: one 4-cell house joined
	## to a 2-cell neighbour, and the 4-cell house split into two 2-cell halves.
	var coarse: Array[Array] = [[&"a", &"b"] as Array, [&"lone"] as Array]
	var coarse_areas := {&"a": 4, &"b": 2, &"lone": 3}
	var fine: Array[Array] = [[&"a1", &"a2", &"b"] as Array, [&"lone"] as Array]
	var fine_areas := {&"a1": 2, &"a2": 2, &"b": 2, &"lone": 3}
	var coarse_ratio := WarrenParcelPlan.largest_contact_cell_ratio(coarse,
		coarse_areas)
	var fine_ratio := WarrenParcelPlan.largest_contact_cell_ratio(fine,
		fine_areas)
	assert_almost_eq(fine_ratio, coarse_ratio, 0.0001,
		("subdividing a house must not move the contact metric: %f became %f") \
		% [coarse_ratio, fine_ratio])
	assert_almost_eq(coarse_ratio, 6.0 / 9.0, 0.0001,
		"six of nine built cells stand in the largest connected run")
	## And it must still fail a town that really is scattered: the same eight
	## built cells, but as four detached pavilions with nothing touching.
	var scattered: Array[Array] = [[&"a1"] as Array, [&"a2"] as Array,
		[&"b"] as Array, [&"lone"] as Array]
	var scattered_areas := {&"a1": 2, &"a2": 2, &"b": 2, &"lone": 2}
	assert_lt(WarrenParcelPlan.largest_contact_cell_ratio(scattered,
			scattered_areas), 0.33,
		"a town of detached pavilions must still miss the gate")


func test_isolated_building_metric_is_invariant_under_subdivision() -> void:
	## The isolates gate needs the same property for the same reason: it used to
	## cap the COUNT of detached buildings, so dividing the same mass more
	## finely spent the allowance faster without changing the town.
	##
	## Same mass, same connectivity: a 4-cell detached house beside a joined
	## pair, then that same joined pair divided into three.
	var coarse: Array[Array] = [[&"a", &"b"] as Array, [&"lone"] as Array]
	var coarse_areas := {&"a": 4, &"b": 2, &"lone": 4}
	var fine: Array[Array] = [[&"a1", &"a2", &"b"] as Array, [&"lone"] as Array]
	var fine_areas := {&"a1": 2, &"a2": 2, &"b": 2, &"lone": 4}
	assert_almost_eq(WarrenParcelPlan.isolated_cell_ratio(fine, fine_areas),
		WarrenParcelPlan.isolated_cell_ratio(coarse, coarse_areas), 0.0001,
		"subdividing a joined house must not move the isolates metric")
	assert_almost_eq(WarrenParcelPlan.isolated_cell_ratio(coarse,
			coarse_areas), 0.4, 0.0001,
		"four of ten built cells stand in a building that touches nothing")
	## A town of detached pavilions still scores high, which is the property the
	## gate exists to enforce.
	var scattered: Array[Array] = [[&"a"] as Array, [&"b"] as Array,
		[&"lone"] as Array]
	assert_almost_eq(WarrenParcelPlan.isolated_cell_ratio(scattered,
			coarse_areas), 1.0, 0.0001,
		"a town where nothing touches is entirely isolated mass")


func test_no_two_houses_meet_only_at_a_corner() -> void:
	## Diagonal neighbours are the one arrangement the compiled vocabulary
	## cannot express. SettlementFabricPlan rejects overlapping visual envelopes
	## unless the pair declares a seam, and WarrenAssetCompiler declares one only
	## where classified_roof_seam_compatible() holds -- which needs exactly one
	## roof junction, so it needs a shared FACE. Corner neighbours have none, yet
	## their authored roofs overhang far enough to meet across the corner, so
	## they are rejected as interpenetrating geometry at the last stage.
	##
	## Re-derived here from the parcels rather than from the rule that avoids it:
	## any two footprints sharing a diagonal step and no orthogonal one.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var parcels := town["parcels"] as Array[WarrenBuildingParcel]
		var corners := 0
		for left_index in parcels.size():
			for right_index in range(left_index + 1, parcels.size()):
				var left := parcels[left_index]
				var right := parcels[right_index]
				if _footprints_touch(left.footprint, right.footprint):
					continue
				corners += int(_footprints_share_a_corner(left.footprint,
					right.footprint))
		## MEASURED RESIDUE, NOT A TARGET. The partition prefers corner-free
		## footprints, which cuts these from 51 to 48 across the corpus -- but
		## most corners here are forced, not chosen: ownership demands a house
		## on every buildable street wall, and a street winding through a solid
		## puts those walls diagonally opposite one another constantly. This
		## bound exists so the number cannot grow unnoticed while the real fix
		## is decided; it is NOT an acceptance of interpenetrating geometry,
		## which still blocks composition.
		##
		## RE-MEASURED with the secondary lane network, and rewritten as a RATE.
		## The raw count rose 4-11 -> 9-23 per seed while the towns grew 18-30 ->
		## 41-58 houses; per house that is 0.22-0.37 -> 0.18-0.42, i.e. the
		## corner condition is no more frequent than it was, there is simply more
		## town. An absolute cap on a quantity that scales with the town would
		## forbid the town from growing while measuring nothing about the defect,
		## which is the third time on this branch a proxy has been scale-
		## dependent while the property it stood for was intact.
		##
		## Half a corner pair per house is a deliberately loose tripwire, set
		## above the observed 0.42 rather than at it. The real fix is still
		## authored corner art -- see the closed-negative trim investigation --
		## and interpenetrating geometry still blocks composition.
		assert_lte(corners * 2, parcels.size(),
			"seed %d: %d corner-only pairs across %d houses" % [world_seed,
				corners, parcels.size()])


func test_no_column_carries_two_houses() -> void:
	## One column, one house. WarrenParcelConstruction descends a fully-borne
	## house to its bearing datum as one stack, and WarrenAssetPlan rejects any
	## descent that passes through another parcel's retained mass -- so a house
	## standing over another on the same column cannot seal, however disjoint
	## their bands. Checked here against the descent rule itself, not against
	## the reservation this class uses to avoid it.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var massif := town["massif"] as WarrenMassif
		var parcels := town["parcels"] as Array[WarrenBuildingParcel]
		var owner_by_column: Dictionary = {}
		for parcel: WarrenBuildingParcel in parcels:
			for column: Vector2i in parcel.footprint:
				assert_false(owner_by_column.has(column),
					"seed %d: column %s carries both %s and %s" % [world_seed,
						column, owner_by_column.get(column, &""),
						parcel.stable_id])
				owner_by_column[column] = parcel.stable_id
		var occupied: Dictionary = {}
		for parcel: WarrenBuildingParcel in parcels:
			for cell: Vector3i in WarrenSolidPartitioner.occupied_cells(parcel):
				occupied[cell] = parcel.stable_id
		for parcel: WarrenBuildingParcel in parcels:
			for column: Vector2i in parcel.footprint:
				for band in range(massif.base_at(column), parcel.base_band):
					assert_false(occupied.has(Vector3i(column.x, band,
							column.y)),
						("seed %d: %s cannot be borne down to ground -- %s " \
						+ "stands in its descent at %s") % [world_seed,
							parcel.stable_id,
							occupied.get(Vector3i(column.x, band, column.y),
								&""),
							Vector3i(column.x, band, column.y)])


func test_houses_are_cut_from_the_solid_the_excavation_left() -> void:
	## Mass-first's defining claim: houses are the leftover solid, not volumes
	## invented beside it. Every occupied cell must be massif mass the carver
	## did not remove, and no two houses may claim the same cell -- the exact
	## pair of conditions WarrenParcelPlan.seal() re-checks as overlap.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var massif := town["massif"] as WarrenMassif
		var excavation := town["excavation"] as WarrenExcavation
		var owners: Dictionary = {}
		var checked := 0
		for parcel: WarrenBuildingParcel in town["parcels"] \
				as Array[WarrenBuildingParcel]:
			for cell: Vector3i in WarrenSolidPartitioner.occupied_cells(parcel):
				var column := Vector2i(cell.x, cell.z)
				checked += 1
				assert_true(massif.has_column(column) \
					and cell.y >= massif.base_at(column) \
					and cell.y < massif.top_at(column),
					"seed %d: cell %s of %s is outside the massif solid" \
					% [world_seed, cell, parcel.stable_id])
				assert_false(excavation.carved.has(cell),
					"seed %d: cell %s of %s stands inside the carved street" \
					% [world_seed, cell, parcel.stable_id])
				assert_false(owners.has(cell),
					"seed %d: %s and %s both claim %s" % [world_seed,
						owners.get(cell, &""), parcel.stable_id, cell])
				owners[cell] = parcel.stable_id
		assert_gt(checked, 0, "seed %d: nothing was partitioned" % world_seed)


func test_the_partition_leaves_no_buildable_solid_standing_over_a_street() \
		-> void:
	## Mass-first exists to roof its streets, so solid left standing OVER the
	## route must be either built into a house or genuinely unbuildable -- never
	## merely unclaimed. This is the completeness half of the ownership
	## guarantee: `street_wall_audit` says no flank is stranded, this says no
	## ceiling is.
	##
	## "Buildable" is re-derived here from WarrenBuildingParcel's own contract,
	## never from the partitioner's rules. A house whose footprint spans a street
	## cell can never be fully borne -- the street is carved out beneath that
	## column -- so WarrenParcelConstruction._support_base_band keeps it at its
	## addressed floor and its whole built silhouette is `top_band - base_band`.
	## Two complete storeys plus the roof reservation is therefore what a bridge
	## must find ABOVE the street's headroom; seal() pins `base_band` to a real
	## frontage cell's band; and the bearing majority demands that half its
	## columns still reach ground through unexcavated solid.
	##
	## Measured, and the reason this passes rather than being vacuous: 324
	## candidate envelopes over the corpus's streets are enumerated and every one
	## is refused, 177 of them because some footprint column's terrace stops
	## below `base + minimum` -- the bore leaves 1-8 bands of solid over its
	## route where a bridge needs six above the headroom -- and 138 because a
	## column already carries a house, one-column-one-house being absolute. Only
	## 8 fail on carved mass and 1 on the bearing majority. See task-9's report,
	## and `warren_mass_first_report --stage bridge` for the same question asked
	## across the whole frontier.
	##
	## So this is the tripwire for the day the geometry stops being self-blocking
	## -- a carver that leaves deeper cover, or a footprint family with a longer
	## reach across a street. It fires, and the partition owes that cover a house.
	var over_street_cells := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var massif := town["massif"] as WarrenMassif
		var excavation := town["excavation"] as WarrenExcavation
		var parcels := town["parcels"] as Array[WarrenBuildingParcel]
		var owned := _owned_cells(parcels)
		var claimed := _owned_columns(parcels)
		var ceilings: Dictionary = {}
		for walk: Vector3i in excavation.route:
			var column := Vector2i(walk.x, walk.z)
			ceilings[column] = maxi(int(ceilings.get(column, -(1 << 30))),
				walk.y + excavation.slot_bands(walk))
		for column_value: Variant in ceilings.keys():
			var column := column_value as Vector2i
			var unbuilt := 0
			for band in range(int(ceilings[column]), massif.top_at(column)):
				var cell := Vector3i(column.x, band, column.y)
				if excavation.carved.has(cell):
					continue
				over_street_cells += 1
				unbuilt += int(not owned.has(cell))
			if unbuilt == 0:
				continue
			var base := _bridge_base_band(massif, excavation, claimed, column,
				int(ceilings[column]))
			assert_eq(base, -1, ("seed %d: %d cells of solid stand unbuilt over " \
				+ "the street at %s, where a house addressed at band %d would " \
				+ "bridge it") % [world_seed, unbuilt, column, base])
	assert_gt(over_street_cells, 20,
		"the corpus left no solid over any street, so this test measured nothing")


func test_the_partition_fills_the_solid_its_public_realm_can_reach() -> void:
	## A tall stack reads as a skyscraper alone and as a terraced hillside town
	## when shorter neighbours stand against it, so mass the town can address
	## and does not build is a defect rather than spare capacity. Owning every
	## street wall houses the front rank of the bore only; this is the claim
	## that nothing else the same public realm could carry was left standing.
	##
	## Measured against a REAL frontier volume, because that is where the gap
	## lives: the ground arcade and the elevated galleries add walk cells the
	## bore's own route never had, WarrenParcelizer._candidates has always
	## treated every walk cell as an ordinary address, and the flank pass reads
	## `excavation.route` alone. On the raw adapted plan the two sets coincide
	## and this test is a tautology; on an extended one it is the whole point.
	##
	## Sites are re-derived from WarrenBuildingParcel's own contract, never from
	## the partitioner's admission rules: an authored footprint whose threshold
	## abuts a real address, unexcavated solid through the shortest envelope
	## WarrenParcelConstruction would build as two storeys from that base, the
	## bearing majority, and no column another house already stands on.
	##
	## `MEASURED_UNJOINABLE_FILL_SITES` is the residue: an infill house is
	## optional, so unlike a street wall it is never placed when its roof has no
	## join to its neighbours' or when it would meet one only across a corner.
	## That is the only reason a site here may go unbuilt, and the bound exists
	## so the number cannot grow unnoticed.
	var sites := 0
	var unclaimed_sites := 0
	var measured := 0
	for world_seed: int in FRONTIER_CORPUS:
		var town := _frontier_town(world_seed)
		if town.is_empty():
			continue
		measured += 1
		var massif := town["massif"] as WarrenMassif
		var excavation := town["excavation"] as WarrenExcavation
		var claimed := _owned_columns(
			town["parcels"] as Array[WarrenBuildingParcel])
		for address: Vector3i in town["addresses"] as Array[Vector3i]:
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
					Vector2i.LEFT, Vector2i.UP]:
				for shape: Vector2i in [Vector2i(2, 3), Vector2i(2, 2),
						Vector2i(1, 2), Vector2i(1, 1)]:
					var footprint := _bridge_footprint(address, direction,
						shape.x, shape.y)
					var minimum := _two_storey_bands(massif, footprint,
						address.y)
					if _envelope_stands(massif, excavation, {}, footprint,
							address.y, minimum):
						sites += 1
					if _envelope_stands(massif, excavation, claimed, footprint,
							address.y, minimum):
						unclaimed_sites += 1
	assert_gt(measured, 1, "too few frontier towns to prove anything")
	assert_gt(sites, 100,
		"the corpus offers too few house sites to prove anything")
	assert_between(unclaimed_sites, 0, MEASURED_UNJOINABLE_FILL_SITES,
		("%d house sites stand unbuilt on unclaimed solid the town's own walk " \
		+ "cells address, so the towns are ribbons of towers rather than a " \
		+ "terraced mass") % unclaimed_sites)


func _frontier_town(world_seed: int) -> Dictionary:
	## The production parcel stage's own inputs: a volume that has been through
	## the arcade and gallery solvers, and the widened void they carve.
	if _frontier_towns.has(world_seed):
		return _frontier_towns[world_seed] as Dictionary
	var out: Dictionary = {}
	var previous_mode := WarrenTownSolver.GENERATION_MODE
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
	WarrenTownSolver.GENERATION_MODE = previous_mode
	if not frontier.is_empty():
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
			bore, volume)
		if massif != null and excavation != null:
			var addresses: Dictionary = {}
			for cell: Vector3i in excavation.route:
				addresses[cell] = true
			for cell: Vector3i in volume.walk_cells:
				addresses[cell] = true
			var address_list: Array[Vector3i] = []
			address_list.assign(addresses.keys())
			out = {
				"massif": massif,
				"excavation": excavation,
				"volume": volume,
				"addresses": address_list,
				"parcels": WarrenSolidPartitioner.partition(massif, excavation,
					volume),
			}
	_frontier_towns[world_seed] = out
	return out


func _two_storey_bands(massif: WarrenMassif, footprint: Array[Vector2i],
		base: int) -> int:
	## The shortest envelope that both seals and builds as two storeys, taken
	## from WarrenParcelConstruction.proposal() rather than from the
	## partitioner: a fully borne house descends to its bearing datum as one
	## continuous stack, so an elevated address inherits those storeys and needs
	## only WarrenBuildingParcel.seal()'s own minimum, while one addressed at
	## natural ground has nothing beneath it and must carry both storeys itself.
	var seal_minimum := WarrenBuildingParcel.STOREY_BANDS \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	var ground := -(1 << 30)
	for column: Vector2i in footprint:
		if not massif.has_column(column):
			return seal_minimum
		ground = maxi(ground, massif.base_at(column))
	var support := ground
	if posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS) != 0:
		support -= 1
	var needed := WarrenBuildingParcel.STOREY_BANDS * 2 \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS \
		- (base - mini(support, base))
	return maxi(seal_minimum, needed + posmod(needed, 2))


func _bridge_base_band(massif: WarrenMassif, excavation: WarrenExcavation,
		claimed: Dictionary, column: Vector2i, ceiling: int) -> int:
	## The lowest band at which a sealable house spanning `column` could stand,
	## or -1 when the solid admits none. Every condition is taken from
	## WarrenBuildingParcel.seal() and WarrenParcelConstruction directly: an
	## authored footprint whose threshold abuts a real frontage cell, unexcavated
	## solid through the whole envelope, the bearing majority, the mixed-span
	## silhouette minimum, and no column another house already stands on.
	var minimum := WarrenBuildingParcel.STOREY_BANDS * 2 \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	for address: Vector3i in excavation.route:
		if address.y < ceiling \
				or absi(address.x - column.x) > BRIDGE_REACH_CELLS \
				or absi(address.z - column.y) > BRIDGE_REACH_CELLS:
			continue
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.UP]:
			for shape: Vector2i in [Vector2i(2, 3), Vector2i(2, 2),
					Vector2i(1, 2), Vector2i(1, 1)]:
				var footprint := _bridge_footprint(address, direction, shape.x,
					shape.y)
				if not footprint.has(column):
					continue
				if _envelope_stands(massif, excavation, claimed, footprint,
						address.y, minimum):
					return address.y
	return -1


func _bridge_footprint(walk: Vector3i, direction: Vector2i, width: int,
		depth: int) -> Array[Vector2i]:
	## WarrenParcelizer's footprint at the only lateral variant whose doorway
	## lands in the threshold column, so this enumerates exactly the shapes
	## WarrenParcelConstruction.door_serves_address() can accept.
	var perpendicular := Vector2i(-direction.y, direction.x)
	var threshold := Vector2i(walk.x, walk.z) + direction
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + direction * depth_offset \
				+ perpendicular * width_offset)
	return out


func _envelope_stands(massif: WarrenMassif, excavation: WarrenExcavation,
		claimed: Dictionary, footprint: Array[Vector2i], base: int,
		minimum: int) -> bool:
	var bearing := 0
	for column: Vector2i in footprint:
		if claimed.has(column) or not massif.has_column(column) \
				or massif.base_at(column) > base \
				or massif.top_at(column) < base + minimum:
			return false
		for band in range(base, base + minimum):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				return false
		var grounded := true
		for band in range(massif.base_at(column), base):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				grounded = false
				break
		bearing += int(grounded)
	return bearing * 2 >= footprint.size()


func test_tops_follow_the_massif_terraces() -> void:
	## The skyline is meant to come from the terraced solid rather than from a
	## scoring pass, so no house may rise above the lowest terrace it stands
	## on, and a town may not settle onto one roof datum.
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var massif := town["massif"] as WarrenMassif
		var tops: Dictionary = {}
		for parcel: WarrenBuildingParcel in town["parcels"] \
				as Array[WarrenBuildingParcel]:
			var terrace := 1 << 30
			for column: Vector2i in parcel.footprint:
				terrace = mini(terrace, massif.top_at(column))
			assert_between(parcel.top_band, parcel.base_band + 1, terrace,
				"seed %d: parcel %s tops out above its terrace" % [world_seed,
					parcel.stable_id])
			tops[parcel.top_band] = true
		assert_gt(tops.size(), 3,
			"seed %d: only %d distinct roof bands is a flat skyline" \
			% [world_seed, tops.size()])


func test_no_house_builds_more_storeys_than_a_terrace_carries() -> void:
	## The storeys a viewer counts are WarrenParcelConstruction.proposal()'s,
	## not the envelope the partition cut: a house descends from its addressed
	## floor to its bearing datum as one continuous stack. With the bearing
	## datum at natural ground a street eight bands up makes a one-storey
	## envelope read as six, which is the tower the reviewer rejected.
	##
	## The bearing datum is the terrace instead, so the whole stack fits inside
	## the buildable layer the terrace carries. Derived from that layer rather
	## than chosen, and asserted against the real adapted plan so the number is
	## the one the asset compiler will build.
	## Two claims, because there are two ways to be tall and only one of them is
	## the defect. A house that DESCENDS may not descend past its terrace, so
	## its whole stack fits the buildable layer. A house whose street is cut
	## BELOW its terrace has no plinth to descend to at all and is simply as
	## tall as the solid standing over it -- rarer, and capping it is the
	## already-closed remedy that strands street walls, so it is bounded by a
	## measured tripwire instead of forbidden.
	var maximum := (WarrenMassif.BUILDABLE_LAYER_BANDS \
		- WarrenBuildingParcel.ROOF_RESERVATION_BANDS) \
		/ WarrenBuildingParcel.STOREY_BANDS
	var counted := 0
	var undescended_tall := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var envelope := (town["plan"] as WarrenVolumePlan).envelope
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			var proposal := WarrenParcelConstruction.proposal(parcel)
			assert_false(proposal.is_empty(),
				"seed %d: parcel %s compiles to no proposal" % [world_seed,
					parcel.stable_id])
			if proposal.is_empty():
				continue
			counted += 1
			var support := (proposal.origin as Vector3i).y
			# The deepest terrace under the footprint, floored at the highest
			# natural ground -- see _support_base_band on why a footprint
			# crossing a step cuts into the uphill side rather than refusing.
			var terrace := 1 << 30
			var ground := -(1 << 30)
			for column: Vector2i in parcel.footprint:
				terrace = mini(terrace, envelope.bearing_at(column))
				ground = maxi(ground, envelope.ground_at(column))
			terrace = maxi(terrace, ground)
			# One band of slack is the address-phase parity fudge
			# _support_base_band already owned; the clamp to base_band is the
			# street cut below its own terrace.
			assert_gte(support, mini(parcel.base_band, terrace - 1),
				"seed %d: %s roots at %d, %d bands under its terrace" \
				% [world_seed, parcel.stable_id, support, terrace - support])
			if support < parcel.base_band:
				assert_between(int(proposal.storeys), 1, maximum,
					"seed %d: %s descends to a terrace and still builds %d " \
					% [world_seed, parcel.stable_id, int(proposal.storeys)]
					+ "storeys against a %d-band layer" \
					% WarrenMassif.BUILDABLE_LAYER_BANDS)
			elif int(proposal.storeys) > maximum:
				undescended_tall += 1
	assert_gt(counted, 50, "too few houses measured to be a corpus")
	assert_lte(undescended_tall, MEASURED_UNDESCENDED_TALL_HOUSES,
		"%d houses stand taller than a terrace on a street cut below it" \
		% undescended_tall)


func test_a_house_on_a_terrace_declares_the_hill_beneath_it() -> void:
	## THE PLINTH BUDGET, and the declaration contract behind it.
	##
	## Split-datum era: a house stopped descending at its terrace, leaving real
	## source mass between natural ground and its lowest room, and unless it
	## DECLARED that gap nothing rendered it. Buildable-layer era: the terrain
	## carries everything under the layer, `bearing_at` is `base_at`, and the
	## only gap left is the one a footprint straddling a ground step opens on
	## its downhill side. The contract is unchanged and still exact; what moved
	## is how much there is to declare, and the reviewer's budget -- a plinth is
	## ONE course of stone, part of a facade -- is what now has to be pinned.
	##
	## The declaration must be exactly the gap --
	## short and the house floats, long and it buries a storey.
	var declared := 0
	var measured_houses := 0
	var over_budget := 0
	var deepest_plinth := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var envelope := (town["plan"] as WarrenVolumePlan).envelope
		var occupied := _owned_cells(_sealed_parcels(world_seed))
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if proposal.is_empty():
				continue
			var support := (proposal.origin as Vector3i).y
			# Only the MASS in the gap. A lane tunnelling under a plinth leaves
			# void there, and stone declared over a lane fills the lane in.
			var expected := 0
			for column: Vector2i in parcel.footprint:
				for band in range(envelope.ground_at(column), support):
					expected += 4 * int(parcel.source.has_mass(
						Vector3i(column.x, band, column.y)))
			var terrace := WarrenParcelConstruction.retained_terrace_cells(
				parcel)
			assert_eq(terrace.size(), expected,
				"seed %d: %s stands %d bands above ground and declares %d " \
				% [world_seed, parcel.stable_id, support, terrace.size()]
				+ "terrace cells, not %d" % expected)
			declared += terrace.size()
			measured_houses += 1
			var lowest_ground := 1 << 30
			for column: Vector2i in parcel.footprint:
				lowest_ground = mini(lowest_ground, envelope.ground_at(column))
			deepest_plinth = maxi(deepest_plinth, support - lowest_ground)
			over_budget += int(support - lowest_ground
				> SettlementFabricAssembler.STONE_BUDGET_BANDS)
			for cell: Vector3i in terrace:
				var macro_cell := Vector3i(floori(float(cell.x) / 2.0), cell.y,
					floori(float(cell.z) / 2.0))
				assert_false(occupied.has(macro_cell),
					"seed %d: %s retains %s, which a house already occupies" \
					% [world_seed, parcel.stable_id, macro_cell])
				assert_true(parcel.source.has_mass(macro_cell),
					"seed %d: %s retains %s, which the excavation removed" \
					% [world_seed, parcel.stable_id, macro_cell])
	# The sample guard is deliberately below the currently accepted relief
	# corpus. The load-bearing property is exact: no footprint may turn a terrain
	# riser into more than one explicit foundation course.
	assert_gt(measured_houses, 35,
		"only %d houses measured -- too few to be a corpus" % measured_houses)
	assert_eq(over_budget, 0,
		("%d of %d houses are rooted more than %d bands above the lowest "
		+ "ground under their own footprint, the worst by %d") % [over_budget,
			measured_houses, SettlementFabricAssembler.STONE_BUDGET_BANDS,
			deepest_plinth])
	assert_lte(deepest_plinth, SettlementFabricAssembler.STONE_BUDGET_BANDS,
		"the deepest plinth is %d bands, past the one course the reviewer's "
		% deepest_plinth + "budget allows")


func test_a_grounded_corpus_seed_draws_its_declared_plinths() -> void:
	## THE DRAWING HALF of the plinth contract. The test above proves
	## declaration is correct and bounded; task-24-report.md concern #2 found
	## the assembler then drew NONE of the 216 plinths the stamped-hill corpus
	## declared, because a since-removed stone_clad veto refused a plinth under
	## any rock-grounded house. Mass-first now normally uses timber at grade, but
	## support declaration remains independent of facade style.
	## A plinth is FRONTED stone: a building always stands directly on it
	## (that is what makes a cell eligible below), so it is bounded on its own
	## terms by the declaration side
	## (WarrenParcelConstruction.resolve_support_band, budgeted at
	## WarrenMassif.PLINTH_BUDGET_BANDS) rather than by the bare-stone budget
	## that governs masonry nothing stands over. Whether the ground storey
	## above it also happens to be rock is the separate, already-accepted
	## "stone feature" the reviewer praised, not a reason to refuse the
	## foundation course underneath it.
	##
	## Modelled with a synthetic solid standing on the declared terrace --
	## test_a_house_on_a_terrace_declares_the_hill_beneath_it's fixture,
	## carried one step further into the assembler that draws it.
	var drawn_total := 0
	var plinthed_houses := 0
	var over_budget := 0
	for world_seed: int in CORPUS:
		if _town(world_seed).is_empty():
			continue
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			var terrace := WarrenParcelConstruction.retained_terrace_cells(
				parcel)
			if terrace.is_empty():
				continue
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if proposal.is_empty():
				continue
			var retained: Dictionary = {}
			for cell: Vector3i in terrace:
				retained[cell] = true
			var support := (proposal.origin as Vector3i).y
			# The house's own ground storey, standing exactly where
			# WarrenParcelConstruction rooted it. Real ground storeys are
			# unconditionally rock (WarrenAssetCompiler's `room.*.base.rock`)
			# -- the point of this fixture is that the plinth must draw
			# whether or not this solid is stone-clad, so it is deliberately
			# not told apart here.
			var solids: Dictionary = {}
			for column: Vector2i in parcel.footprint:
				for x_offset in 2:
					for z_offset in 2:
						solids[Vector3i(column.x * 2 + x_offset, support,
							column.y * 2 + z_offset)] = parcel.stable_id
			var payload := SettlementFabricAssembler.house_plinth_walls(
				retained, solids)
			plinthed_houses += 1
			drawn_total += payload.instance_count
			assert_gt(payload.instance_count, 0,
				("seed %d: %s declares %d plinth cells and the assembler " \
				+ "draws none of them") % [world_seed, parcel.stable_id,
					terrace.size()])
			var lowest_ground := 1 << 30
			for column: Vector2i in parcel.footprint:
				lowest_ground = mini(lowest_ground,
					parcel.source.envelope.bearing_at(column))
			over_budget += int(support - lowest_ground
				> SettlementFabricAssembler.STONE_BUDGET_BANDS)
	assert_gt(plinthed_houses, 10,
		"only %d plinthed houses in the corpus -- too few to prove anything" \
		% plinthed_houses)
	assert_gt(drawn_total, 0, "the grounded corpus draws zero plinth modules")
	assert_eq(over_budget, 0,
		"%d houses stand on more plinth stone than STONE_BUDGET_BANDS allows" \
		% over_budget)


func test_footprints_stay_in_the_authored_family() -> void:
	## Every shape must have an authored roof profile downstream. A footprint
	## outside WarrenParcelConstruction's five profiles compiles to nothing at
	## all, so the family is a contract rather than a stylistic preference.
	var town := _town(1)
	assert_false(town.is_empty())
	var parcels := WarrenSolidPartitioner.partition(
		town["massif"] as WarrenMassif, town["excavation"] as WarrenExcavation,
		town["plan"] as WarrenVolumePlan)
	var families: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var family := Vector2i(parcel.width_cells, parcel.depth_cells)
		families[family] = true
		assert_true(WarrenSolidPartitioner.SHAPES.has(family),
			"parcel %s has footprint %s, which is outside the family" \
			% [parcel.stable_id, family])
		assert_false(WarrenParcelConstruction.profile_for(parcel).is_empty(),
			"parcel %s has no authored roof profile" % parcel.stable_id)
	assert_gt(families.size(), 1,
		"a warren of one repeated footprint is not a partitioned town")
	assert_true(families.has(Vector2i(2, 1)),
		("the production partition must exercise the broad/shallow rowhouse " \
		+ "source contract instead of decomposing every street row into towers"))


func test_partition_is_deterministic_with_and_without_exact_surface_selection() -> void:
	## Integer hashes only: no randf, no Time, no engine RNG. The optional volume
	## does not change the residual solid, but it legitimately rejects a coarse
	## frontage candidate whose exact authored door misses a stair/ramp tread.
	## Each mode must remain deterministic; equality between the modes is no
	## longer an invariant because only one of them knows fine floor ownership.
	var town: Dictionary = {}
	var fixture_seed := -1
	for world_seed: int in CORPUS:
		town = _town(world_seed)
		if not town.is_empty():
			fixture_seed = world_seed
			break
	assert_false(town.is_empty(),
		"the accepted partition corpus produced no deterministic fixture")
	if town.is_empty():
		return
	var massif := town["massif"] as WarrenMassif
	var excavation := town["excavation"] as WarrenExcavation
	var first := WarrenSolidPartitioner.partition(massif, excavation)
	var second := WarrenSolidPartitioner.partition(massif, excavation)
	var sealed_run := WarrenSolidPartitioner.partition(massif, excavation,
		town["plan"] as WarrenVolumePlan)
	var repeated_sealed_run := WarrenSolidPartitioner.partition(massif,
		excavation, town["plan"] as WarrenVolumePlan)
	assert_eq(_signature(first), _signature(second),
		"seed %d: two partitions of one excavation must be identical" % fixture_seed)
	assert_eq(_signature(sealed_run), _signature(repeated_sealed_run),
		("seed %d: two exact-surface partitions of one volume must be identical") \
		% fixture_seed)


func test_partition_refuses_unsealed_inputs() -> void:
	## A partition of geometry nobody validated would be worse than none: the
	## massif's solidity and the excavation's walk are preconditions for every
	## invariant this class relies on.
	var town := _town(1)
	assert_false(town.is_empty())
	var empty := WarrenSolidPartitioner.partition(null,
		town["excavation"] as WarrenExcavation)
	assert_eq(empty.size(), 0)
	assert_string_contains(WarrenSolidPartitioner.last_failure, "massif")
	empty = WarrenSolidPartitioner.partition(town["massif"] as WarrenMassif,
		WarrenExcavation.new(1))
	assert_eq(empty.size(), 0)
	assert_string_contains(WarrenSolidPartitioner.last_failure, "excavation")


func test_partition_corpus_produces_a_town_on_every_accepted_seed() -> void:
	## Re-check the two claims that make this stage usable -- enough houses and
	## no stranded street wall -- on every stamped-relief seed this bounded bore
	## corpus accepts. Multi-town supply is covered by FRONTIER_CORPUS on the
	## canonical flat partition fixture; relief supply has its own adapter test.
	var accepted := 0
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		accepted += 1
		var parcels := town["parcels"] as Array[WarrenBuildingParcel]
		assert_gt(parcels.size(), 9, "seed %d: only %d houses (%s)" \
			% [world_seed, parcels.size(),
				WarrenSolidPartitioner.last_failure])
		var unowned := WarrenSolidPartitioner.unowned_route_faces(parcels,
			town["excavation"] as WarrenExcavation,
			town["massif"] as WarrenMassif)
		assert_eq(unowned.size(), 0, "seed %d: %d unowned wall cells %s" \
			% [world_seed, unowned.size(), str(unowned.slice(0, 6))])
	assert_gt(accepted, 0,
		"no stamped-relief seed produced a partitioned town")


func _town(world_seed: int) -> Dictionary:
	if _towns.has(world_seed):
		return _towns[world_seed] as Dictionary
	var out: Dictionary = {}
	var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
	var excavation := null if massif == null else _excavation(world_seed, massif)
	if massif != null and excavation != null:
		var parcels := WarrenSolidPartitioner.partition(massif, excavation)
		out = {
			"massif": massif,
			"excavation": excavation,
			"plan": WarrenExcavationVolumeAdapter.to_volume_plan(massif,
				excavation),
			"parcels": parcels,
			# Captured with the partition that produced it: later calls
			# overwrite the static, and the roof tests compare what the
			# partitioner CLAIMED against what the real module table decides.
			"unjoinable": int(WarrenSolidPartitioner.last_diagnostic.get(
				"unjoinable_roof_count", -1)),
		}
	_towns[world_seed] = out
	return out


func _strict_walls(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Vector3i]:
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for cell: Vector3i in excavation.route:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.UP]:
			var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
			if not massif.has_column(column) \
					or massif.base_at(column) > cell.y \
					or massif.top_at(column) < cell.y + STRICT_WALL_BANDS:
				continue
			var clear := true
			for band in range(massif.base_at(column),
					cell.y + STRICT_WALL_BANDS):
				if excavation.carved.has(Vector3i(column.x, band, column.y)):
					clear = false
					break
			var wall := Vector3i(column.x, cell.y, column.y)
			if not clear or seen.has(wall):
				continue
			seen[wall] = true
			out.append(wall)
	return out


func _sealed_parcels(world_seed: int) -> Array[WarrenBuildingParcel]:
	## Parcels sealed against the adapted plan, so envelope-derived facts
	## (bearing datum, source mass) are readable from the parcel itself.
	var town := _town(world_seed)
	if town.is_empty():
		return [] as Array[WarrenBuildingParcel]
	return WarrenSolidPartitioner.partition(town["massif"] as WarrenMassif,
		town["excavation"] as WarrenExcavation,
		town["plan"] as WarrenVolumePlan)


func _proposals(world_seed: int) -> Array[Dictionary]:
	## Sealed parcels carry the construction proposal the roof classifier reads,
	## so the roof tests partition against the real adapted plan rather than the
	## unsealed geometric preview.
	var town := _town(world_seed)
	var out: Array[Dictionary] = []
	if town.is_empty():
		return out
	for parcel: WarrenBuildingParcel in WarrenSolidPartitioner.partition(
			town["massif"] as WarrenMassif,
			town["excavation"] as WarrenExcavation,
			town["plan"] as WarrenVolumePlan):
		var proposal := WarrenParcelConstruction.proposal(parcel)
		assert_false(proposal.is_empty(),
			"seed %d: parcel %s compiles to no proposal" % [world_seed,
				parcel.stable_id])
		if not proposal.is_empty():
			out.append(proposal)
	return out


func _footprints_share_a_corner(left: Array[Vector2i],
		right: Array[Vector2i]) -> bool:
	var occupied: Dictionary = {}
	for column: Vector2i in right:
		occupied[column] = true
	for column: Vector2i in left:
		for step: Vector2i in [Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)]:
			if occupied.has(column + step):
				return true
	return false


func _footprints_touch(left: Array[Vector2i], right: Array[Vector2i]) -> bool:
	var occupied: Dictionary = {}
	for column: Vector2i in right:
		occupied[column] = true
	for column: Vector2i in left:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.UP]:
			if occupied.has(column + direction):
				return true
	return false


func _parcel_ridge(parcel: WarrenBuildingParcel) -> Vector2i:
	## Independent restatement of the authored roof-family contract. All narrow
	## and square families run the ridge into the parcel; the sole broad/shallow
	## family runs it along its two-module facade. Raw partition corpus parcels
	## are intentionally unsealed, so derive width/depth from their footprint
	## instead of reading the fields `seal()` populates.
	var size := _parcel_footprint_size(parcel)
	var depth := size.x if parcel.frontage_direction.x != 0 else size.y
	if parcel.footprint.size() == 2 and depth == 1:
		return Vector2i(-parcel.frontage_direction.y,
			parcel.frontage_direction.x)
	return parcel.frontage_direction


func _parcel_shape(parcel: WarrenBuildingParcel) -> String:
	var size := _parcel_footprint_size(parcel)
	var depth := size.x if parcel.frontage_direction.x != 0 else size.y
	var width := size.y if parcel.frontage_direction.x != 0 else size.x
	return "%dx%d" % [width, depth]


func _parcel_footprint_size(parcel: WarrenBuildingParcel) -> Vector2i:
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column: Vector2i in parcel.footprint:
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return maximum - minimum + Vector2i.ONE


func _owned_cells(parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	var out: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for cell: Vector3i in WarrenSolidPartitioner.occupied_cells(parcel):
			out[cell] = true
	return out


func _owned_columns(parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	var out: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for column: Vector2i in parcel.footprint:
			if not out.has(column):
				out[column] = [] as Array[int]
			(out[column] as Array[int]).append(parcel.top_band - 1)
	return out


func _signature(parcels: Array[WarrenBuildingParcel]) -> String:
	var parts := PackedStringArray()
	for parcel: WarrenBuildingParcel in parcels:
		parts.append(parcel.slot_signature() + "@%d" % parcel.top_band)
	return "|".join(parts)


## What a foundation course can honestly hide, restated from
## SettlementFabricAssembler.STONE_BUDGET_BANDS so this suite never reads the
## number it audits from the class it audits. A house whose lowest drawn band
## stands further than this over the nearest drawn support is floating.
const MAX_UNSUPPORTED_BANDS := 2
## The tallest run of bands a viewer may read as ONE unbroken wall, whichever
## stage drew each band. WarrenMassifBuilder bounds every step in the solid at
## MAX_NEIGHBOR_STEP_BANDS, and the tallest house the buildable layer carries
## adds its own facade above the last step it stands on -- so the composed face
## is bounded by that step plus one house, and nothing here may exceed it.
const MAX_COMPOSED_FACE_BANDS := WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS \
	+ WarrenMassif.BUILDABLE_LAYER_BANDS


## Bands of terrain body modelled under each column's sampled ground band. The
## hill is a solid the mesher renders and the chunk collider carries, not a
## surface, so anything resting at or below its own ground band is carried.
const TERRAIN_BODY_BANDS := 12


func _carried_mass(world_seed: int) -> Dictionary:
	## Everything a viewer sees mass at, at macro resolution: the TERRAIN body
	## under each column, plus the plinth course a house declares. House cells
	## are added by the caller.
	##
	## RE-BASED for the buildable layer. This used to be "the whole standing
	## massif solid", because the fabric drew that solid -- and it is exactly
	## what WarrenFabricCompiler stopped declaring and
	## SettlementFabricAssembler stopped drawing. What carries a house now is
	## SettlementReliefPlan's hill, meshed and collided by the terrain, so the
	## honest model of "drawn support" is the terrain body under the sampled
	## ground band. Modelling the old solid here would score a house as
	## grounded on masonry nobody renders any more, which is precisely the
	## artefact the reviewer's floating note was about.
	var town := _town(world_seed)
	if town.is_empty():
		return {}
	var massif := town["massif"] as WarrenMassif
	var drawn: Dictionary = {}
	for column: Vector2i in massif.columns:
		for band in range(massif.base_at(column) - TERRAIN_BODY_BANDS,
				massif.base_at(column)):
			drawn[Vector3i(column.x, band, column.y)] = true
	return drawn


func test_no_house_stands_more_than_a_plinth_above_its_own_support() -> void:
	## Round-5 review note 3: "some of the buildings now are just kind of
	## 'floating'". A house is grounded when the mass it stands on is DRAWN --
	## natural ground, retained hill, or another house -- within one foundation
	## course of its lowest room. Measured on the highest support anywhere under
	## the footprint, so a house that genuinely oversails a street on one column
	## still counts as carried by the others.
	var floating := 0
	var measured := 0
	var worst := 0
	for world_seed: int in CORPUS:
		var drawn := _carried_mass(world_seed)
		if drawn.is_empty():
			continue
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			for cell: Vector3i in WarrenParcelConstruction.retained_terrace_cells(
					parcel):
				drawn[Vector3i(cell.x / 2, cell.y, cell.z / 2)] = true
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if proposal.is_empty():
				continue
			measured += 1
			var underside := (proposal.origin as Vector3i).y
			var gap := 1 << 30
			for column: Vector2i in parcel.footprint:
				var column_gap := 0
				for band in range(underside - 1,
						underside - 1 - TERRAIN_BODY_BANDS, -1):
					if drawn.has(Vector3i(column.x, band, column.y)):
						column_gap = underside - band - 1
						break
				gap = mini(gap, column_gap)
			worst = maxi(worst, gap)
			if gap > MAX_UNSUPPORTED_BANDS:
				floating += 1
	assert_gt(measured, 35, "only %d houses measured" % measured)
	assert_eq(floating, 0,
		"%d of %d houses stand over drawn nothing, the worst by %d bands" \
		% [floating, measured, worst])


func test_no_composed_vertical_face_reads_as_a_tower() -> void:
	## Round-5 review note 4: the two-to-three storey rule is about the COMPOSED
	## face -- what a viewer reads as one unbroken wall -- not about one house.
	## Measured over every drawn band, so a house sitting flush on the hill it
	## stands on is counted as the single wall it looks like.
	##
	## The bound is derived, not tuned: WarrenMassifBuilder holds every step in
	## the solid to MAX_NEIGHBOR_STEP_BANDS, and WarrenMassif.bearing_at holds a
	## house to one BUILDABLE_LAYER_BANDS above the terrace it stands on, so the
	## worst legal composition is one terrace step plus one house.
	var tallest := 0
	var worst_seed := -1
	var faces := 0
	for world_seed: int in CORPUS:
		if _town(world_seed).is_empty():
			continue
		# FABRIC ONLY. The composed face is what the fabric stacks; the terrain
		# body beneath is landscape in the world's own vocabulary -- grass,
		# slope and KayKit crag -- and whether a terrain-authored cliff counts
		# as "visible stone" under the 2-3 storey rule is the reviewer's open
		# ruling (mass-first ledger 214/218), not this suite's to assume.
		var drawn: Dictionary = {}
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			for cell: Vector3i in WarrenParcelConstruction.retained_terrace_cells(
					parcel):
				drawn[Vector3i(cell.x / 2, cell.y, cell.z / 2)] = true
		for parcel: WarrenBuildingParcel in _sealed_parcels(world_seed):
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if proposal.is_empty():
				continue
			for column: Vector2i in parcel.footprint:
				for band in range((proposal.origin as Vector3i).y,
						parcel.top_band):
					drawn[Vector3i(column.x, band, column.y)] = true
		var runs: Dictionary = {}
		for cell_value: Variant in drawn.keys():
			var cell := cell_value as Vector3i
			for index in 4:
				var step: Vector2i = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
					Vector2i.DOWN][index]
				if drawn.has(Vector3i(cell.x + step.x, cell.y, cell.z + step.y)):
					continue
				var key := Vector3i(cell.x, cell.z, index)
				if not runs.has(key):
					runs[key] = {}
				(runs[key] as Dictionary)[cell.y] = true
		for key_value: Variant in runs.keys():
			var bands: Array[int] = []
			bands.assign((runs[key_value] as Dictionary).keys())
			bands.sort()
			var index := 0
			while index < bands.size():
				var last := index
				while last + 1 < bands.size() \
						and bands[last + 1] == bands[last] + 1:
					last += 1
				faces += 1
				if bands[last] - bands[index] + 1 > tallest:
					tallest = bands[last] - bands[index] + 1
					worst_seed = world_seed
				index = last + 1
	assert_gt(faces, 180, "only %d composed faces measured" % faces)
	assert_lte(tallest, MAX_COMPOSED_FACE_BANDS,
		"seed %d presents %d unbroken bands -- %d storeys of one wall" % [
			worst_seed, tallest,
			tallest / WarrenBuildingParcel.STOREY_BANDS])


func test_the_apparent_face_rule_is_the_storey_rule_restated() -> void:
	## THE EQUIVALENCE PROOF, over the whole reachable input space rather than
	## on a sample. Production's "visually short" rule was
	## `proposal().storeys >= 2`, counted from a support datum the storey-parity
	## fudge pushed one band UNDER the ground whenever the address offset was
	## odd. Wave 5 stops burying that band, so the storey form had to be
	## restated -- and a restatement that changed any verdict would be a gate
	## move wearing a comment.
	##
	## Inputs: an envelope of any legal height (even, at least the seal
	## minimum) at any address offset the buildable layer can present.
	var checked := 0
	for offset in range(0, WarrenMassif.BUILDABLE_LAYER_BANDS + 1):
		for envelope in range(WarrenBuildingParcel.STOREY_BANDS
				+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
				WarrenMassif.BUILDABLE_LAYER_BANDS * 2 + 1, 2):
			# The old rule, spelled out: storeys counted from the support the
			# parity fudge produced.
			var support := -offset
			if posmod(offset, WarrenBuildingParcel.STOREY_BANDS) != 0:
				support -= 1
			var storeys := (envelope
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS - support) \
				/ WarrenBuildingParcel.STOREY_BANDS
			var was_short := storeys < 2
			# The new rule: bands of face above the ground, plinth included.
			var is_short := envelope + offset \
				< WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS
			assert_eq(is_short, was_short,
				("offset %d, envelope %d: the apparent-face rule says %s and "
				+ "the storey rule said %s") % [offset, envelope,
				str(is_short), str(was_short)])
			checked += 1
	assert_gt(checked, 20, "the equivalence sweep covered nothing")
	# TEETH, so the restatement is not vacuously true of everything: a kerb is
	# still short, and the shortest thing that clears the bar is the five-band
	# face an odd offset produces -- the one the plinth stone completes.
	assert_true(WarrenBuildingParcel.STOREY_BANDS
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		< WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS,
		"a bare seal-minimum envelope at grade must still read as short")
	assert_eq(WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS,
		WarrenSolidPartitioner.MIN_STOREYS * WarrenBuildingParcel.STOREY_BANDS
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS - 1,
		"the bar is the storey minimum less the one band an odd offset cannot "
		+ "buy, which is the band the plinth supplies")


func test_no_house_is_buried_and_a_parity_offset_becomes_a_plinth() -> void:
	## THE GROUNDING CONTRACT (terrain milestone, Wave 5). Measured over the
	## stamped-hill corpus rather than asserted on a fixture, because the defect
	## it replaces was a corpus statistic: 211 of 424 houses rooted exactly one
	## band under their own ground and not one plinth anywhere
	## (task-23-report §4).
	##
	## Three claims, and the third is what makes the first two more than a
	## rename: nothing is buried, the support never floats above the ground it
	## claims to rest on beyond the plinth budget, and every band between the
	## stamped surface and the support is DECLARED as plinth cells -- so the
	## stone a house stands on is stone the assembler will actually place, not a
	## gap it hovers over.
	var houses := 0
	var buried := 0
	var plinths := 0
	var declared := 0
	var over_budget := 0
	for world_seed in range(0, 6):
		var massif := WarrenMassifBuilder.build(world_seed, _hill(world_seed))
		if massif == null:
			continue
		var excavation := _excavation(world_seed, massif)
		if excavation == null:
			continue
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			continue
		for parcel: WarrenBuildingParcel in WarrenSolidPartitioner.partition(
				massif, excavation, plan):
			var construction := WarrenParcelConstruction.proposal(parcel)
			if construction.is_empty():
				continue
			houses += 1
			var support := (construction.origin as Vector3i).y
			var lowest := 1 << 30
			for column: Vector2i in parcel.footprint:
				lowest = mini(lowest, plan.envelope.bearing_at(column))
			buried += int(support < lowest)
			var lift := support - lowest
			if lift > 0:
				plinths += 1
				over_budget += int(lift
					> plan.envelope.plinth_budget_bands)
				declared += int(
					WarrenParcelConstruction.retained_terrace_cells(parcel).size()
					> 0)
	assert_gt(houses, 0, "no house to measure")
	assert_eq(buried, 0,
		"%d of %d houses are rooted below the lowest ground under their own "
		% [buried, houses] + "footprint")
	assert_eq(over_budget, 0,
		"%d houses stand on more stone than WarrenMassif.PLINTH_BUDGET_BANDS "
		% over_budget + "allows")
	assert_gt(plinths, 0,
		"not one house in %d stands on a plinth, so the budget is doing "
		% houses + "nothing and the parity is still being resolved downward")
	assert_eq(declared, plinths,
		"%d of %d plinthed houses declare no retained cells, so their stone "
		% [plinths - declared, plinths] + "is never placed and they float")
