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
## the teeth of `test_bridges_become_rooms_decks_or_audited_releases` are the
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

## Every verdict a bridge record may carry. `open_deck` joins the vocabulary
## in Task C5: a span whose two flanks both present a FLAT surface at its own
## floor band is a rooftop walkway rather than a room, so it is paved as
## public floor instead of released back to rock.
const BRIDGE_OUTCOMES: Array[String] = ["stamped", "open_deck", "released"]

## Measured share of the route floor a maze town lays that really stands on
## something solid -- retained stone, a compiled building, or an inhabited
## room -- minus a 0.05 guard. Before Task C5 every leftover rock cell was
## discarded, so a bored street's own floor stood on nothing at all. Re-pin
## upward only.
const ROUTE_ON_STONE_FLOOR := 0.95


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


func test_bridges_become_rooms_decks_or_audited_releases() -> void:
	## Ruling 2 (C4) extended by ruling 5 (C5): every bridge plot is either a
	## real one-storey room bearing on its two flanks, an OPEN DECK paved
	## between two flat flank surfaces, or a RELEASED record with a reason.
	## Nothing vanishes and nothing rejects the town.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var records := _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_BRIDGE)
		var stamped := int(plan.audit.get("maze_bridge_rooms", -1))
		var paved := int(plan.audit.get("maze_bridge_open_decks", -1))
		var outcomes := plan.audit.get("maze_bridge_outcomes", []) as Array
		var released := 0
		var open_decks := 0
		var route: Dictionary = {}
		for cell: Vector3i in plan.route_floor_cells:
			route[cell] = true
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.has("id") and record.has("outcome") \
				and record.has("reason"),
				"%s bridge outcome %s is incomplete" % [_label(outcome),
					record])
			var verdict := String(record.get("outcome", ""))
			assert_has(BRIDGE_OUTCOMES, verdict,
				"%s bridge outcome %s names no known verdict" % [
					_label(outcome), record])
			assert_true(record.has("flat_flank_columns") \
				and record.has("flat_flank_sides"),
				("%s bridge outcome %s must publish why it is or is not an " \
					+ "open deck") % [_label(outcome), record.get("id", &"")])
			if verdict == "stamped":
				continue
			if verdict == "open_deck":
				open_decks += 1
				# An open deck is PAVING, so the fact to check is the paving:
				# the span's own floor band is walkable public floor that
				# joined the town's route surfaces.
				var unpaved := 0
				for cell: Vector3i in _bridge_floor_cells(plan,
						StringName(record["id"])):
					unpaved += int(not _is_walkable(plan, cell) \
						or not route.has(cell))
				assert_eq(unpaved, 0,
					"%s open bridge deck %s leaves %d floor cells unpaved" % [
						_label(outcome), record.get("id", &""), unpaved])
				continue
			released += 1
			assert_has(BRIDGE_RELEASE_REASONS,
				String(record.get("reason", "")),
				"%s released bridge %s for an unvocabularised reason" % [
					_label(outcome), record.get("id", &"")])
		assert_eq(outcomes.size(), records.size(),
			"%s must report one outcome per bridge plot" % _label(outcome))
		assert_eq(paved, open_decks,
			"%s must publish the open bridge decks it paved" % _label(outcome))
		assert_eq(stamped + open_decks + released, records.size(),
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


func _bridge_floor_cells(plan: WarrenSpatialPlan,
		bridge_id: StringName) -> Array[Vector3i]:
	## Every FINE cell of one bridge plot's own floor band, read from the
	## sealed source rather than from the pass that paved it.
	var out: Array[Vector3i] = []
	for plot: Dictionary in _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_BRIDGE):
		if StringName(plot["id"]) != bridge_id:
			continue
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for x_offset in 2:
				for z_offset in 2:
					out.append(Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset))
	return out


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
	## The bridge pass end to end, on the geometry no corpus town offers: a
	## one-cell span between two flank rooms standing at the bridge's OWN
	## band. `_stamp_maze_bridges` itself is driven, from a one-record
	## `maze_bridges` fixture, so the outcome record, the span-count snapshot
	## and the three audit keys the fabric compiler bonds against are all
	## PRODUCED by production code rather than restated by this test.
	##
	## This is what distinguishes "the corpus offers no such bridge" from
	## "the predicate never binds".
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
	var columns: Array[Vector2i] = [Vector2i(0, 0)]
	var volume := WarrenVolumePlan.new(&"synthetic.bridge", 12345, null)
	var parcels := WarrenParcelPlan.new(&"synthetic.bridge.parcels", volume)
	# Exactly the record `WarrenMazeBlockPartitioner._bridge_record` emits,
	# and exactly the group map `partition` publishes beside it.
	parcels.audit["maze_bridges"] = [{
		"id": &"bridge.00", "cells": columns, "floor": band,
		"top": band + WarrenSpatialGrid.STOREY_CELLS,
		"door_walk": Vector3i(0, band - 1, 0),
		"building_id": &"house.west"}]
	parcels.audit["maze_buildings"] = {&"house.west": [&"flank.west"]}
	var supports := WarrenSupportGraph.new()
	assert_true(supports.add_node(&"flank.west") \
		and supports.add_node(&"flank.east"), "flanks enter the support DAG")
	var buildings: Array[WarrenBuildingVolume] = [west, east]
	var required: Array[StringName] = []
	var terrain: Array[StringName] = []
	var edges: Array[Dictionary] = []
	var result := WarrenVolumetricSolver._stamp_maze_bridges(grid, volume,
		parcels, buildings, supports, required, terrain, edges, {},
		_program())
	assert_false(bool(result.get("failed", false)),
		"the bridge pass completed: %s" % WarrenVolumetricSolver.last_failure)
	var outcomes := result.get("outcomes", []) as Array
	assert_eq(outcomes.size(), 1, "one record, one outcome")
	if outcomes.size() != 1:
		return
	var outcome := outcomes[0] as Dictionary
	assert_eq(String(outcome.get("outcome", "")), "stamped",
		"the span stamps: %s" % outcome.get("reason", ""))
	assert_eq(String(outcome.get("reason", "x")), "",
		"a stamped record names no refusal")
	assert_eq(int(result.get("record_count", -1)), 1, "one bridge record")
	assert_eq(int(result.get("stamped", -1)), 1, "stamped once")
	assert_eq(int(result.get("released", -1)), 0, "released nothing")
	# MINOR 5's snapshot, taken from the production counter before the
	# residual backfill wipes it: both flanks really were probed.
	var counts := outcome.get("span_counts", {}) as Dictionary
	assert_eq(int(counts.get("flank_contacts", -1)), 2,
		"the bearing proof saw both flanking walls")
	assert_eq(int(counts.get("flank_rooms_probed", -1)), 2,
		"and probed a room on each of them")
	assert_eq(buildings.size(), 3, "the caller's building list grew by one")
	if buildings.size() != 3:
		return
	var built := buildings[2]
	assert_eq(built.stable_id, StringName("spatial.maze_bridge.00"),
		"bridge buildings are numbered by stamp order")
	var cells := WarrenVolumetricSolver._maze_bridge_cells(columns, band,
		band + WarrenSpatialGrid.STOREY_CELLS)
	for cell: Vector3i in cells:
		assert_eq(grid.use_at(cell), WarrenSpatialGrid.Use.PRIVATE_VOLUME,
			"%s became the bridge's own private volume" % cell)
		assert_eq(grid.owner_name_at(cell), StringName(
			"spatial.maze_bridge.00"), "%s is owned by the bridge" % cell)
	assert_eq(built.private_parent_ids, [&"flank.west"] as Array[StringName],
		"a bridge reaches the street through the flank house it belongs to")
	assert_eq(edges, [{"child": StringName("spatial.maze_bridge.00"),
		"parent": &"flank.west"}] as Array[Dictionary],
		"and carries one support edge to the bearing flank")
	assert_eq(terrain, [] as Array[StringName],
		"a bridge over a street never claims terrain bearing")
	assert_eq(required, [StringName("spatial.maze_bridge.00")] \
		as Array[StringName],
		"and is a required support of the sealed town")
	var room := built.room_records[0]
	assert_eq(room.kind, &"tower", "a one-cell span is a tower room")
	assert_false(room.terrain_bearing, "which does not stand on the ground")
	# The three keys the production pass stamps after seal(): without them
	# `WarrenSpatialFabricCompiler` looks for a bearing parent underneath a
	# room that has none, and `_modular_box_use_audit` classifies the tower as
	# an unsupported voxel instead of an occupied skywalk.
	var flanks := room.audit.get("bridge_support_room_ids", []) as Array
	assert_eq(flanks.size(), 2,
		"the compiler reads two flanks to bond, not a parent below")
	assert_true(flanks.has(StringName("flank.west.room00")),
		"and both are the real flank rooms: %s" % [flanks])
	assert_true(flanks.has(StringName("flank.east.room00")),
		"and both are the real flank rooms: %s" % [flanks])
	assert_true(room.audit.has("bridge_support_records"),
		"the span's own bond records travel with the room")
	assert_false(bool(room.audit.get("bridge_is_bracketed_jetty", true)),
		"a two-sided span is not a bracketed jetty")


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


func _maze_source(plan: WarrenSpatialPlan) -> WarrenMazeSourcePlan:
	return plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan


func _flat_roof_by_parcel(plan: WarrenSpatialPlan) -> Dictionary:
	## Parcel id -> whether the plot planner declared that house's roof a
	## SLAB. Something stands on its top band -- an upper street (`tiered`) or
	## another plot occupying its own columns there (`not roofed`) -- so it
	## owes the storey grid one storey and one band of slab instead of the
	## authored pitched reservation. Read from the sealed source's own facts,
	## not from the parcel the translator built out of them.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		var facts := source.plot_facts(plot)
		out[StringName("parcel.maze.%s" % String(plot["id"]))] = \
			bool(facts.get("tiered", false)) \
			or not bool(facts.get("roofed", true))
	return out


func test_tiered_parcels_get_flat_roofs() -> void:
	## Ruling 1: a plot something STANDS ON has a flat roof, and the spatial
	## roof compiler is what has to know it. Two teeth, neither of which reads
	## the other's answer: every room stamp of such a parcel must carry the
	## flag (the plot fact really reaches the stamp through the proposal), and
	## every one of those stamps that owns an exposed roof plate must receive
	## a FLAT roof unit instead of the pitched shell the heuristics would pick.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var flat_by_parcel := _flat_roof_by_parcel(plan)
		assert_gt(flat_by_parcel.size(), 0,
			"%s must carry its own sealed maze source" % _label(outcome))
		var mismatched := 0
		var first := ""
		var flat_stamps := 0
		for building: WarrenBuildingVolume in plan.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if not flat_by_parcel.has(room.source_parcel_id):
					continue
				var wanted := bool(flat_by_parcel[room.source_parcel_id])
				flat_stamps += int(room.flat_roof)
				if room.flat_roof == wanted:
					continue
				mismatched += 1
				if first.is_empty():
					first = "%s wants flat_roof=%s" % [room.stable_id,
						str(wanted)]
		assert_eq(mismatched, 0,
			("%s stamps %d rooms whose flat_roof disagrees with the plot " \
				+ "(%s)") % [_label(outcome), mismatched, first])
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var roofed := int(fabric.audit.get("plot_flat_roof_room_count", -1))
		var flats := int(fabric.audit.get("plot_flat_roof_count", -1))
		var pitched := int(fabric.audit.get("plot_flat_roof_pitched_count",
			-1))
		print(("MAZE_FLAT_ROOFS %s stamps=%d roofed=%d flat_units=%d " \
			+ "pitched=%d partial=%d rejected=%d") % [_label(outcome),
			flat_stamps, roofed, flats, pitched,
			int(fabric.audit.get("plot_flat_roof_partial_plate_count", -1)),
			int(fabric.audit.get("plot_flat_roof_rejected_count", -1))])
		# Every flat-roofed stamp that owns a COMPLETE exposed plate receives
		# the authored slab. A stamp whose plate is partial -- another room
		# stands on part of its crown -- has no whole-footprint flat module to
		# receive, so it keeps the finite setback vocabulary and is counted
		# separately rather than folded into either number.
		var partial := int(fabric.audit.get(
			"plot_flat_roof_partial_plate_count", -1))
		assert_gte(flats + partial, roofed,
			("%s owes %d flat roof units to its flat-roofed stamps and " \
				+ "compiled %d (%d partial plates)") % [_label(outcome),
				roofed, flats, partial])
		assert_eq(pitched, 0,
			("%s gave %d flat-roofed stamps a pitched roof over a complete " \
				+ "plate") % [_label(outcome), pitched])
		assert_gt(flats, 0,
			"%s compiled no flat roof at all" % _label(outcome))
		measured += int(flat_stamps > 0)
	assert_gt(measured, 0,
		"at least one sealing seed really has a flat-roofed parcel")


func _rock_cells(plan: WarrenSpatialPlan) -> Dictionary:
	## Every FINE cell of the source plan's ROCK: derived solid at or above the
	## massif's own bearing datum that lies inside no plot's `[floor, top)`.
	## Terrain below `base_at` belongs to the heightfield, not to the town, and
	## is deliberately excluded.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null or source.massif == null:
		return out
	var plot_mass := _plot_mass_cells(plan)
	for column_value: Variant in source.massif.columns.keys():
		var column := column_value as Vector2i
		for band in range(source.massif.base_at(column),
				source.massif.top_at(column) + 1):
			if not source.solid_at(Vector3i(column.x, band, column.y)):
				continue
			for x_offset in 2:
				for z_offset in 2:
					var fine := Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset)
					if plot_mass.has(fine):
						continue
					out[fine] = true
	return out


func test_rock_is_retained_as_stone() -> void:
	## Ruling 3: rock is STONE, not nothing. Every fine cell of the source
	## plan's leftover mass -- shoulders, tunnel roofs, street-floor slabs,
	## plinths, the interior nobody built in -- that no room, feature or public
	## realm took must reach the fabric's retained-terrace channel instead of
	## `_discard_unassigned_mass`. The second assertion is the one a player
	## feels: a street's walk surface must stand on something.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var solids := fabric.transformed_cells(&"solid")
		var retained := fabric.retained_terrace_cells
		var expected := 0
		var missing := 0
		var first := ""
		for cell_value: Variant in _rock_cells(plan).keys():
			var cell := cell_value as Vector3i
			var use := plan.grid.use_at(cell)
			if use in [WarrenSpatialGrid.Use.PUBLIC_AIR,
					WarrenSpatialGrid.Use.PRIVATE_VOLUME,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR] \
					or solids.has(cell):
				continue
			expected += 1
			if retained.has(cell):
				continue
			missing += 1
			if first.is_empty():
				first = "%s" % cell
		var audited := int(fabric.audit.get("maze_retained_rock_cells", -1))
		var skipped := int(plan.audit.get(
			"maze_retained_rock_skipped_reserved", -1))
		var suppressed := int(fabric.audit.get(
			"maze_plinth_faces_suppressed_by_stone", -1))
		print(("MAZE_ROCK %s rock=%d retained=%d audited=%d missing=%d " \
			+ "skipped_reserved=%d plinth_faces_suppressed=%d") % [
			_label(outcome), expected, retained.size(), audited, missing,
			skipped, suppressed])
		assert_gte(skipped, 0,
			"%s must publish the rock cells another feature had reserved" \
				% _label(outcome))
		assert_gte(suppressed, 0,
			"%s must publish the plinth faces retained stone suppressed" \
				% _label(outcome))
		assert_eq(missing, 0,
			"%s discards %d of %d rock cells (first %s)" % [_label(outcome),
				missing, expected, first])
		assert_gt(audited, 0,
			"%s must publish the retained rock it kept" % _label(outcome))
		var standing := 0
		var floating := 0
		var first_hole := ""
		var holes: Dictionary = {}
		var source := _maze_source(plan)
		for cell: Vector3i in plan.route_floor_cells:
			var below := cell + Vector3i.DOWN
			# Terrain is the heightfield's, and the heightfield draws it: a
			# street cut at its own column's ground datum stands on the
			# mountain, not on anything this fabric owes a module for.
			var column := Vector2i(floori(float(cell.x) / 2.0),
				floori(float(cell.z) / 2.0))
			var on_terrain := source != null and source.massif != null \
				and source.massif.has_column(column) \
				and below.y < source.massif.base_at(column)
			# A route floor whose lower neighbour is the street itself is a
			# STEP: the passage climbs a band and the cell below belongs to
			# the run it climbed from. Nothing is owed a module there. What
			# this assertion is really about is OUTSIDE -- a walk surface with
			# literally nothing under it, which is what every leftover rock
			# cell was before Task C5 retained it.
			if on_terrain or retained.has(below) or solids.has(below) \
					or plan.grid.use_at(below) in [
						WarrenSpatialGrid.Use.PRIVATE_VOLUME,
						WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
						WarrenSpatialGrid.Use.PUBLIC_AIR]:
				standing += 1
				continue
			floating += 1
			holes[plan.grid.use_at(below)] = int(
				holes.get(plan.grid.use_at(below), 0)) + 1
			if first_hole.is_empty():
				first_hole = "%s under %s owner=%s" % [cell, below,
					plan.grid.owner_name_at(below)]
		var share := float(standing) \
			/ float(maxi(1, plan.route_floor_cells.size()))
		print(("MAZE_ROUTE_STONE %s standing=%d/%d share=%.3f holes=%s " \
			+ "first=%s") % [_label(outcome), standing,
			plan.route_floor_cells.size(), share, str(holes), first_hole])
		assert_gte(share, ROUTE_ON_STONE_FLOOR,
			("%s lays %d route floor cells and only %.3f of them stand on " \
				+ "anything") % [_label(outcome),
				plan.route_floor_cells.size(), share])
		measured += 1
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func _rooms_by_parcel(plan: WarrenSpatialPlan) -> Dictionary:
	var out: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var rooms: Array = out.get(room.source_parcel_id, [])
			rooms.append(room)
			out[room.source_parcel_id] = rooms
	return out


func test_stone_bases_follow_bears_on_rock() -> void:
	## Ruling 4: the stone base is a PLOT fact, not a composition accident. A
	## house whose columns really stand on rock or terrain roots in the ground
	## and wears the plinth course; a house standing on another house names
	## that house instead, and gets no stone at all.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var source := _maze_source(plan)
		assert_not_null(source,
			"%s must carry its own sealed maze source" % _label(outcome))
		if source == null:
			continue
		var rooms_by_parcel := _rooms_by_parcel(plan)
		var wrong := 0
		var first := ""
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
				continue
			var parcel_id := StringName("parcel.maze.%s" % String(plot["id"]))
			var rooms := rooms_by_parcel.get(parcel_id, []) as Array
			if rooms.is_empty():
				continue
			checked += 1
			var bears := bool(source.plot_facts(plot).get("bears_on_rock",
				false))
			var ground: WarrenRoomStamp = null
			var stacked := false
			for room_value: Variant in rooms:
				var room := room_value as WarrenRoomStamp
				stacked = stacked or not room.terrain_bearing \
					and room.support_parent_parcel_id != parcel_id
				if ground == null or room.source_storey_index \
						< ground.source_storey_index:
					ground = room
			if bears and not ground.terrain_bearing:
				wrong += 1
				if first.is_empty():
					first = "%s bears on rock but roots in %s" % [parcel_id,
						ground.support_parent_parcel_id]
			if not bears and stacked and ground.terrain_bearing:
				wrong += 1
				if first.is_empty():
					first = "%s stands on a house and still claims terrain" \
						% parcel_id
		assert_eq(wrong, 0,
			"%s gives %d parcels the wrong base (%s)" % [_label(outcome),
				wrong, first])
		# The composition's own reading of the same fact: a house the plot
		# model says stands on ANOTHER PLOT may not root in the mountain at
		# its own floor band. Published by `_partition_rooms` rather than
		# re-derived here, so a future planner change that reintroduces the
		# defect fails at the source of it.
		var unrooted := int(plan.audit.get(
			"maze_unrooted_terrain_bearing_count", -1))
		print("MAZE_BASES %s parcels=%d unrooted_terrain_bearing=%d" % [
			_label(outcome), checked, unrooted])
		assert_eq(unrooted, 0,
			"%s roots %d houses in terrain the plot says they never touch: %s" \
				% [_label(outcome), unrooted, str(plan.audit.get(
					"maze_unrooted_terrain_bearing_details", []))])
	assert_gt(checked, 0, "at least one sealing seed really composes a house")


func test_stacked_houses_bond_to_flat_roofs() -> void:
	## Ruling 2: a flat-roofed parcel FILLS its plot -- its rooms, its flat
	## roof unit and its retained slab course occupy `[base_band, top_band)` --
	## so a house at that parcel's `top_band` really does stand on something
	## and may declare the seam. Before Task C5 the slab was derived mass no
	## building owned, and every one of these stacks fell back to claiming
	## terrain bearing straight through the house underneath it.
	var declared_total := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var stacked := int(plan.audit.get("maze_stacked_plot_count", -1))
		var declared := int(plan.audit.get("maze_declared_stack_count", -1))
		var gaps := int(plan.audit.get("maze_stack_slab_gap_count", -1))
		print("MAZE_STACKS %s stacked_plots=%d declared=%d slab_gaps=%d" % [
			_label(outcome), stacked, declared, gaps])
		assert_gte(stacked, 0,
			"%s must publish how many plots its planner stacked" % _label(
				outcome))
		assert_eq(gaps, 0,
			("%s refuses %d stacked houses for a slab gap the flat roof now " \
				+ "fills") % [_label(outcome), gaps])
		# Independent of the count: EVERY declared child that composed a
		# building must have a ground room that names the parent parcel and
		# does not claim terrain bearing. A child whose lineage the
		# composition dropped altogether builds nothing at all, which is a
		# different (and older) defect -- counted, not asserted away.
		var rooms_by_parcel := _rooms_by_parcel(plan)
		var seams := 0
		var uncomposed := 0
		var wrong := ""
		for child_value: Variant in (plan.audit.get("maze_stack_parents",
				{}) as Dictionary).keys():
			var child_id := StringName(child_value)
			var parent_id := StringName((plan.audit["maze_stack_parents"] \
				as Dictionary)[child_id])
			var ground: WarrenRoomStamp = null
			for room_value: Variant in rooms_by_parcel.get(child_id,
					[]) as Array:
				var room := room_value as WarrenRoomStamp
				if ground == null or room.source_storey_index \
						< ground.source_storey_index:
					ground = room
			if ground == null:
				uncomposed += 1
				continue
			if ground.terrain_bearing \
					or ground.support_parent_parcel_id != parent_id:
				if wrong.is_empty():
					wrong = "%s roots in %s instead of %s" % [child_id,
						"terrain" if ground.terrain_bearing \
							else ground.support_parent_parcel_id, parent_id]
				continue
			seams += 1
		print(("MAZE_STACK_SEAMS %s declared=%d bonded=%d uncomposed=%d " \
			+ "audited_uncomposed=%d") % [_label(outcome), declared, seams,
			uncomposed, int(plan.audit.get("maze_uncomposed_stack_count",
				-1))])
		assert_eq(int(plan.audit.get("maze_uncomposed_stack_count", -1)),
			uncomposed,
			"%s must publish the declared stacks that composed nothing" \
				% _label(outcome))
		assert_eq(wrong, "",
			"%s declared a stack the composition did not build: %s" % [
				_label(outcome), wrong])
		assert_lte(seams + uncomposed, maxi(0, declared),
			"%s builds more stacked ground rooms than it declared" % _label(
				outcome))
		declared_total += seams
	assert_gt(declared_total, 0,
		"no planner seed builds a stacked house bonded to a flat roof")


func test_retained_rock_skips_a_cell_another_feature_reserved() -> void:
	## Review IMPORTANT 1. `Reservation.FEATURE` is NON-SHAREABLE, and retained
	## stone is the one claim in this pipeline that sweeps a whole volume
	## instead of placing an authored shape -- so it is the one that can meet a
	## cell some other feature reserved without ever assigning it a use (the
	## elevated court does exactly that, and `_discard_unassigned_mass` then
	## turns those cells OUTSIDE, straight into this pass's candidate set).
	## Reserving one of them fails the whole grid transaction and kills the
	## town. The pass must SKIP it and count it.
	##
	## Unit-style on purpose: one real maze source, two identical grids, one
	## pre-reserved cell between them. No solve, no fabric, ~1 s.
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var source := WarrenMazeSitePlanner.plan(12, {}, profile)
	assert_not_null(source, "the pinned planner seed must still plan a town")
	if source == null:
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	assert_not_null(volume, "the maze source must adapt to a volume")
	if volume == null:
		return
	var baseline := _rock_retention_probe(source, volume, Vector3i(2147483647,
		2147483647, 2147483647))
	assert_gt(int(baseline.result.cells), 0,
		"the probe must retain real rock before the reservation is added")
	assert_eq(int(baseline.result.skipped), 0,
		"an unreserved grid skips nothing")
	assert_gt((baseline.cells as Array).size(), 0,
		"the probe must expose the cells it retained")
	# Take a cell the baseline really retained and give its FEATURE bit to
	# somebody else, exactly as a composed feature would.
	var taken := (baseline.cells as Array[Vector3i])[
		(baseline.cells as Array).size() / 2]
	var guarded := _rock_retention_probe(source, volume, taken)
	assert_false(bool(guarded.result.failed),
		"a foreign FEATURE reservation must never reject the retention pass")
	assert_eq(int(guarded.result.skipped), 1,
		"the pass must count the one cell it could not claim")
	assert_eq(int(guarded.result.cells), int(baseline.result.cells) - 1,
		"the pass must retain everything else")
	# And the sealed reservation must still be buildable over what is left.
	var supports := WarrenSupportGraph.new()
	var stone := WarrenVolumetricSolver._maze_stone_reservation(
		guarded.grid as WarrenSpatialGrid, supports)
	assert_false(bool(stone.failed),
		"retained stone must still seal around the reserved cell")
	var feature := stone.feature as WarrenFeatureReservation
	assert_not_null(feature, "retained stone must produce a sealed feature")
	if feature == null:
		return
	assert_eq(feature.reserved_cells.size(), int(guarded.result.cells),
		"the sealed feature must own exactly the cells the pass claimed")
	assert_false(feature.reserved_cells.has(taken),
		"the sealed feature must not own the cell it skipped")


func _rock_retention_probe(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, reserved: Vector3i) -> Dictionary:
	## One fresh grid carrying the source's projected mass, discarded down to
	## OUTSIDE exactly as `from_volume` leaves it before `_retain_maze_rock`
	## runs, optionally with one cell's FEATURE bit already owned by somebody
	## else. Returns `{grid, result, cells}`.
	var bounds := WarrenVolumetricSolver._grid_bounds(source.massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum as Vector3i,
		bounds.size as Vector3i)
	assert_true(grid.is_valid(), "the probe grid must be valid")
	assert_true(WarrenVolumetricSolver._project_massif(grid, source.massif),
		"the probe grid must carry the source massif")
	assert_true(WarrenVolumetricSolver._discard_unassigned_mass(grid),
		"the probe grid must reach the state the retention pass expects")
	if reserved.x != 2147483647:
		var claim := grid.begin_transaction(&"probe.other_feature")
		assert_true(claim.reserve([reserved] as Array[Vector3i],
			WarrenSpatialGrid.Reservation.FEATURE, &"probe.other_feature") \
			and claim.commit(), "the probe reservation must commit")
	var result := WarrenVolumetricSolver._retain_maze_rock(grid, volume)
	var cells: Array[Vector3i] = []
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
		if grid.owner_name_at(cell) \
				== WarrenSpatialFabricCompiler.MAZE_RETAINED_STONE_ID:
			cells.append(cell)
	return {"grid": grid, "result": result, "cells": cells}


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
