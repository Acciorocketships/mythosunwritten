extends GutTest

## MODE_MAZE end to end. Phase B built the one-pass plot planner; this file
## runs the real production entry point — `WarrenVolumetricSolver.solve()`
## with `GENERATION_MODE = MODE_MAZE` — over the four planner seeds and asks
## the questions Task C2 owns: does the town SEAL, and is everything the
## one-pass source could not supply an audit fact rather than a rejection?
##
## Task C1 asked only whether a town reached COMPOSITION. That assertion is
## kept (a town dying at the massif, the carve, the volume adapter, or the
## translator is a different and worse defect than one dying inside the
## composition) but it is no longer the bar: every planner seed must now come
## out the far side with a sealed `WarrenSpatialPlan`.

## The seeds the plot planner is pinned on, split by the scale profile each is
## measured at. Fixed pairs rather than `WarrenVillageScaleProfile.select()`
## so this file exercises both profiles regardless of how a seed rolls.
const COMPACT_SEEDS: Array[int] = [12, 4]
const STANDARD_SEEDS: Array[int] = [3, 9]

## Wall-clock ceiling for one production solve. The composition file has a
## ~4 min budget and the landmark stage used to run away for five minutes on
## its own; a seed that needs more than this has regressed into a search.
const MAXIMUM_SOLVE_MS := 30000

## Every failure `_solve_maze` can write once the source and its translation
## have both succeeded. A town that died at one of these got as far as the
## composition — which is what Task C1 delivered.
const COMPOSITION_STAGE_PREFIXES: Array[String] = [
	"maze composition rejected",
	"maze fabric gate failed",
	"maze finalization rejected",
]

## Every failure `_solve_maze` can write BEFORE the composition begins.
const SOURCE_STAGE_PREFIXES: Array[String] = [
	"maze source rejected",
	"maze massif",
	"maze carve",
	"maze volume adapter",
]

## `WarrenMazeBlockPartitioner`'s rejection of a plot-free source. It reaches
## the caller WRAPPED as "maze composition rejected: maze block partition: …"
## because the translator runs inside `from_volume`, so it must be matched by
## substring: it is a source defect wearing a composition failure's clothes,
## and a prefix test alone would score it as success.
const TRANSLATOR_NO_PLOTS := "sealed maze source carries no plots"

## The complete vocabulary of advisory shortfalls a maze town may report. A
## key outside this set means a NEW quota quietly became advisory without
## anyone deciding it should be, which is exactly the drift the audit exists
## to prevent. `hero_` prefixes and `_target` suffixes are the same facts
## under the emitting code's own names and are folded away before the check.
const ADVISORY_SHORTFALL_KEYS: Array[String] = [
	"covered_market", "courtyard_parcel_sides", "balconies", "landmarks",
	"skywalks", "assets", "courtyard_bridges", "bridges",
]

## Hero-quota gate texts. None of them may appear on a maze-mode failure: in
## one-pass mode a missing court, landmark, or link is an audit fact.
const HERO_QUOTA_GATE_FRAGMENTS: Array[String] = [
	"joint hero-feature beam found",
	"topology-first prefab landmarks survived",
	"topology-first skywalks fit",
]

## Seeds that compose a town and then lose it to a STRUCTURAL gate in
## `WarrenSpatialFabricCompiler` — a room the roof vocabulary cannot cover. It
## is a room/roof contract, not a feature quota, and it was masked until Task
## C2 opened the hero-feature gate that used to reject the town first.
##
## Pinned at the DEFECT level, not the gate level: every fragment listed must
## appear in the failure, so a different defect at the same gate cannot pass
## itself off as "the known blocker".
##
## The pin is two-sided on purpose. A seed that dies at a DIFFERENT gate fails
## here because the map went stale, and a seed that starts SEALING fails here
## because its entry is now a lie that must be deleted. 3/STANDARD IS EXACTLY
## THAT CASE and its entry is gone as of Task C3: its two roofless residual
## towers were the greedy scan building inside structural ROCK — solid the plot
## planner never gave to any building — and the maze-mode candidate filter that
## keeps rooms inside plot mass removed them. The seed seals end to end.
const KNOWN_FABRIC_BLOCKERS: Dictionary = {
	"9/standard": ["roof remainder for spatial.parcel.maze.house.044",
		"1-cell exposed sliver"],
}

## Measured share of the back-room mass the directed pre-pass really stamps as
## rooms, minus a 0.05 guard, taken from the WEAKEST of the three sealing towns
## (0.372, 0.227, 0.344 at the pass's first delivery). The denominator is the
## ALLOCATABLE fine mass the back-room records cover when the pass begins — the
## cells it could have taken — so a plot band a street was bored through never
## counts against it. Re-pin upward only: a drop is a regression to report,
## never to relax.
##
## What the remainder is, measured from `maze_back_room_refusals`: records
## whose parcel composed no building at all (its lineage was dropped), storeys
## whose mass the composed parcels themselves moved into, rectangles whose
## authored shell or roof will not fit beside the house in front of them, and
## rectangles standing more than the authored stone course above their own
## ground with no building underneath. All four are left to the greedy scan.
const BACK_ROOM_STAMPED_FLOOR := 0.17

## Measured share of a town's paved deck floor that is really WALKABLE from
## the town entry, minus a 0.05 guard. A plaza the player cannot reach is a
## hole in the fabric wearing paving, so this is the assertion that gives
## ruling 1 its teeth; the BFS behind it walks the sealed GRID rather than the
## route array, which `WarrenSpatialPlan._validate_route` has already proved
## connected. Re-pin upward only.
const DECK_REACHABLE_FLOOR := 0.95

## Measured share of the planner's bridge plots that become real bridge rooms,
## minus a 0.05 guard. It is **0.000 on this corpus**, so this line is a
## placeholder that becomes a real floor the day the model gap below closes;
## the teeth of `test_bridges_become_rooms_or_audited_releases` are the
## accounting identity, the reason vocabulary, and the shortfall equality.
##
## Why zero, measured: a bridge floor is `passage headroom top + 1`, and on all
## three bridges of the three sealing towns that band is exactly the flanking
## houses' ROOF course (`house.032[2,8)` and `house.030[2,8)` both stop their
## rooms at band 6, which is bridge.00's floor). A roof is not a room, so the
## two-sided socket bearing a bridge needs cannot be bound -- and
## `WarrenSpatialFabricCompiler` re-runs that same bond strictly, so a bridge
## stamped without it would reject the whole town instead of one span.
const BRIDGE_STAMPED_FLOOR := 0.0

## Every reason `_stamp_maze_bridges` may release a span for. A reason outside
## this set means the pass grew a new refusal nobody decided on, which is the
## same drift `ADVISORY_SHORTFALL_KEYS` exists to catch.
const BRIDGE_RELEASE_REASONS: Array[String] = [
	"span is not a one-storey tower or slim shell",
	"span mass is already spent or feature-reserved",
	"no flank house composed a building at this floor",
	"span footprint is not an authored shell",
	"span has no two bound flank bearings",
	"bearing flank has no room to name",
	"authored envelope does not fit",
]

static var _program_cache: SettlementFabricProgram
## One production solve per (seed, scale) shared by every test in the file.
## Four maze towns is the corpus; solving them once each is what keeps this
## file inside its budget while letting each test assert on the same run.
static var _solve_cache: Dictionary = {}


func _program() -> SettlementFabricProgram:
	## Compiling the measured vocabulary costs seconds; every solve in this
	## file reads the same immutable program.
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func after_each() -> void:
	## A leaked flag silently converts every later suite in the same process to
	## maze mode, so restore it even when an assertion failed.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _solve(world_seed: int, scale_id: StringName) -> Dictionary:
	## One real production solve. Reports the town (or null), the failure it
	## died with, and the wall clock — the three facts the baseline is made of.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	var started_ms := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(world_seed, {}, _program(),
		profile)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	return {
		"plan": plan,
		"ms": elapsed_ms,
		"seed": world_seed,
		"scale": scale_id,
		"failure": "" if plan != null else WarrenVolumetricSolver.last_failure,
	}


func _solved(world_seed: int, scale_id: StringName) -> Dictionary:
	var key := "%d/%s" % [world_seed, String(scale_id)]
	if not _solve_cache.has(key):
		_solve_cache[key] = _solve(world_seed, scale_id)
	return _solve_cache[key] as Dictionary


func _corpus() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for world_seed: int in COMPACT_SEEDS:
		out.append(_solved(world_seed, WarrenVillageScaleProfile.COMPACT))
	for world_seed: int in STANDARD_SEEDS:
		out.append(_solved(world_seed, WarrenVillageScaleProfile.STANDARD))
	return out


func _label(outcome: Dictionary) -> String:
	return "seed %d/%s" % [int(outcome.seed), String(outcome.scale)]


func _pre_composition_stage(failure: String) -> String:
	## The source-side stage this failure names, or "" when the town really did
	## reach composition.
	for prefix: String in SOURCE_STAGE_PREFIXES:
		if failure.begins_with(prefix):
			return prefix
	if failure.contains(TRANSLATOR_NO_PLOTS):
		return TRANSLATOR_NO_PLOTS
	return ""


func _names_a_composition_stage(failure: String) -> bool:
	for prefix: String in COMPOSITION_STAGE_PREFIXES:
		if failure.begins_with(prefix):
			return true
	return false


func _canonical_shortfall_key(key: String) -> String:
	## `hero_landmarks_target` and `landmarks` are the same fact wearing two
	## emitters' names; compare the fact.
	var out := key
	if out.begins_with("hero_"):
		out = out.substr(5)
	if out.ends_with("_target"):
		out = out.substr(0, out.length() - 7)
	return out


func _asset_plot_count(world_seed: int, scale_id: StringName) -> int:
	## Ask the source planner directly how many asset plots it placed. The
	## composition audit must account for every one of them.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var maze := WarrenMazeSitePlanner.plan(world_seed, {}, profile)
	if maze == null:
		return -1
	var count := 0
	for plot: Dictionary in maze.plots:
		count += int(StringName(plot["kind"]) \
			== WarrenMazeSourcePlan.PLOT_ASSET)
	return count


func _feature_count(plan: WarrenSpatialPlan, kind: StringName) -> int:
	var count := 0
	for feature: WarrenFeatureReservation in plan.features:
		count += int(feature.kind == kind)
	return count


func test_maze_mode_reaches_composition() -> void:
	## Task C1's assertion, kept: whatever else happens, no planner seed may
	## die at the source, the adapter, or the translator.
	for outcome: Dictionary in _corpus():
		var failure := String(outcome.failure)
		var stage := _pre_composition_stage(failure)
		assert_eq(stage, "",
			"%s died at the %s stage, before composition: %s" % [
				_label(outcome), stage, failure.left(160)])
		if outcome.plan != null:
			continue
		assert_true(_names_a_composition_stage(failure),
			("%s failed with a stage this file does not know; the gate map " \
				+ "is stale: %s") % [_label(outcome), failure.left(160)])


func test_maze_mode_seals_the_planner_seeds() -> void:
	## The Task C2 bar. Every planner seed composes a sealed town, and does it
	## in one bounded pass rather than a search — except the two pinned above,
	## which compose one and lose it to a room/roof contract downstream.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		var failure := String(outcome.failure)
		var shortfalls: Dictionary = {} if plan == null \
			else plan.audit.get("advisory_shortfalls", {}) as Dictionary
		print("MAZE_COMPOSITION %s sealed=%s ms=%d %s" % [
			_label(outcome), str(plan != null), int(outcome.ms),
			str(shortfalls) if plan != null else failure.left(200)])
		assert_lt(int(outcome.ms), MAXIMUM_SOLVE_MS,
			"%s must compose in one pass, not a search" % _label(outcome))
		var key := "%d/%s" % [int(outcome.seed), String(outcome.scale)]
		if not KNOWN_FABRIC_BLOCKERS.has(key):
			assert_not_null(plan, "%s must seal a town: %s" % [
				_label(outcome), failure.left(200)])
			continue
		assert_null(plan, ("%s now seals; delete its KNOWN_FABRIC_BLOCKERS " \
			+ "entry") % _label(outcome))
		if plan != null:
			continue
		for pinned: String in KNOWN_FABRIC_BLOCKERS[key] as Array:
			assert_true(failure.contains(pinned),
				"%s must still die at its pinned defect '%s', not: %s" % [
					_label(outcome), pinned, failure.left(200)])


func test_hero_shortfalls_are_audit_facts() -> void:
	## A court, a landmark, or a link the one-pass source did not supply is
	## recorded and shipped, never enforced. Two teeth: the audit key must be
	## present on every sealed town, and no seed may die naming a hero quota.
	for outcome: Dictionary in _corpus():
		var failure := String(outcome.failure)
		for fragment: String in HERO_QUOTA_GATE_FRAGMENTS:
			assert_false(failure.contains(fragment),
				"%s was rejected on a hero quota: %s" % [_label(outcome),
					failure.left(200)])
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		assert_true(plan.audit.has("advisory_shortfalls"),
			"%s must publish its advisory shortfalls" % _label(outcome))
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		for key_value: Variant in shortfalls.keys():
			assert_has(ADVISORY_SHORTFALL_KEYS,
				_canonical_shortfall_key(String(key_value)),
				"%s reports an unvocabularised shortfall %s" % [
					_label(outcome), key_value])
		assert_eq(int(plan.audit.get("advisory_shortfall_count", -1)),
			shortfalls.size(),
			"%s shortfall count must match its own record" % _label(outcome))
		# One pass means one authority on links. `WarrenSpatialFeatureSolver`
		# still owns a legacy scanner that rediscovers straight links after
		# room composition when nothing was preplanned; in maze mode it must
		# never run, so every committed link is one the plan asked for. That
		# count is zero until C4 translates `maze_bridges`, and the shortfall
		# above is what records the absence.
		var preplanned := int(plan.audit.get("preplanned_skywalk_count", -1))
		assert_eq(_feature_count(plan, &"enclosed_skywalk"), preplanned,
			("%s must commit only preplanned links; the legacy skywalk " \
				+ "search may not run in one-pass mode") % _label(outcome))
		if preplanned == 0:
			assert_eq(int(shortfalls.get("skywalks", -1)), 0,
				("%s commits no link, so the absence must be the recorded " \
					+ "shortfall") % _label(outcome))


func test_assets_become_landmarks_or_audited_shortfalls() -> void:
	## Every asset plot the planner placed is either a prefab landmark in the
	## sealed town or a counted, reasoned shortfall. Nothing may vanish.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var asset_plots := _asset_plot_count(int(outcome.seed),
			StringName(outcome.scale))
		var landmarks := _feature_count(plan, &"prefab_landmark")
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		var short := int(shortfalls.get("assets", 0))
		var outcomes := plan.audit.get("maze_asset_outcomes", []) as Array
		print("MAZE_ASSETS %s plots=%d landmarks=%d shortfalls=%d %s" % [
			_label(outcome), asset_plots, landmarks, short, outcomes])
		assert_eq(landmarks + short, asset_plots,
			"%s must account for every asset plot" % _label(outcome))
		assert_eq(outcomes.size(), asset_plots,
			"%s must report one outcome per asset plot" % _label(outcome))
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.has("id") and record.has("kind_id") \
				and record.has("reason"),
				"%s asset outcome %s is incomplete" % [_label(outcome),
					record])
			if not bool(record.get("placed", false)):
				assert_false(String(record.get("reason", "")).is_empty(),
					"%s unplaced asset %s must name a reason" % [
						_label(outcome), record.get("id", &"")])


func _plot_mass_cells(plan: WarrenSpatialPlan) -> Dictionary:
	## Every FINE cell inside some plot's own `[floor, top)`, read from the
	## sealed maze source the plan itself carries. In the plot model this is
	## the whole of the town's buildable mass: anything solid outside it is
	## structural ROCK, which is derived stone and never a room.
	var out: Dictionary = {}
	var source := plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(plot["floor"]), int(plot["top"])):
				for x_offset in 2:
					for z_offset in 2:
						out[Vector3i(column.x * 2 + x_offset, band,
							column.y * 2 + z_offset)] = true
	return out


func test_back_rooms_become_rooms() -> void:
	## The cells a house plot's door rectangle left over are that building's
	## back rooms, and the directed pre-pass is what turns them into real
	## WarrenRoomStamps. Before it existed they were plot mass nobody claimed
	## and `_discard_unassigned_mass` threw them away.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var total := int(plan.audit.get("maze_back_room_cell_count", -1))
		var stamped := int(plan.audit.get("maze_back_room_stamped_cell_count",
			-1))
		var unstamped := plan.audit.get("maze_back_room_unstamped_cells",
			{}) as Dictionary
		assert_gt(total, 0,
			"%s must publish the back-room mass it was handed" \
				% _label(outcome))
		if total <= 0:
			continue
		measured += 1
		var share := float(stamped) / float(total)
		print(("MAZE_BACK_ROOMS %s stamped=%d/%d share=%.3f rooms=%d " \
			+ "unstamped=%d") % [_label(outcome), stamped, total, share,
				int(plan.audit.get("maze_back_room_building_count", -1)),
				int(unstamped.get("count", -1))])
		assert_eq(stamped + int(unstamped.get("count", -1)), total,
			("%s must account for every back-room cell: stamped plus " \
				+ "unstamped is the whole") % _label(outcome))
		assert_eq((unstamped.get("cells", []) as Array).size(),
			int(unstamped.get("count", -1)),
			"%s must name the cells it could not stamp" % _label(outcome))
		assert_gte(share, BACK_ROOM_STAMPED_FLOOR,
			"%s stamps only %.3f of its back-room mass" % [_label(outcome),
				share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_residual_rooms_stay_inside_plots() -> void:
	## Ruling 1: in the plot model, mass that is not inside a plot is
	## structural ROCK, and the greedy residual scan may not build in it. Every
	## room the backfill admits — and every back room the pre-pass stamps —
	## must lie inside some plot's own band span, checked against the sealed
	## source rather than against the audit that claims it.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var plot_mass := _plot_mass_cells(plan)
		assert_gt(plot_mass.size(), 0,
			"%s must carry its own sealed maze source" % _label(outcome))
		var outside := 0
		var first := ""
		for building: WarrenBuildingVolume in plan.buildings:
			if not String(building.stable_id).begins_with("spatial.residual.") \
					and not String(building.stable_id).begins_with(
						"spatial.maze_back.") \
					and not String(building.stable_id).begins_with(
						"spatial.maze_bridge."):
				continue
			checked += 1
			for cell: Vector3i in building.private_cells:
				if plot_mass.has(cell):
					continue
				outside += 1
				if first.is_empty():
					first = "%s at %s" % [building.stable_id, cell]
		assert_eq(outside, 0,
			"%s builds %d residual cells in structural rock (%s)" % [
				_label(outcome), outside, first])
	assert_gt(checked, 0,
		"at least one sealed seed really has residual or back-room buildings")


func _source_plots(plan: WarrenSpatialPlan,
		kind: StringName) -> Array[Dictionary]:
	## The planner's own records of one plot kind, read from the sealed maze
	## source the plan itself carries. Free: no second site plan.
	var out: Array[Dictionary] = []
	var source := plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) == kind:
			out.append(plot)
	return out


func _deck_floor_cells(plan: WarrenSpatialPlan) -> Array[Vector3i]:
	## Every FINE cell a deck plot's own floor band covers. A deck has no
	## height (top == floor), so this one band is the whole of it.
	var out: Array[Vector3i] = []
	for plot: Dictionary in _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_DECK):
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for x_offset in 2:
				for z_offset in 2:
					out.append(Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset))
	return out


func _is_walkable(plan: WarrenSpatialPlan, cell: Vector3i) -> bool:
	## One walkable public cell: swept public air standing on a classified
	## public floor. Read from the GRID, which is the authority the paving and
	## the surface solver both consume.
	if not plan.grid.contains(cell) \
			or plan.grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
		return false
	var floor_claim := plan.grid.face_claim(cell, Vector3i.DOWN)
	return not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
		== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


func _walkable_from_entry(plan: WarrenSpatialPlan) -> Dictionary:
	## Flood the sealed grid from the town entry over walkable cells, stepping
	## 4-adjacent in x/z within one band.
	##
	## Honest about its own strength: `WarrenSpatialPlan._validate_route`
	## already proves the route ARRAY connected under the same adjacency, so a
	## deck cell that reached `route_floor_cells` is connected by construction
	## and this flood mostly restates that. It is kept because it walks the
	## GRID -- uses and face claims -- rather than the array, so it would still
	## catch a cell that seal accepted and the grid does not back. The
	## load-bearing assertions of the deck test are the other three: route
	## membership, `maze_deck_cell_count`, and `surface_plan.has_cell`.
	var seen: Dictionary = {plan.entry_floor_cell: true}
	var frontier: Array[Vector3i] = [plan.entry_floor_cell]
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			for rise: int in [-1, 0, 1]:
				var next := cell + direction + Vector3i.UP * rise
				if seen.has(next) or not _is_walkable(plan, next):
					continue
				seen[next] = true
				frontier.append(next)
	return seen


func test_decks_are_walkable_public_floor() -> void:
	## Ruling 1: a deck plot is a PLAZA, not a record. Its floor band is paved
	## as public floor with the same swept headroom a street gets, it joins the
	## town's route surfaces, and the town can WALK onto it. Before this pass
	## the planner's decks were audit facts composition discarded.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var cells := _deck_floor_cells(plan)
		assert_eq(int(plan.audit.get("maze_deck_cell_count", -1)),
			cells.size(),
			"%s must publish the deck mass it paved" % _label(outcome))
		if cells.is_empty():
			# A scale's deck quota is what the planner ASKS for; a town whose
			# streets grew no region of DECK_MIN columns legitimately has
			# none, and paving zero cells is the right answer there.
			continue
		measured += 1
		var route: Dictionary = {}
		for cell: Vector3i in plan.route_floor_cells:
			route[cell] = true
		var unpaved := 0
		var first := ""
		for cell: Vector3i in cells:
			if _is_walkable(plan, cell) and route.has(cell):
				continue
			unpaved += 1
			if first.is_empty():
				first = "%s" % cell
		assert_eq(unpaved, 0,
			"%s leaves %d of %d deck cells unpaved (first %s)" % [
				_label(outcome), unpaved, cells.size(), first])
		var walkable := _walkable_from_entry(plan)
		var reached := 0
		for cell: Vector3i in cells:
			reached += int(walkable.has(cell))
		var share := float(reached) / float(cells.size())
		# The paving itself, not the topology that permits it: the compiled
		# fabric's own surface union must carry every deck cell, or the plaza
		# renders as a hole the player can nonetheless walk into.
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		var unsurfaced := 0
		if fabric != null and fabric.surface_plan != null:
			for cell: Vector3i in cells:
				unsurfaced += int(not fabric.surface_plan.has_cell(cell))
		assert_eq(unsurfaced, 0,
			"%s leaves %d deck cells out of the public-realm surface" % [
				_label(outcome), unsurfaced])
		print("MAZE_DECKS %s paved=%d reachable=%d share=%.3f surfaced=%d" % [
			_label(outcome), cells.size(), reached, share,
			cells.size() - unsurfaced])
		assert_gte(share, DECK_REACHABLE_FLOOR,
			"%s paves %d deck cells but only %.3f of them are reachable" % [
				_label(outcome), cells.size(), share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_bridges_become_rooms_or_audited_releases() -> void:
	## Ruling 2: every bridge plot is either a real one-storey room bearing on
	## its two flanks, or a RELEASED record with a reason. Nothing vanishes and
	## nothing rejects the town.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var records := _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_BRIDGE)
		var stamped := int(plan.audit.get("maze_bridge_rooms", -1))
		var outcomes := plan.audit.get("maze_bridge_outcomes", []) as Array
		var released := 0
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.has("id") and record.has("outcome") \
				and record.has("reason"),
				"%s bridge outcome %s is incomplete" % [_label(outcome),
					record])
			if String(record.get("outcome", "")) == "stamped":
				continue
			released += 1
			assert_eq(String(record.get("outcome", "")), "released",
				"%s bridge outcome %s names no known verdict" % [
					_label(outcome), record])
			assert_has(BRIDGE_RELEASE_REASONS,
				String(record.get("reason", "")),
				"%s released bridge %s for an unvocabularised reason" % [
					_label(outcome), record.get("id", &"")])
		assert_eq(outcomes.size(), records.size(),
			"%s must report one outcome per bridge plot" % _label(outcome))
		assert_eq(stamped + released, records.size(),
			"%s must account for every bridge plot" % _label(outcome))
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		assert_eq(int(shortfalls.get("bridges", 0)), released,
			"%s must record its released bridges as a shortfall" % _label(
				outcome))
		var rooms := 0
		for building: WarrenBuildingVolume in plan.buildings:
			rooms += int(String(building.stable_id).begins_with(
				"spatial.maze_bridge."))
		assert_eq(rooms, stamped,
			"%s must build exactly the bridge rooms it claims" % _label(
				outcome))
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			if String(record.get("outcome", "")) != "stamped":
				continue
			# A stamped span must carry the two-flank contract the fabric
			# compiler bonds against. Live today and asserted the moment the
			# model gap closes, rather than written after the fact.
			var room := _bridge_room(plan, StringName(record["id"]),
				outcomes)
			assert_not_null(room,
				"%s stamped %s but built no bridge room" % [_label(outcome),
					record.get("id", &"")])
			if room == null:
				continue
			var flanks := room.audit.get("bridge_support_room_ids",
				[]) as Array
			assert_eq(flanks.size(), 2,
				"%s bridge room %s must name two flank rooms" % [
					_label(outcome), room.stable_id])
		if records.is_empty():
			continue
		measured += 1
		var share := float(stamped) / float(records.size())
		print("MAZE_BRIDGES %s stamped=%d/%d share=%.3f released=%d %s" % [
			_label(outcome), stamped, records.size(), share, released,
			outcomes])
		assert_gte(share, BRIDGE_STAMPED_FLOOR,
			"%s stamps only %.3f of its bridge plots" % [_label(outcome),
				share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func _bridge_room(plan: WarrenSpatialPlan, bridge_id: StringName,
		outcomes: Array) -> WarrenRoomStamp:
	## The room a stamped bridge record built. `_stamp_maze_bridges` numbers
	## its buildings by STAMP order, so the index is the record's position
	## among the stamped ones, not among all records.
	var index := 0
	for record_value: Variant in outcomes:
		var record := record_value as Dictionary
		if String(record.get("outcome", "")) != "stamped":
			continue
		if StringName(record["id"]) == bridge_id:
			break
		index += 1
	var wanted := StringName("spatial.maze_bridge.%02d" % index)
	for building: WarrenBuildingVolume in plan.buildings:
		if building.stable_id == wanted:
			return building.room_records[0]
	return null


func test_bridge_flanks_at_storey_level_are_reported() -> void:
	## IMPORTANT 3's corpus question, asked of the plans this file already
	## solved: is there a sealing town where a bridge's floor really lies
	## inside a flanking house PARCEL's composed storeys, rather than in the
	## roof course its rooms stop at? Every such case is printed with what the
	## pass then did with it, so "no bridge stamps" can never be mistaken for
	## "no bridge was ever offered a flank".
	var checked := PackedStringArray()
	var cases := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		checked.append(_label(outcome))
		var source := plan.source_volume.mass_context.get(
			&"maze_source_plan") as WarrenMazeSourcePlan
		var parcels := WarrenMazeBlockPartitioner.partition(source,
			plan.source_volume)
		assert_not_null(parcels,
			"%s must re-translate its own sealed source" % _label(outcome))
		if parcels == null:
			continue
		var outcomes := plan.audit.get("maze_bridge_outcomes", []) as Array
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			var plot := _plot_by_id(source, StringName(record["id"]))
			var flanks := _storey_level_flanks(parcels, plot)
			if flanks.is_empty():
				continue
			cases += 1
			print(("MAZE_BRIDGE_FLANK %s %s floor=%d flanks=%s -> %s (%s) " \
				+ "counts=%s") % [_label(outcome), record["id"],
					int(plot["floor"]), flanks, record["outcome"],
					record["reason"], record.get("span_counts", {})])
		# The diagnosis a released span published must survive to the audit;
		# `_backfill_residual_rooms` wipes the counter it is read from.
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.get("span_counts", null) is Dictionary,
				"%s bridge outcome %s must carry its span diagnosis" % [
					_label(outcome), record.get("id", &"")])
	print("MAZE_BRIDGE_FLANK checked=%s storey_level_cases=%d" % [
		", ".join(checked), cases])
	if cases == 0:
		print(("MAZE_BRIDGE_FLANK SKIPPED: no sealing seed of %s offers a " \
			+ "bridge whose floor lies inside a flank parcel's storeys") % [
				", ".join(checked)])


func _plot_by_id(source: WarrenMazeSourcePlan,
		plot_id: StringName) -> Dictionary:
	for plot: Dictionary in source.plots:
		if StringName(plot["id"]) == plot_id:
			return plot
	return {}


func _storey_level_flanks(parcels: WarrenParcelPlan,
		plot: Dictionary) -> Array[String]:
	## Every parcel 4-adjacent to this bridge whose own composed storeys
	## contain the bridge floor -- `[base_band, roof_base_band())`, which is
	## where its rooms are, not `[base_band, top_band)`, which includes the
	## roof course a bridge cannot bear on.
	var out: Array[String] = []
	if plot.is_empty():
		return out
	var columns: Dictionary = {}
	for cell_value: Variant in plot["cells"] as Array:
		columns[cell_value as Vector2i] = true
	var band := int(plot["floor"])
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var roof_base := parcel.base_band + parcel.storey_count() \
			* WarrenBuildingParcel.STOREY_BANDS
		if band < parcel.base_band or band >= roof_base:
			continue
		var beside := false
		for column: Vector2i in parcel.footprint:
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
					Vector2i.UP, Vector2i.DOWN]:
				beside = beside or columns.has(column + direction)
			if beside:
				break
		if beside:
			out.append("%s[%d,%d)%s" % [parcel.stable_id, parcel.base_band,
				roof_base, "" if (band - parcel.base_band) % 2 == 0 \
					else " offset"])
	return out


func test_bridge_shells_match_the_span_shape() -> void:
	## `_maze_bridge_kind` is the whole vocabulary decision of the bridge
	## pass, and no corpus town reaches it with anything but a tower, so it is
	## asserted directly.
	var one: Array[Vector2i] = [Vector2i(2, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(one), &"tower",
		"a one-cell span is a tower")
	var along_x: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(along_x), &"slim",
		"two cells in a line are a slim")
	var along_z: Array[Vector2i] = [Vector2i(2, -3), Vector2i(2, -2)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(along_z), &"slim",
		"the line may run either way")
	var backward: Array[Vector2i] = [Vector2i(3, -3), Vector2i(2, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(backward), &"slim",
		"and in either order")
	var diagonal: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -2)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(diagonal), &"",
		"a diagonal pair is not an authored shell")
	var apart: Array[Vector2i] = [Vector2i(2, -3), Vector2i(5, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(apart), &"",
		"two cells that do not touch are not one room")
	var three: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3),
		Vector2i(4, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(three), &"",
		"a three-cell span has no shell in this vocabulary")
	var none: Array[Vector2i] = []
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(none), &"",
		"an empty span is not a room")


func test_bridge_cells_are_one_authored_storey() -> void:
	## `_maze_bridge_cells` expands a span into fine mass, and that mass must
	## be exactly what the chosen shell stamps -- the two facts the pass then
	## relies on without re-checking.
	var one: Array[Vector2i] = [Vector2i(2, -3)]
	var tower := WarrenVolumetricSolver._maze_bridge_cells(one, 9, 11)
	assert_eq(tower.size(), 8, "a one-cell span is 2x2 fine over two bands")
	var wanted: Dictionary = {}
	for cell: Vector3i in tower:
		wanted[cell] = true
	assert_eq(wanted.size(), 8, "and carries no duplicate cell")
	for x in [4, 5]:
		for z in [-6, -5]:
			for y in [9, 10]:
				assert_true(wanted.has(Vector3i(x, y, z)),
					"macro (2, -3) at band 9 covers %s" % Vector3i(x, y, z))
	assert_true(_stamps_exactly(&"tower", tower),
		"a one-cell span is exactly a tower shell")
	var two: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3)]
	var slim := WarrenVolumetricSolver._maze_bridge_cells(two, 9, 11)
	assert_eq(slim.size(), 16, "a two-cell span is twice that")
	assert_true(_stamps_exactly(&"slim", slim),
		"a two-cell span is exactly a slim shell")
	assert_false(_stamps_exactly(&"tower", slim),
		"and is refused as a tower, at every yaw")


func _stamps_exactly(kind: StringName, cells: Array[Vector3i]) -> bool:
	## True when some yaw of `kind` stamps exactly `cells` -- the search the
	## bridge pass runs before it trusts an origin.
	for yaw in 4:
		if WarrenVolumetricSolver._maze_back_room_origin(kind, cells,
				yaw).x != 2147483647:
			return true
	return false


func test_a_bound_span_stamps_a_bridge_room() -> void:
	## The bridge stamping path end to end, on the geometry no corpus town
	## offers: a one-cell span between two flank rooms standing at the
	## bridge's OWN band. Every step is the production function -- the
	## two-flank socket proof, the authored envelope preflight, and the shared
	## private-room stamp -- so this is what distinguishes "the corpus has no
	## such bridge" from "the predicate never binds".
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(24, 16, 24))
	assert_true(grid.is_valid(), "the synthetic grid is usable")
	var band := 4
	assert_true(_fill_allocatable(grid), "synthetic massif projects")
	assert_true(_carve_synthetic_street(grid, band), "synthetic street carves")
	var west := _synthetic_flank(grid, &"flank.west", -1, band)
	var east := _synthetic_flank(grid, &"flank.east", 1, band)
	assert_not_null(west, "west flank composes")
	assert_not_null(east, "east flank composes")
	if west == null or east == null:
		return
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	var buildings: Array[WarrenBuildingVolume] = [west, east]
	for building: WarrenBuildingVolume in buildings:
		building_by_id[building.stable_id] = building
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
	var columns: Array[Vector2i] = [Vector2i(0, 0)]
	var kind := WarrenVolumetricSolver._maze_bridge_kind(columns)
	var cells := WarrenVolumetricSolver._maze_bridge_cells(columns, band,
		band + WarrenSpatialGrid.STOREY_CELLS)
	var span := WarrenVolumetricSolver._residual_bridge_span(cells,
		building_by_id, building_by_cell, 12345, _program())
	assert_false(span.is_empty(),
		"two flank rooms at the bridge band bind the span")
	if span.is_empty():
		return
	var flank_ids := span.room_ids as Array
	assert_eq(flank_ids.size(), 2, "a span bears on exactly two rooms")
	assert_ne(StringName(flank_ids[0]), StringName(flank_ids[1]),
		"and on two DISTINCT rooms, never one wall twice")
	var origin := WarrenVolumetricSolver._maze_back_room_origin(kind, cells,
		0)
	assert_ne(origin.x, 2147483647, "the span is an authored tower shell")
	var parent := building_by_id[StringName(span.parent_building_id)] \
		as WarrenBuildingVolume
	var parent_room := WarrenVolumetricSolver._maze_back_room_parent_room(
		parent, span.parent_contact_cell as Vector3i)
	assert_not_null(parent_room, "the bearing flank names a room")
	var roof := WarrenVolumetricSolver._residual_roof_feature(kind, origin,
		12345)
	var probe := WarrenRoomStamp.new(&"probe", &"probe", kind, origin, 0, 0,
		false, false, Vector3i(2147483647, 2147483647, 2147483647),
		Vector3i.ZERO, roof, parent_room.source_parcel_id,
		parent_room.source_storey_index)
	probe.private_cells.assign(cells)
	assert_true(WarrenVolumetricSolver._residual_room_envelope_fits(probe,
		building_by_id, _program(), 12345),
		"the bridge shell fits between its two flanks")
	var supports := WarrenSupportGraph.new()
	assert_true(supports.add_node(&"flank.west") \
		and supports.add_node(&"flank.east"), "flanks enter the support DAG")
	var required: Array[StringName] = []
	var terrain: Array[StringName] = []
	var edges: Array[Dictionary] = []
	var built := WarrenVolumetricSolver._stamp_maze_private_room(grid,
		supports, {"building_id": &"spatial.maze_bridge.00",
			"source_id": &"maze.bridge.00", "kind": kind, "origin": origin,
			"yaw": 0, "cells": cells, "floor_band": band,
			"terrain_bearing": false, "access_id": &"flank.west",
			"support_parcel_id": parent_room.source_parcel_id,
			"support_storey_index": parent_room.source_storey_index,
			"roof_feature": roof, "parent_building_id": parent.stable_id},
		buildings, building_by_id, building_by_cell, required, terrain, edges)
	assert_not_null(built, "the bridge room stamps: %s" \
		% WarrenVolumetricSolver.last_failure)
	if built == null:
		return
	for cell: Vector3i in cells:
		assert_eq(grid.use_at(cell), WarrenSpatialGrid.Use.PRIVATE_VOLUME,
			"%s became the bridge's own private volume" % cell)
		assert_eq(grid.owner_name_at(cell), &"spatial.maze_bridge.00",
			"%s is owned by the bridge" % cell)
	assert_eq(built.private_parent_ids, [&"flank.west"] as Array[StringName],
		"a bridge reaches the street through its flank house")
	assert_eq(edges, [{"child": &"spatial.maze_bridge.00",
		"parent": &"flank.west"}] as Array[Dictionary],
		"and carries one support edge to the bearing flank")
	assert_eq(terrain, [] as Array[StringName],
		"a bridge over a street never claims terrain bearing")
	assert_eq(required, [&"spatial.maze_bridge.00"] as Array[StringName],
		"and is a required support of the sealed town")
	assert_eq(buildings.size(), 3, "the caller's building list grew by one")
	var room := built.room_records[0]
	room.audit["bridge_support_room_ids"] = span.room_ids
	assert_eq((room.audit.get("bridge_support_room_ids", []) as Array).size(),
		2, "the compiler reads two flanks to bond, not a parent below")


func _fill_allocatable(grid: WarrenSpatialGrid) -> bool:
	var cells: Array[Vector3i] = []
	for x in range(-8, 16):
		for y in range(0, 16):
			for z in range(-8, 16):
				cells.append(Vector3i(x, y, z))
	var tx := grid.begin_transaction(&"massif.allocation")
	return tx.assign_use(cells, WarrenSpatialGrid.Use.ALLOCATABLE,
		&"massif.allocation") and tx.commit()


func _carve_synthetic_street(grid: WarrenSpatialGrid, band: int) -> bool:
	## The bore, in miniature: one lane of swept public air on a classified
	## public floor, which is what lets a flank building seal with a threshold.
	var air: Array[Vector3i] = []
	for x in range(-4, 6):
		for y in range(band, band + WarrenVolumePlan.HEADROOM_BANDS):
			air.append(Vector3i(x, y, -1))
	var carve := grid.begin_transaction(&"public.route")
	if not carve.require_use(air,
			[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.route") \
			or not carve.assign_use(air, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.route"):
		return false
	for x in range(-4, 6):
		if not carve.claim_face(Vector3i(x, band, -1), Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"):
			return false
	return carve.commit()


func _synthetic_flank(grid: WarrenSpatialGrid, id: StringName, macro_x: int,
		band: int) -> WarrenBuildingVolume:
	## One addressed tower storey on the macro column `macro_x`, standing at
	## the same band a bridge beside it would occupy.
	var cells: Array[Vector3i] = []
	for y in range(band, band + WarrenSpatialGrid.STOREY_CELLS):
		for x in range(macro_x * 2, macro_x * 2 + 2):
			for z in 2:
				cells.append(Vector3i(x, y, z))
	var tx := grid.begin_transaction(id)
	if not tx.assign_use(cells, WarrenSpatialGrid.Use.PRIVATE_VOLUME, id) \
			or not tx.commit():
		return null
	var origin := WarrenVolumetricSolver._maze_back_room_origin(&"tower",
		cells, 0)
	var room := WarrenRoomStamp.new(StringName("%s.room00" % id), id,
		&"tower", origin, 0, 0, true, false)
	var building := WarrenBuildingVolume.new(id, band)
	if not building.add_private_cells(cells) \
			or not room.add_private_cells(cells) \
			or not room.seal(grid, id) or not building.add_room(room) \
			or not building.add_threshold(Vector3i(macro_x * 2, band, 0),
				Vector3i(macro_x * 2, band, -1)) \
			or not building.seal(grid):
		return null
	return building





func test_maze_mode_is_deterministic() -> void:
	## Two solves of one seed must agree cell for cell: maze mode is a pure
	## function of (seed, ground bands, scale profile).
	var first := _solved(12, WarrenVillageScaleProfile.COMPACT)
	var first_plan := first.plan as WarrenSpatialPlan
	assert_not_null(first_plan, String(first.failure).left(200))
	if first_plan == null:
		return
	var repeated := _solve(12, WarrenVillageScaleProfile.COMPACT)
	var repeated_plan := repeated.plan as WarrenSpatialPlan
	assert_not_null(repeated_plan, String(repeated.failure).left(200))
	if repeated_plan == null:
		return
	assert_eq(first_plan.deterministic_signature(),
		repeated_plan.deterministic_signature(),
		"maze mode is a pure function of (seed, ground bands, scale profile)")
