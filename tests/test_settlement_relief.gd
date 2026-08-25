extends GutTest

## WAVE 2 of the warren/terrain integration: the SETTLEMENT RELIEF STAMP.
##
## SettlementReliefPlan is duck-typed into HeightfieldPlan._sample exactly the
## way the water carve is -- a monotone modification of the continuous field
## BEFORE quantization -- so the town's hill becomes real heightfield that the
## existing stack meshes, dresses with KayKit cliffs, suppresses grass on and
## collides. This suite pins the stamp's contract
## (docs/superpowers/specs/2026-08-09-warren-terrain-integration-design.md §3.2),
## the design's §3.3 stamp property, the storey-ceiling risk (§6 risk 2) and the
## portal grade bench Wave 1 found the excavation needs.

const CORPUS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
## The chain tests build a massif and bore it, which costs seconds per seed.
const CHAIN_CORPUS: Array[int] = [1, 3, 5, 7, 11]
const FLAT_GROUND_M := 4.0
const AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const MAX_STOREYS := TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS
## Massif columns run to RADIUS_CELLS; one spare ring so the rim's own
## neighbours are sampled too.
const COLUMN_SPAN := WarrenMassifBuilder.RADIUS_CELLS + 1
const SITE_CELL := Vector2i(6, 5)
const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## A single settlement at a known cell, so the shape tests are about the STAMP
## rather than about which super cell of which seed happens to hold a site.
## Duck-typed on site_for, the one method SettlementReliefPlan asks for.
class FixedSites:
	extends RefCounted
	var _cell: Vector2i

	func _init(cell: Vector2i) -> void:
		_cell = cell

	func site_for(super_cell: Vector2i) -> Dictionary:
		if super_cell != SettlementPlan.super_of(_cell):
			return {}
		return {"id": &"test.settlement", "cell": _cell}


## A carve placed exactly on a stamped cell, so the "zero where the carve bites"
## rule is exercised rather than merely never contradicted. Duck-typed on
## carve_at_cell, the one method HeightfieldPlan asks a water plan for.
class CrownCarve:
	extends RefCounted
	var _cell: Vector2i
	var _depth: float

	func _init(cell: Vector2i, depth: float) -> void:
		_cell = cell
		_depth = depth

	func carve_at_cell(cx: int, cz: int) -> float:
		return _depth if Vector2i(cx, cz) == _cell else 0.0


func _flat_relief(world_seed: int, budget: float = -1.0,
		cell: Vector2i = SITE_CELL) -> SettlementReliefPlan:
	var budget_metres := SettlementReliefPlan.RELIEF_BUDGET_METRES \
		if budget < 0.0 else budget
	var relief := SettlementReliefPlan.new(world_seed, FixedSites.new(cell),
		AMPLITUDE, MAX_STOREYS, budget_metres)
	return relief


func _flat_plan(world_seed: int, relief: SettlementReliefPlan,
		ground: float = FLAT_GROUND_M) -> HeightfieldPlan:
	## A synthetic FLAT world plus the stamp. Design §3.8 keeps settlement site
	## SCORING out of this milestone, so "does the hill read" is a question about
	## STAMP mode on ordinary ground; a constant field is that question with the
	## natural noise held still. HeightfieldPlan forwards the override to the
	## stamp, so both sides agree about what the ground is.
	var plan := HeightfieldPlan.new(world_seed, AMPLITUDE, MAX_STOREYS, "mean",
		TerrainWorldTuning.MAX_CLIFF_STEP)
	if relief != null:
		plan.set_relief_plan(relief)
	plan.set_raw_height_override(func(_cx: int, _cz: int) -> float:
		return ground)
	return plan


func _cliff_top(region: HeightfieldRegion, cx: int, cz: int) -> bool:
	## The design's own definition (TerrainSurfaceField._is_cliff_top): any
	## neighbour, cardinal or diagonal, two or more storeys below. Restated here
	## rather than borrowed so the property is checked against the spec and not
	## against the implementation it constrains.
	var here := region.storey_at(cx, cz)
	for d: Vector2i in _NEIGHBOURS:
		if here - region.storey_at(cx + d.x, cz + d.y) >= 2:
			return true
	return false


func _ground_bands(region: HeightfieldRegion, site: Vector2i) -> Dictionary:
	## VillageWarrenFabricSolver._sample_ground_bands, reproduced against a fixed
	## region: five probes per 3 m column, ceil of the column maximum. The datum
	## is the LOWEST sampled surface rather than the production adapter's
	## entry-relative datum, so every band is >= 0 without asking this suite to
	## take a position on frame placement (Wave 6's problem).
	var view := VillageTerrainView.from_region(region)
	var origin := Vector2(float(site.x) * TerrainSurfaceField.TILE,
		float(site.y) * TerrainSurfaceField.TILE)
	var half := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.45
	var maxima: Dictionary = {}
	var lowest := INF
	for z in range(-COLUMN_SPAN, COLUMN_SPAN + 1):
		for x in range(-COLUMN_SPAN, COLUMN_SPAN + 1):
			var centre := origin + Vector2(
				float(x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
				float(z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
			var column_max := -INF
			for offset: Vector2 in [Vector2.ZERO,
					Vector2(-half, -half), Vector2(half, -half),
					Vector2(-half, half), Vector2(half, half)]:
				var height := view.surface_y(centre + offset)
				column_max = maxf(column_max, height)
				lowest = minf(lowest, height)
			maxima[Vector2i(x, z)] = column_max
	var bands: Dictionary = {}
	for column: Vector2i in maxima:
		bands[column] = ceili((float(maxima[column]) - lowest)
			/ WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
	return {"bands": bands, "datum": lowest, "maxima": maxima}


func _column_point(site: Vector2i, column: Vector2i) -> Vector2:
	return Vector2(float(site.x) * TerrainSurfaceField.TILE
			+ float(column.x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
		float(site.y) * TerrainSurfaceField.TILE
			+ float(column.y) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)


func _same_band_run(bands: Dictionary, seeds: Dictionary) -> Dictionary:
	## Largest 4-connected run of columns sharing one ground band that contains
	## at least one column of `seeds`, with its Manhattan spread. This is what
	## the excavation's grade phase can actually lay a ground street on: Wave 1
	## proved at-grade streets are CONTOUR-BOUND, because every action's first
	## stride cell sits on the move's starting band, so the run must be flat and
	## not merely gentle.
	var visited: Dictionary = {}
	var best := {"cells": 0, "spread": 0}
	for start_value: Variant in bands.keys():
		var start := start_value as Vector2i
		if visited.has(start) or not seeds.has(start):
			continue
		var band: int = bands[start]
		var frontier: Array[Vector2i] = [start]
		var members: Array[Vector2i] = []
		visited[start] = true
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			members.append(cell)
			for d: Vector2i in _CARDINALS:
				var nb := cell + d
				if visited.has(nb) or not bands.has(nb) \
						or int(bands[nb]) != band:
					continue
				visited[nb] = true
				frontier.append(nb)
		if members.size() <= int(best.cells):
			continue
		var spread := 0
		for i in members.size():
			for j in range(i + 1, members.size()):
				spread = maxi(spread, absi(members[i].x - members[j].x)
					+ absi(members[i].y - members[j].y))
		best = {"cells": members.size(), "spread": spread}
	return best


func _grade_reading(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	var cells: Array[Vector3i] = []
	for cell: Vector3i in excavation.route:
		if cell.y == massif.base_at(Vector2i(cell.x, cell.z)):
			cells.append(cell)
	var spread := 0
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			spread = maxi(spread, absi(cells[i].x - cells[j].x)
				+ absi(cells[i].z - cells[j].z))
	return {"cells": cells.size(), "spread": spread}


# --------------------------------------------------------------------------
# Contract: determinism, monotonicity, and the two disable paths
# --------------------------------------------------------------------------

func test_relief_is_deterministic_across_independently_built_plans() -> void:
	## Mirrors tests/test_water_plan.gd's determinism pin: two plans that never
	## met must agree cell for cell, because the stamp is a pure function of
	## (world_seed, SEED_VERSION, cell) and its memos never change a value.
	for world_seed: int in [0, 7, 11]:
		var a := _flat_relief(world_seed)
		var b := _flat_relief(world_seed)
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				var cell := SITE_CELL + Vector2i(dx, dz)
				assert_eq(a.relief_at_cell(cell.x, cell.y),
					b.relief_at_cell(cell.x, cell.y),
					"seed %d disagreed at %s" % [world_seed, str(cell)])


func test_relief_only_ever_raises() -> void:
	## The mirror of the carve's monotone lower. Checked as a value property AND
	## as a field property: the composed raw_height with the stamp is never below
	## the same world without it.
	for world_seed: int in CORPUS:
		var relief := _flat_relief(world_seed)
		var stamped := _flat_plan(world_seed, relief)
		var bare := _flat_plan(world_seed, null)
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				var cell := SITE_CELL + Vector2i(dx, dz)
				var value := relief.relief_at_cell(cell.x, cell.y)
				assert_true(value >= 0.0,
					"seed %d relief %f at %s" % [world_seed, value, str(cell)])
				assert_true(stamped.raw_height(cell.x, cell.y)
					>= bare.raw_height(cell.x, cell.y) - 1e-6,
					"seed %d lowered the field at %s" % [world_seed, str(cell)])


func test_a_zero_budget_leaves_the_field_bit_identical() -> void:
	## "Byte-identical when the budget is 0" is the milestone's own safety
	## requirement, and it must hold on the REAL noise field, not just a flat one.
	var world_seed := 7
	var water := TerrainWorldTuning.make_water(world_seed)
	var settlements := SettlementPlan.new(world_seed, water)
	var zero := SettlementReliefPlan.new(world_seed, settlements, AMPLITUDE,
		MAX_STOREYS, 0.0)
	var stamped := TerrainWorldTuning.make_heightfield(world_seed, water, zero)
	var bare := TerrainWorldTuning.make_heightfield(world_seed, water)
	var site: Vector2i = _first_site(settlements)
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			assert_eq(stamped.raw_height(site.x + dx, site.y + dz),
				bare.raw_height(site.x + dx, site.y + dz),
				"zero budget moved the field at %s" % str(Vector2i(dx, dz)))


func test_no_relief_plan_leaves_the_field_bit_identical() -> void:
	## The route-first canary in miniature: attaching and clearing the stamp must
	## return the plan to exactly the world it started in.
	var world_seed := 3
	var water := TerrainWorldTuning.make_water(world_seed)
	var settlements := SettlementPlan.new(world_seed, water)
	var plan := TerrainWorldTuning.make_heightfield(world_seed, water)
	var site: Vector2i = _first_site(settlements)
	var before: Array[float] = []
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			before.append(plan.raw_height(site.x + dx, site.y + dz))
	plan.set_relief_plan(SettlementReliefPlan.new(world_seed, settlements,
		AMPLITUDE, MAX_STOREYS))
	plan.set_relief_plan(null)
	var index := 0
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			assert_eq(plan.raw_height(site.x + dx, site.y + dz), before[index])
			index += 1


func test_relief_is_zero_where_the_water_carve_bites() -> void:
	## Two height writers, one field: the carve owns any cell it touches, so the
	## stamp can never fill a channel back in. Proved twice -- once against a
	## synthetic carve placed deliberately on the crown, so the rule is actually
	## exercised, and once over a real world, where the answer is that the two
	## never even meet because the radii keep them apart.
	var world_seed := 5
	var relief := _flat_relief(world_seed)
	var flooded := _flat_plan(world_seed, relief)
	flooded.set_water_plan(CrownCarve.new(SITE_CELL, 3.0))
	var dry := _flat_plan(world_seed, null)
	dry.set_water_plan(CrownCarve.new(SITE_CELL, 3.0))
	assert_gt(relief.relief_at_cell(SITE_CELL.x, SITE_CELL.y), 0.0,
		"the synthetic carve was not placed on a stamped cell")
	assert_eq(flooded.raw_height(SITE_CELL.x, SITE_CELL.y),
		dry.raw_height(SITE_CELL.x, SITE_CELL.y),
		"the stamp raised a carved cell")

	var water := TerrainWorldTuning.make_water(world_seed)
	var settlements := SettlementPlan.new(world_seed, water)
	var real := SettlementReliefPlan.new(world_seed, settlements, AMPLITUDE,
		MAX_STOREYS)
	var stamped := TerrainWorldTuning.make_heightfield(world_seed, water, real)
	var bare := TerrainWorldTuning.make_heightfield(world_seed, water)
	var site: Vector2i = _first_site(settlements)
	var contested := 0
	var radius := int(ceil(real.outer_radius_metres()
		/ TerrainSurfaceField.TILE)) + 1
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := site + Vector2i(dx, dz)
			if water.carve_at_cell(cell.x, cell.y) <= 0.0:
				continue
			contested += 1
			assert_eq(stamped.raw_height(cell.x, cell.y),
				bare.raw_height(cell.x, cell.y),
				"the stamp raised a carved cell at %s" % str(cell))
	assert_eq(contested, 0,
		"a real settlement stamp overlapped the water carve")
	gut.p("carve/stamp contested cells within the stamp radius: %d" % contested)


func test_stamp_radius_stays_inside_the_water_clearance() -> void:
	## SettlementPlan keeps every site at least WATER_CLEARANCE from planned
	## water; a stamp narrower than that clearance can never argue with a carve.
	## This is the test that must fail if the reviewer's ruling raises the budget
	## past what the site spacing supports.
	var outer := SettlementReliefPlan.outer_radius_cells(
		SettlementReliefPlan.RELIEF_BUDGET_METRES)
	assert_lt(outer * TerrainSurfaceField.TILE, SettlementPlan.WATER_CLEARANCE,
		"the relief budget outgrew SettlementPlan.WATER_CLEARANCE")


func test_stamp_cannot_leave_its_own_settlement_super_cell() -> void:
	## SettlementPlan._compute_site places a site at offset [8, 23] inside its
	## 32-cell super cell, so a stamp narrower than 8 cells never crosses a super
	## boundary -- which is what lets relief_at_cell resolve its site with ONE
	## lookup instead of scanning a neighbourhood. Pinning it here means a budget
	## rise that breaks the assumption fails loudly instead of silently clipping
	## half a hill.
	assert_lt(SettlementReliefPlan.outer_radius_cells(
		SettlementReliefPlan.RELIEF_BUDGET_METRES), 8.0,
		"a stamp this wide can reach a neighbouring super cell")
	var relief := _flat_relief(4, -1.0, Vector2i(8, 8))
	var boundary := SettlementPlan.SUPER_CELLS
	for offset in range(-3, 4):
		assert_eq(relief.relief_at_cell(boundary + offset, 8), 0.0)
		assert_eq(relief.relief_at_cell(8, boundary + offset), 0.0)


func test_window_independence_across_chunk_centres() -> void:
	## The stamp is a per-cell pure function, so quantize_storey still clamps
	## every target into [0, max_storeys] and HeightfieldPlan.storey_margin()'s
	## proof is untouched. Two windows centred two chunks apart must therefore
	## agree cell for cell over their overlap.
	var world_seed := 9
	var relief := _flat_relief(world_seed)
	var plan := _flat_plan(world_seed, relief)
	var near := plan.compute_region(SITE_CELL.x, SITE_CELL.y, 6)
	var far := plan.compute_region(
		SITE_CELL.x + 2 * TerrainChunkMesher.CELLS_PER_CHUNK,
		SITE_CELL.y + 2 * TerrainChunkMesher.CELLS_PER_CHUNK, 24)
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var cell := SITE_CELL + Vector2i(dx, dz)
			assert_eq(near.storey_at(cell.x, cell.y),
				far.storey_at(cell.x, cell.y),
				"storey disagreed at %s" % str(cell))
			assert_eq(near.level_at(cell.x, cell.y),
				far.level_at(cell.x, cell.y),
				"level disagreed at %s" % str(cell))


# --------------------------------------------------------------------------
# Design risk 2: the quantizer's 8-storey clamp
# --------------------------------------------------------------------------

func test_the_shipped_budget_never_reaches_the_storey_clamp() -> void:
	## RISK 2, made loud. quantize_storey clamps to [0, max_storeys]; a stamp
	## that reaches it saturates and renders the hilltop as the wide flat plateau
	## MAX_PLATEAU_CELLS exists to forbid, and raising HEIGHTFIELD_MAX_STOREYS is
	## forbidden because it is the clamp window margin and re-rolls the world.
	## So: over the corpus, on the real field, the ceiling clamp must never have
	## had to bite and no stamped cell may quantize to max_storeys.
	var worst := 0.0
	var highest := 0
	for world_seed: int in CORPUS:
		var water := TerrainWorldTuning.make_water(world_seed)
		var settlements := SettlementPlan.new(world_seed, water)
		var site: Vector2i = _first_site(settlements)
		if site.x == 2147483647:
			continue
		var relief := SettlementReliefPlan.new(world_seed, settlements,
			AMPLITUDE, MAX_STOREYS)
		var plan := TerrainWorldTuning.make_heightfield(world_seed, water,
			relief)
		var region := plan.compute_region(site.x, site.y, 5)
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				var storey := region.storey_at(site.x + dx, site.y + dz)
				highest = maxi(highest, storey)
				assert_lt(storey, MAX_STOREYS,
					"seed %d saturated the storey clamp at %s" % [world_seed,
						str(Vector2i(dx, dz))])
		worst = maxf(worst, relief.ceiling_deficit_metres)
		assert_false(relief.ceiling_clamped,
			"seed %d needed the ceiling clamp (deficit %.2f m)" % [world_seed,
				relief.ceiling_deficit_metres])
	gut.p("storey-clamp headroom: tallest stamped storey %d of %d, worst "
		% [highest, MAX_STOREYS] + "ceiling deficit %.2f m" % worst)


func test_the_storey_ceiling_clamp_has_teeth() -> void:
	## Sabotage direction: a budget that WOULD reach the clamp must be caught.
	## A 40 m stamp on 20 m of ground saturates a 32 m ceiling outright, so the
	## clamp reports a deficit and holds the crown below max_storeys -- proving
	## the tripwire above is measuring something real rather than a budget that
	## could never have reached it.
	var relief := _flat_relief(2, 40.0)
	var plan := _flat_plan(2, relief, 20.0)
	var region := plan.compute_region(SITE_CELL.x, SITE_CELL.y, 5)
	assert_true(relief.ceiling_clamped,
		"an over-budget stamp did not report reaching the ceiling")
	assert_gt(relief.ceiling_deficit_metres, 0.0)
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			assert_lt(region.storey_at(SITE_CELL.x + dx, SITE_CELL.y + dz),
				MAX_STOREYS,
				"the clamp let a cell saturate at %s" % str(Vector2i(dx, dz)))


# --------------------------------------------------------------------------
# Shape: no cliff top in town, a walkable approach, and flat benches
# --------------------------------------------------------------------------

func test_no_cliff_top_inside_the_built_footprint() -> void:
	## Design §3.2 slope discipline. Inside the town footprint the profile's
	## per-cell gradient is bounded so that no cell has a neighbour two or more
	## storeys below -- a cliff top there would be unwalkable ground under the
	## houses. Beyond the footprint, steps are allowed and become dressed crag.
	var footprint := int(ceil(float(WarrenMassifBuilder.RADIUS_CELLS)
		* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M / TerrainSurfaceField.TILE))
	for world_seed: int in CORPUS:
		var relief := _flat_relief(world_seed)
		var plan := _flat_plan(world_seed, relief)
		var region := plan.compute_region(SITE_CELL.x, SITE_CELL.y, 6)
		for dz in range(-footprint, footprint + 1):
			for dx in range(-footprint, footprint + 1):
				assert_false(_cliff_top(region, SITE_CELL.x + dx,
					SITE_CELL.y + dz),
					"seed %d stamped a cliff top at %s" % [world_seed,
						str(Vector2i(dx, dz))])


func test_a_walkable_approach_reaches_the_crown() -> void:
	## PathPlan refuses exposed cliff faces, so the stamp must leave at least one
	## cliff-free corridor from outside the hill onto the mesa. Asked of the
	## finished surface through TerrainSurfaceField.cardinal_strip_is_walkable,
	## the same authority the path router uses.
	var outer := int(ceil(SettlementReliefPlan.outer_radius_cells(
		SettlementReliefPlan.RELIEF_BUDGET_METRES))) + 1
	for world_seed: int in CORPUS:
		var relief := _flat_relief(world_seed)
		var plan := _flat_plan(world_seed, relief)
		var region := plan.compute_region(SITE_CELL.x, SITE_CELL.y, outer + 4)
		var centre := Vector2(float(SITE_CELL.x), float(SITE_CELL.y)) \
			* TerrainSurfaceField.TILE
		var reach := float(outer) * TerrainSurfaceField.TILE
		var walkable := 0
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP,
				Vector2.DOWN]:
			if TerrainSurfaceField.cardinal_strip_is_walkable(region,
					centre + direction * reach, centre, 3.0):
				walkable += 1
		assert_gt(walkable, 0,
			"seed %d stamped a hill with no walkable approach" % world_seed)


func test_the_fill_surface_is_stepped_and_not_conical() -> void:
	## The profile is piecewise CONSTANT over its terraces, one tier per storey
	## of budget, so the fill surface is exactly flat wherever the fill owns the
	## ground. A conical (smooth-bell) profile of the same budget would take a
	## different value in every cell; measured against real seeds it costs
	## roughly half the constant-band run the excavation's grade phase needs and
	## introduces cliff tops inside the town. This is the property that A/B
	## defends, checked without the flat-field quantizer hiding the difference.
	var budget := SettlementReliefPlan.RELIEF_BUDGET_METRES
	var steps := SettlementReliefPlan.terrace_steps(budget)
	var lowest_tier := budget - float(steps - 1) * HeightfieldPlan.STOREY_HEIGHT
	var tiers: Dictionary = {}
	for k in steps:
		tiers[snappedf(budget - float(k) * HeightfieldPlan.STOREY_HEIGHT,
			0.0001)] = true
	for world_seed: int in CORPUS:
		var relief := _flat_relief(world_seed)
		var on_tier: Dictionary = {}
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				var value := relief.profile_at_cell(SITE_CELL.x + dx,
					SITE_CELL.y + dz)
				if value <= lowest_tier + 1e-4:
					continue   # the foot, which ramps on purpose
				# Above the lowest tier the profile MUST be exactly a terrace.
				# A cone of the same budget lands strictly between tiers here,
				# which is precisely the shape the grade phase cannot use.
				assert_true(tiers.has(snappedf(value, 0.0001)),
					"seed %d profile %.3f m at %s is between terraces" % [
						world_seed, value, str(Vector2i(dx, dz))])
				on_tier[snappedf(value, 0.0001)] = true
		on_tier[snappedf(lowest_tier, 0.0001)] = true
		assert_eq(on_tier.size(), steps,
			"seed %d showed %d of %d terrace tiers" % [world_seed,
				on_tier.size(), steps])


func test_the_terraced_profile_renders_flat_benches() -> void:
	## The profile is a TERRACED bell on purpose: a flat crown, one flat ring per
	## storey of budget, then a smooth foot. A smooth bell would render as a
	## continuous ramp, and Wave 1 proved a continuously sloping town cannot
	## satisfy the excavation's at-grade street. So the stamped surface must show
	## a distinct crown storey with a distinct bench storey below it, and the
	## bench must be flat where the fill owns the ground.
	for world_seed: int in CORPUS:
		var relief := _flat_relief(world_seed)
		var plan := _flat_plan(world_seed, relief)
		var region := plan.compute_region(SITE_CELL.x, SITE_CELL.y, 6)
		var storeys: Dictionary = {}
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				var storey := region.storey_at(SITE_CELL.x + dx,
					SITE_CELL.y + dz)
				storeys[storey] = int(storeys.get(storey, 0)) + 1
		var crown := region.storey_at(SITE_CELL.x, SITE_CELL.y)
		var natural := int(round(FLAT_GROUND_M / HeightfieldPlan.STOREY_HEIGHT))
		assert_eq(crown - natural, SettlementReliefPlan.terrace_steps(
			SettlementReliefPlan.RELIEF_BUDGET_METRES),
			"seed %d crown is %d storeys over natural ground" % [world_seed,
				crown - natural])
		for tier in range(natural, crown + 1):
			assert_true(storeys.has(tier),
				"seed %d skipped terrace storey %d (%s)" % [world_seed, tier,
					str(storeys)])


# --------------------------------------------------------------------------
# Design §3.3: the stamp property, and Wave 1's portal grade bench
# --------------------------------------------------------------------------

func test_stamped_terrain_renders_every_terrace_step_the_massif_declares() -> void:
	## THE §3.3 STAMP PROPERTY, assertable for the first time now that the stamp
	## and the heightfield both exist. WarrenMassifBuilder scores only the LAYER
	## it authored and hands the ground step back to the terrain; this is the
	## other half of that bargain. Four readings, none of which the massif can
	## satisfy by itself:
	##
	##  (A) EVERY DECLARED STEP IS A RENDERED STEP. base_at is
	##      ceil((peak surface - datum) / 1.5), so a declared step between two
	##      columns must equal the difference of the terrain's own rendered peak
	##      surfaces at those columns to within the one band that rounding can
	##      move it. A massif that invented ground, or read it through a
	##      different datum, breaks this immediately.
	##  (B) NO DECLARED STEP IS INEXPRESSIBLE. The trickle-down clamp caps
	##      cardinal terrain neighbours at MAX_CLIFF_STEP storeys, so nothing the
	##      terrain renders can exceed that; a bigger declared step could only
	##      have come from somewhere the terrain cannot draw.
	##  (C) THE RELIEF WAS HANDED BACK, NOT CHARGED. The layer the builder
	##      authors over stamped terrain must be IDENTICAL, column for column, to
	##      the layer it authors on flat ground. This is the property that makes
	##      "the terrain owns the mound" true rather than aspirational.
	##  (D) EVERY DECLARED TERRACE IS A TERRACE THE TERRAIN HAS. Each distinct
	##      base band the massif declares must be a band the stamped surface
	##      actually reaches somewhere under the footprint.
	var band := WarrenVolumePlan.VERTICAL_BAND_SIZE_M
	var checked := 0
	var columns := 0
	var pairs := 0
	var terraces := 0
	var faults := ""
	for world_seed: int in CHAIN_CORPUS:
		var relief := _flat_relief(world_seed)
		var plan := _flat_plan(world_seed, relief)
		var region := plan.compute_region(SITE_CELL.x, SITE_CELL.y, 6)
		var sample := _ground_bands(region, SITE_CELL)
		var bands: Dictionary = sample.bands
		var peaks: Dictionary = sample.maxima
		var datum := float(sample.datum)
		var massif := WarrenMassifBuilder.build(world_seed, bands)
		if massif == null:
			continue
		var flat := WarrenMassifBuilder.build(world_seed, {})
		checked += 1
		var declared_bands: Dictionary = {}
		for column: Vector2i in massif.columns:
			columns += 1
			var declared := massif.base_at(column)
			declared_bands[declared] = true
			# (C)
			if flat != null and (not flat.has_column(column)
					or flat.layer_at(column) != massif.layer_at(column)):
				faults += " s%d %s layer %d vs flat %d;" % [world_seed,
					str(column), massif.layer_at(column),
					flat.layer_at(column) if flat.has_column(column) else -1]
			var here := float(peaks[column]) - datum
			for d: Vector2i in _CARDINALS:
				var nb := column + d
				if not massif.has_column(nb):
					continue
				pairs += 1
				var step := declared - massif.base_at(nb)
				# (B)
				var expressible := float(TerrainWorldTuning.MAX_CLIFF_STEP) \
					* HeightfieldPlan.STOREY_HEIGHT + band
				if float(absi(step)) * band > expressible:
					faults += " s%d %s inexpressible %d-band step;" % [
						world_seed, str(column), step]
				# (A)
				var there := float(peaks[nb]) - datum
				if absf(float(step) * band - (here - there)) >= band:
					faults += " s%d %s->%s declares %d bands, terrain %.2fm;" % [
						world_seed, str(column), str(nb), step, here - there]
		# (D)
		var rendered: Dictionary = {}
		for column: Vector2i in bands:
			rendered[int(bands[column])] = true
		for declared_band: int in declared_bands:
			terraces += 1
			if not rendered.has(declared_band):
				faults += " s%d declares terrace band %d the terrain never " \
					% [world_seed, declared_band] + "reaches;"
	assert_gt(checked, 0, "no seed reached a massif on stamped terrain")
	assert_eq(faults, "", "declared steps the stamped terrain does not render")
	gut.p(("stamp property: %d massifs, %d columns, %d neighbour pairs, "
		+ "%d declared terraces") % [checked, columns, pairs, terraces])


func _first_site(settlements: SettlementPlan) -> Vector2i:
	for sz in range(-1, 2):
		for sx in range(-1, 2):
			var site: Dictionary = settlements.site_for(Vector2i(sx, sz))
			if not site.is_empty():
				return site["cell"]
	return Vector2i(2147483647, 0)
