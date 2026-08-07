extends GutTest

## Partition audits (spec §3): every carved flank face belongs to a house;
## footprints stay in the 1x1..2x3 family; tops follow the terraced massif.
##
## Building a massif and boring a route costs seconds per seed, so every town
## is built once and shared by the whole suite. The partition under test is
## rebuilt per call where a test needs a pristine (unsealed) copy.

const CORPUS: Array[int] = [0, 1, 3, 5]
## Deliberately stricter than WarrenSolidPartitioner's own admission rule and
## derived without calling it: two full storeys of unexcavated solid above the
## street floor, on unexcavated ground. Anything this obviously buildable is a
## wall the partition may not leave to nobody.
const STRICT_WALL_BANDS := 6

var _towns: Dictionary = {}


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
		assert_gt(walls.size(), 15,
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
			assert_true(plan.has_walk(parcel.address_walk_cell),
				"seed %d: parcel %s addresses a cell that is not a walk" \
				% [world_seed, parcel.stable_id])
			assert_gt(int(WarrenParcelConstruction.proposal(parcel).get(
					"storeys", 0)), 1,
				("seed %d: parcel %s builds as a visually short house, which " \
				+ "production forbids") % [world_seed, parcel.stable_id])


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
		out = {
			"massif": massif,
			"excavation": excavation,
			"plan": WarrenExcavationVolumeAdapter.to_volume_plan(massif,
				excavation),
			"parcels": WarrenSolidPartitioner.partition(massif, excavation),
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
