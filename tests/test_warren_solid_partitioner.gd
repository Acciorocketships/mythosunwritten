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
const CORPUS: Array[int] = [0, 1, 3, 4, 5, 6, 9]
## Seeds whose whole mass-first frontier is built, so the parcel stage can be
## audited against the volume production actually hands it -- arcade and
## gallery walk cells included. Three towns cost roughly 45s, which is why this
## is a short list rather than CORPUS.
const FRONTIER_CORPUS: Array[int] = [1, 5, 9]
## Deliberately stricter than WarrenSolidPartitioner's own admission rule and
## derived without calling it: two full storeys of unexcavated solid above the
## street floor, on unexcavated ground. Anything this obviously buildable is a
## wall the partition may not leave to nobody.
const STRICT_WALL_BANDS := 6
## Fill sites the partition may leave standing across FRONTIER_CORPUS, and only
## for the one declared reason: an optional house is never placed when its roof
## cannot join a neighbour's or when it would meet one across a corner.
## A MEASURED RESIDUE, NOT A TARGET. Attributed by experiment rather than by
## argument: 43 sites stood unbuilt before the fill pass and 10 after, and
## deleting the fill pass's roof/corner refusal takes those 10 to zero, so every
## one of them is that refusal and none is a hole in the fill.
## Re-measured at 18 on FRONTIER_CORPUS [1, 5, 9] once WarrenMassifBuilder
## stopped exempting boundary columns from its step limit: a shorter massif
## offers fewer joinable neighbours per site, so the same refusal leaves a
## larger residue. Still a measured residue, not a target.
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


func test_partition_owns_every_route_flank() -> void:
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
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
	for world_seed: int in CORPUS:
		var town := _town(world_seed)
		if town.is_empty():
			continue
		var owned := _owned_cells(town["parcels"] as Array[WarrenBuildingParcel])
		var columns := _owned_columns(
			town["parcels"] as Array[WarrenBuildingParcel])
		var walls := _strict_walls(town["massif"] as WarrenMassif,
			town["excavation"] as WarrenExcavation)
		# Sample-size guard, re-measured to 12 after the rim step rule: seed 0's
		# massif is shorter, so fewer columns carry STRICT_WALL_BANDS of solid
		# above a street. Lowest observed across CORPUS is 14.
		assert_gt(walls.size(), 12,
			"seed %d: too few walls re-derived to prove anything" % world_seed)
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
		assert_gt(int(audit["wall_count"]), 60,
			"seed %d: too few raw walls to prove anything" % world_seed)
		assert_gt(int(audit["owned_count"]), 20,
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
			assert_gt(int(WarrenParcelConstruction.proposal(parcel).get(
					"storeys", 0)), 1,
				("seed %d: parcel %s builds as a visually short house, which " \
				+ "production forbids") % [world_seed, parcel.stable_id])


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
	## Five of seven, measured. The residue is a real vocabulary gap, not slack
	## left in the search: on seeds 3 and 4 two perpendicular streets pass
	## adjacent columns whose terraces each admit exactly one legal roof height,
	## so neither house can step and the corner between them is a perpendicular
	## valley -- for which the authored table has a recipe only between two
	## width-two houses, and these are one column wide. The partition reports
	## the conflict rather than hiding it, and the frontier drops the candidate.
	## Tighten this bound if the valley vocabulary ever covers narrow houses.
	assert_gt(clean, CORPUS.size() - 3,
		("at most two corpus seeds may be left with an unjoinable corner; " \
		+ "only %d of %d compiled") % [clean, CORPUS.size()])


func test_equal_roof_bands_never_meet_across_a_corner() -> void:
	## The rule the partitioner enforces, checked independently of the code that
	## enforces it: re-derives adjacency and frontage from the parcels and
	## asserts no two houses share a roof band across a corner, because a
	## perpendicular valley between the width-one houses the leftover solid
	## mostly yields has no recipe at all. Together with the test above this
	## pins both halves -- that the rule holds, and that holding it is what
	## makes the real module table accept the plan.
	var equal_pairs := 0
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
				if left.top_band != right.top_band \
						or not _footprints_touch(left.footprint,
							right.footprint):
					continue
				equal_pairs += 1
				corners += int((left.frontage_direction.x == 0) \
					!= (right.frontage_direction.x == 0))
		if int(town["unjoinable"]) != 0:
			# One house with no joinable roof can abut two neighbours, so the
			# reported count bounds the houses involved, not the pairs. What
			# must hold is that a partition claiming success has no corners.
			continue
		assert_eq(corners, 0,
			("seed %d: %d equal-height corner pairs in a partition that " \
			+ "reported every roof joinable") % [world_seed, corners])
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
		## on every buildable street wall, and a route winding through a solid
		## puts those walls diagonally opposite one another constantly. Per seed
		## the count runs 4-11. This bound exists so the number cannot grow
		## unnoticed while the real fix is decided; it is NOT an acceptance of
		## interpenetrating geometry, which still blocks composition.
		assert_between(corners, 0, 12,
			"seed %d: %d corner-only house pairs" % [world_seed, corners])


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
	## Splitting the datum stops a house descending to the valley floor, which
	## leaves real source mass between natural ground and its lowest room.
	## Nothing renders unbuilt massif mass, so unless the house DECLARES that
	## gap it stands on nothing. The declaration must be exactly the gap --
	## short and the house floats, long and it buries a storey.
	var declared := 0
	var houses_on_a_hill := 0
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
			var expected := 0
			for column: Vector2i in parcel.footprint:
				expected += 4 * maxi(0, support - envelope.ground_at(column))
			var terrace := WarrenParcelConstruction.retained_terrace_cells(
				parcel)
			assert_eq(terrace.size(), expected,
				"seed %d: %s stands %d bands above ground and declares %d " \
				% [world_seed, parcel.stable_id, support, terrace.size()]
				+ "terrace cells, not %d" % expected)
			declared += terrace.size()
			houses_on_a_hill += int(expected > 0)
			for cell: Vector3i in terrace:
				var macro_cell := Vector3i(floori(float(cell.x) / 2.0), cell.y,
					floori(float(cell.z) / 2.0))
				assert_false(occupied.has(macro_cell),
					"seed %d: %s retains %s, which a house already occupies" \
					% [world_seed, parcel.stable_id, macro_cell])
				assert_true(parcel.source.has_mass(macro_cell),
					"seed %d: %s retains %s, which the excavation removed" \
					% [world_seed, parcel.stable_id, macro_cell])
	assert_gt(houses_on_a_hill, 40,
		"only %d houses across the corpus stand on a terrace at all" \
		% houses_on_a_hill)
	assert_gt(declared, 0, "no hill was declared anywhere")


func test_footprints_stay_in_the_authored_family() -> void:
	## Every shape must have an authored roof profile downstream. A footprint
	## outside WarrenParcelConstruction's four profiles compiles to nothing at
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


func test_partition_is_deterministic_and_ignores_the_optional_plan() -> void:
	## Integer hashes only: no randf, no Time, no engine RNG. The optional
	## volume plan seals the result, and must not be able to change which
	## houses were chosen -- the solid predicate it carries is the same one
	## derived from the massif and the excavation.
	var town := _town(1)
	assert_false(town.is_empty())
	var massif := town["massif"] as WarrenMassif
	var excavation := town["excavation"] as WarrenExcavation
	var first := WarrenSolidPartitioner.partition(massif, excavation)
	var second := WarrenSolidPartitioner.partition(massif, excavation)
	var sealed_run := WarrenSolidPartitioner.partition(massif, excavation,
		town["plan"] as WarrenVolumePlan)
	assert_eq(_signature(first), _signature(second),
		"two partitions of one excavation must be identical")
	assert_eq(_signature(first), _signature(sealed_run),
		"sealing must not change which houses the partition chose")


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
	## The single-seed tests above could be luck. Re-checks the two claims that
	## make this stage usable -- enough houses, and no stranded street wall --
	## on every seed whose massif and route were accepted.
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
	assert_gt(accepted, 2, "corpus produced too few towns to be a corpus")


func _town(world_seed: int) -> Dictionary:
	if _towns.has(world_seed):
		return _towns[world_seed] as Dictionary
	var out: Dictionary = {}
	var massif := WarrenMassifBuilder.build(world_seed)
	var excavation := null if massif == null \
		else WarrenExcavationCarver.carve(world_seed, massif)
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
