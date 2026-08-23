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
	"skywalks", "assets", "courtyard_bridges",
]

## Hero-quota gate texts. None of them may appear on a maze-mode failure: in
## one-pass mode a missing court, landmark, or link is an audit fact.
const HERO_QUOTA_GATE_FRAGMENTS: Array[String] = [
	"joint hero-feature beam found",
	"topology-first prefab landmarks survived",
	"topology-first skywalks fit",
]

## Seeds that compose a town and then lose it to a STRUCTURAL gate in
## `WarrenSpatialFabricCompiler` — a room the roof vocabulary cannot cover.
## Both are room/roof contracts, not feature quotas, and both were masked
## until Task C2 opened the hero-feature gate that used to reject these towns
## first; the counterfactual of translating asset plots back into parcels
## reproduces each of them unchanged, so neither belongs to the asset model.
##
## Pinned at the DEFECT level, not the gate level: every fragment listed must
## appear in the failure. The modular-box gate alone covers three different
## contract violations over any room in the town, so pinning its headline
## would silently accept a partial-bearing or unclassified room somewhere
## else as "the known blocker"; naming the classification as well means only
## THIS defect passes.
##
## The pin is two-sided on purpose. A seed that dies at a DIFFERENT gate fails
## here because the map went stale, and a seed that starts SEALING fails here
## because its entry is now a lie that must be deleted.
const KNOWN_FABRIC_BLOCKERS: Dictionary = {
	"3/standard": ["spatial modular-box contract failed", "roofless_house",
		"spatial.residual.00.room00", "spatial.residual.02.room00"],
	"9/standard": ["roof remainder for spatial.parcel.maze.house.044",
		"1-cell exposed sliver"],
}

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
