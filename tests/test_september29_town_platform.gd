extends GutTest

## September 29 town review (tiers): multi-level towns. A deterministic subset
## of towns raise a citadel district on a rock plinth one or two storeys above
## the lower town (WarrenTownPlatform). See
## docs/qa/2026-09-29-town-review/tiers/design.md.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
## Platform towns of the probe corpus (city seed, profile): one per size, and
## one with a two-storey plinth.
const PLATFORM_TOWNS := [[3, &"compact"], [13, &"standard"], [27, &"large"],
	[6, &"standard"]]
## A town without a platform, pinned to its baseline source signature.
const PLAIN_TOWN := [1, &"compact"]
## Houses on at least this share of the platform columns not taken by its
## lanes (measured 0.50-1.0 over the 40-seed probe; 0.0-0.3 on several
## platforms before the huddle/gate/bridge rules).
const MIN_UPPER_TOWN_COVERAGE := 0.45

static var _sources: Dictionary = {}
static var _built: Dictionary = {}


func _source(job: Array) -> WarrenMazeSourcePlan:
	var key := "%d:%s" % [job[0], job[1]]
	if not _sources.has(key):
		_sources[key] = WarrenMazeSitePlanner.plan(int(job[0]), {},
			WarrenVillageScaleProfile.for_id(job[1]), &"", false)
	return _sources[key]


func _town(job: Array) -> Dictionary:
	var key := "%d:%s" % [job[0], job[1]]
	if not _built.has(key):
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var spatial := FROZEN.spatial(_source(job), program)
		_built[key] = {"spatial": spatial,
			"built": KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
				SuntailBuildingKit.create())}
	return _built[key]


## Invariant 1: platforms are a random subset of towns (at their production
## sizes) -- roughly a third to a half, never all and never none -- and each
## has a real district's size.
func test_platform_towns_are_a_deterministic_subset() -> void:
	var raised := 0
	var total := 200
	for seed_value in range(1, total + 1):
		var massif := WarrenMassifBuilder.build(seed_value, {},
			WarrenVillageScaleProfile.select(seed_value))
		var columns := massif.platform_columns()
		if columns.is_empty():
			continue
		raised += 1
		assert_gte(columns.size(), WarrenTownPlatform.MIN_COLUMNS,
			"seed %d raises a platform too small to be a district" % seed_value)
		var lowest := 2147483647
		var highest := 0
		for column: Vector2i in columns:
			var bands := massif.plinth_at(column)
			lowest = mini(lowest,bands)
			highest = maxi(highest,bands)
			assert_eq(bands % 4,0,"each nested district adds a complete two-storey tier")
		assert_eq(lowest,4,"the outer plinth remains two storeys")
		assert_eq(massif.platform_bands,highest,"the summary records the highest tier")
		assert_true(massif.is_platform(massif.crown_column),
			"seed %d: the citadel is the town's crown" % seed_value)
	var share := float(raised) / float(total)
	assert_between(share, 0.25, 0.5, "platform share %.2f" % share)
	# Deterministic: the same seed raises the same platform.
	var a := WarrenMassifBuilder.build(3, {}, WarrenVillageScaleProfile.for_id(&"compact"))
	var b := WarrenMassifBuilder.build(3, {}, WarrenVillageScaleProfile.for_id(&"compact"))
	assert_eq(a.platform_columns(), b.platform_columns())


## Invariant 2 + 3: the plinth is closed rock -- never bored; the way up is
## the gate flight outside it -- and every house on the platform stands on
## it; the upper town is densely built (gardens are the exception).
func test_plinth_is_solid_and_the_district_is_built_up() -> void:
	for job: Array in PLATFORM_TOWNS:
		var source := _source(job)
		assert_not_null(source, "%s builds" % [job])
		if source == null:
			continue
		var massif := source.massif
		assert_false(massif.platform_columns().is_empty(), "%s has a platform" % [job])
		var holes: Array[Vector3i] = []
		for column: Vector2i in massif.platform_columns():
			for band in range(massif.base_at(column), massif.bearing_at(column)):
				var cell := Vector3i(column.x, band, column.y)
				if not source.solid_at(cell):
					holes.append(cell)
		assert_eq(holes, [] as Array[Vector3i], "%s plinth holes" % [job])
		var built: Dictionary = {}
		var lanes: Dictionary = {}
		for cell: Vector3i in source.passage_kinds:
			var column := Vector2i(cell.x, cell.z)
			if massif.is_platform(column) and cell.y == massif.bearing_at(column):
				lanes[column] = true
		for plot: Dictionary in source.plots:
			for column: Vector2i in plot.cells:
				if not massif.is_platform(column):
					continue
				built[column] = true
				assert_gte(int(plot.floor), massif.bearing_at(column),
					"%s plot %s stands inside the plinth" % [job, plot.id])
		var open := massif.platform_columns().size() - lanes.size()
		var share := float(built.size()) / float(maxi(1, open))
		assert_gte(share, MIN_UPPER_TOWN_COVERAGE,
			"%s: only %d of %d non-lane platform columns carry houses" % [job,
				built.size(), open])


## The lower town huddles at the plinth's foot: within
## WarrenTownPlatform.HUDDLE_RINGS of the district no house rises above the
## plinth top, so the citadel stands clear of it from a distance.
func test_lower_town_huddles_under_the_plinth_top() -> void:
	for job: Array in PLATFORM_TOWNS:
		var source := _source(job)
		if source == null:
			continue
		var massif := source.massif
		var over: Array[String] = []
		for plot: Dictionary in source.plots:
			for column: Vector2i in plot.cells:
				var cap := WarrenTownPlatform.huddle_top(massif, column)
				if cap != 2147483647 and int(plot.top) > cap:
					over.append("%s@%s top %d > %d" % [plot.id, column, plot.top, cap])
		assert_eq(over, [] as Array[String], "%s houses overtop the plinth" % [job])


## Invariant 4: the upper town is a quarter of houses reached from the gate.
func test_upper_town_is_reached_from_the_gate_and_built_up() -> void:
	for job: Array in PLATFORM_TOWNS:
		var source := _source(job)
		if source == null:
			fail_test("%s does not build" % [job])
			continue
		var massif := source.massif
		var edges := source.excavation.walk_edges()
		var adjacent: Dictionary = {}
		for edge: Dictionary in edges:
			for pair: Array in [[edge.a, edge.b], [edge.b, edge.a]]:
				if not adjacent.has(pair[0]):
					adjacent[pair[0]] = []
				(adjacent[pair[0]] as Array).append(pair[1])
		var start: Vector3i = source.excavation.route[0]
		var seen: Dictionary = {start: true}
		var queue: Array[Vector3i] = [start]
		while not queue.is_empty():
			var cell: Vector3i = queue.pop_back()
			for next: Vector3i in adjacent.get(cell, []):
				if not seen.has(next):
					seen[next] = true
					queue.append(next)
		var upper := 0
		for cell: Vector3i in seen:
			var column := Vector2i(cell.x, cell.z)
			upper += int(massif.is_platform(column) \
				and cell.y == massif.bearing_at(column))
		assert_gt(upper, 0, "%s: the gate reaches the platform grade" % [job])
		var gates := source.excavation.lanes.filter(func(lane: Dictionary) -> bool:
			return StringName(lane.get("feature_kind", &"")) == &"citadel_gate")
		assert_eq(gates.size(), 1, "%s: one gate flight climbs to the district" % [job])
		var built: Dictionary = {}
		for plot: Dictionary in source.plots:
			for column: Vector2i in plot.cells:
				if massif.is_platform(column):
					built[column] = true
		assert_gt(built.size(), 0, "%s: the platform carries houses" % [job])
		gut.p("%s: %d of %d platform columns carry houses" % [job, built.size(),
			massif.platform_columns().size()])


## Invariant 5: the plinth reads as a fortification -- plain coursed stone
## (no timber frame, no timber posts), a crenellated parapet on its open rim,
## turrets, a stone gate -- and every course of it reaches the ground.
func test_plinth_is_a_grounded_stone_fortification() -> void:
	var job: Array = PLATFORM_TOWNS[1]
	var town := _town(job)
	var wall: BuildingMass = null
	for mass: BuildingMass in town.built.masses:
		if mass.stable_id == &"kit.platform-wall":
			wall = mass
	assert_not_null(wall, "the plinth is its own kit mass")
	if wall == null:
		return
	for storey: Dictionary in wall.storeys:
		assert_true(bool(storey.get("fortified", false)))
	var spatial: WarrenSpatialPlan = town.spatial
	var envelope := spatial.source_volume.envelope
	var bands: Dictionary = {}
	for storey: Dictionary in wall.storeys:
		for cell: Vector2i in storey.cells:
			var column: Array = bands.get(cell, [])
			for band in range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2))):
				column.append(band)
			bands[cell] = column
	var floating: Array[Vector2i] = []
	for cell: Vector2i in bands:
		var ground := envelope.ground_at(Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0)))
		if (bands[cell] as Array).min() > ground:
			floating.append(cell)
	assert_eq(floating, [] as Array[Vector2i], "plinth courses that do not reach ground")
	var pieces := 0
	var rim_pieces := 0
	var rim_y := float(spatial.source_volume.mass_context.get(&"massif").platform_bands) \
		* SuntailBuildingKit.create().band_height()
	for placement: Dictionary in town.built.placements:
		if not String(placement.stable_id).begins_with("kit.platform-wall"):
			continue
		assert_eq(placement.asset_id, &"suntail.stone.stone_wall_plain",
			"plinth piece %s is %s" % [placement.stable_id, placement.asset_id])
		pieces += 1
		rim_pieces += int((placement.transform as Transform3D).origin.y >= rim_y - 0.01)
	assert_gt(pieces, 0, "the plinth shows stone")
	assert_gt(rim_pieces, 0, "parapet, turret and gate stone rises above the rim")


## Invariant 6: ordinary towns remain unfortified and deterministic.
func test_town_without_platform_stays_plain_and_deterministic() -> void:
	var source := _source(PLAIN_TOWN)
	assert_eq(source.massif.platform_bands, 0)
	assert_true(source.massif.platform_columns().is_empty())
	assert_eq(source.deterministic_signature().sha256_text(), PLAIN_SIGNATURE)
	var rebuilt := WarrenMazeSitePlanner.plan(int(PLAIN_TOWN[0]), {},
		WarrenVillageScaleProfile.for_id(PLAIN_TOWN[1]), &"", false)
	assert_eq(rebuilt.deterministic_signature(), source.deterministic_signature(),
		"compare independent construction, not the cached source with itself")


## Re-pinned by the edges stream (September 29): the perimeter lane and the
## at-grade edge rings re-lay every town, platform or not; again for the
## held landmark sites (follow-up).
# October 1: bridge load paths are reserved before optional streets, and
# secondary gate seeds now obey the same boring restrictions as later steps.
# The requested redesign changes ordinary layouts too. Previous signature:
# d041885315922100395fd17c5ecd5aa33b60b0331ea304264a6801aaf78d6fa9.
const PLAIN_SIGNATURE := "5ae4c01fe993d8e71d258440646a61f9a3d0efb12bd55ee25bf6795c718bef51"
